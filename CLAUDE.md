# CLAUDE.md — Nodara BR-RAG

## Regla obligatoria de respuesta

Todas tus respuestas sobre tareas completadas en iteraciones futuras deben ser en ESPAÑOL, de forma BREVE, y estructuradas siempre en 4 puntos: 1. Qué se hizo. 2. Resultado Esperado. 3. Cómo Validarlo (QA). 4. Deuda Técnica (Registrar cualquier atajo, warning o refactorización pendiente).

La deuda del punto 4 se consolida en [TECH_DEBT.md](TECH_DEBT.md) (ID, impacto, propuesta y estado) en la misma iteración.

## Roles y scope

- **Arquitecto Líder** (usuario): define el alcance y aprueba los cambios. **Programador Senior** (Claude): implementa y valida.
- **Objetivo**: un LLM local (Ollama) traduce manuales técnicos de Australia (inglés) y los cruza en tiempo real con
  SAP S/4HANA (Brasil) antes de responder al operador, en un entorno de simulación **air-gapped**.
- **Stack cerrado** (no agregar tecnologías sin aprobación del Arquitecto):
  PostgreSQL relacional (S/4: BUT000, ACDOCA, MATDOC) · Debezium + Kafka · MinIO + Delta Lake + Unity Catalog OSS +
  Trino · PostgreSQL + pgvector aislado (solo manuales) · FastAPI + LangChain + Ollama · Next.js + TailwindCSS.

## Mapa del sistema

| Servicio | Red(es) | Host | Notas |
|---|---|---|---|
| `s4hana-db` | net, edge | `S4_DB_PORT` | `wal_level=logical`; esquema `sap`; init en `init-scripts/s4hana` |
| `kafka` | net | — | KRaft, un nodo; tópicos `s4hana.sap.*` |
| `debezium` / `debezium-init` | net, edge / net | 8083 | conector `cdc/connectors/s4hana-cdc.json` (PUT idempotente) |
| `minio` / `minio-init` | net, edge / net | 9000, 9001 | buckets `lakehouse` (Delta) y `raw-manuals` (originales versionados) |
| `unity-catalog` | net, edge | 8081 | tablas `nodara.bronze.*` + volumen `nodara.raw.manuals_au` (H2 en volumen) |
| `trino` | net, edge | 8080 | catálogos `lakehouse` (Delta) y `s4hana` (PostgreSQL, rol `trino_ro`) |
| `delta-sink` | net | — | Kafka → Delta bronze; registra en Trino y UC |
| `vector-db` | kb, edge | 5433 | esquema `kb`; `documents.source_uri` → raw layer; embeddings 768-d |
| `ollama` | net | — | sin egress; modelos solo vía `make models` (perfil `bootstrap`) |
| `backend` | net, kb | — | no publicado; API `/api/v1/*` |
| `frontend` | net, edge | 3000 | única entrada del operador; proxy `/api/*` → backend; UI ES/EN/PT |
| `ui-test` | edge | — | perfil `qa`: Playwright contra el frontend (`make ui-test`) |

## Convenciones

- **Idiomas**: código y comentarios en inglés; documentación en español; manuales en inglés; respuestas del LLM en
  pt-BR; UI en ES/EN/PT (por defecto PT).
- **SAP**: nombres de campo originales en minúsculas, cliente `100`, esquema `sap`. Respetar las longitudes SAP
  (p. ej. `NAME_ORG1` = 40). ACDOCA debe quedar cuadrado por `belnr` (Σ `hsl` = 0).
- **Raw layer (gobierno de datos)**: cada manual original vive en `knowledge/raw-manuals/<origen>/<doc_id>.md`
  (front matter con `doc_id`, `classification` y `language`). `minio-init` lo sube a `s3://raw-manuals/<origen>/`
  solo si cambia su SHA-256, el bucket está versionado y cada origen se registra como volumen EXTERNAL de Unity
  Catalog. `kb.documents.source_uri` apunta al original y el texto de cada fragmento debe ser idéntico al del
  original: `make smoke` verifica índice ⊆ raw.
- **i18n**: todo texto estático de la UI vive en `frontend/app/i18n.tsx` (React Context). Los diccionarios ES/EN
  están tipados contra PT, así que si falta una clave el build falla. Nada de strings visibles hardcodeados en los componentes.
- **Versiones fijadas** en imágenes y dependencias (nunca `latest`). Para actualizar, hacerlo a propósito y revalidar con `make smoke`.
- **Secretos**: solo en `.env` (gitignored, lo genera `make env`). En el compose usar `${VAR:?run make env}`; en Debezium,
  `${env:VAR}`. Nunca commitear credenciales, tokens ni `.env`.
- **Air-gap**: ningún servicio de runtime depende de Internet. Los servicios de IA y streaming no se conectan a
  `nodara-edge`. Un puerto nuevo implica bind `127.0.0.1`, una variable en `.env.example` y su entrada en `scripts/preflight.sh`.
- **CDC**: para capturar una tabla nueva, agregarla a la publicación `nodara_s4_pub` y a `table.include.list`;
  el `delta-sink` la detecta sola (esquema derivado de Debezium).

## Definición de Hecho (obligatoria antes de commit)

1. `make config` → compose válido.
2. `make up` → sin colisiones (preflight) y todos los servicios `healthy`.
3. `make smoke` → **0 fallos** (el RAG E2E corre automáticamente si los modelos ya fueron importados).
4. Si se tocó el frontend: `make ui-test` en verde.
5. README, este archivo y `TECH_DEBT.md` actualizados.

## Comandos

`make env` · `make preflight` · `make config` · `make up` · `make ps` · `make logs s=<servicio>` · `make smoke` ·
`make ui-test` · `make models` · `make embed` · `make simulate n=10` · `make down` · `make clean` (borra volúmenes)

## Problemas conocidos (entorno WSL + Docker Desktop)

- Si el CLI `docker` devuelve `Input/output error`, Docker Desktop entró en *Resource Saver* (motor detenido sin
  contenedores). Solución: `"/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" desktop restart`.
- PostgreSQL nativo de Windows ocupa 5432 en esta máquina, por eso el `.env` local usa `S4_DB_PORT=5434`.
- Los init-scripts de PostgreSQL solo corren con el volumen vacío. Un cambio de esquema exige recrear el volumen
  (`docker compose rm -sf <db>` + `docker volume rm nodara-br-rag_<volumen>`); en pgvector, después correr `make embed`.
- La imagen de MinIO (`pgsty/minio`) no trae `grep`/`sed`/`awk`: en sus scripts usar `case` de sh.
- Unity Catalog exige un prefijo de ruta en los volúmenes EXTERNAL (`s3://bucket/<prefijo>`).
- Idempotencia: Unity Catalog responde `400 *_ALREADY_EXISTS` y Trino `ALREADY_EXISTS` ante duplicados.
- Los tests contra el stack en marcha se lanzan con `compose run --no-deps` (no tocan las dependencias).
- GPU GTX 1070 Ti (Pascal, CC 6.1): Ollama usa el runner CUDA 12 (el de CUDA 13 no la soporta).
