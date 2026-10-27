# CLAUDE.md — Nodara BR-RAG

## Regla obligatoria de respuesta

Todas tus respuestas sobre tareas completadas en iteraciones futuras deben ser en ESPAÑOL, de forma BREVE, y estructuradas siempre en 4 puntos: 1. Qué se hizo. 2. Resultado Esperado. 3. Cómo Validarlo (QA). 4. Deuda Técnica (Registrar cualquier atajo, warning o refactorización pendiente).

La deuda del punto 4 se consolida en [TECH_DEBT.md](TECH_DEBT.md) (ID, impacto, propuesta y estado) en la misma iteración.

## Roles y scope

- **Arquitecto Líder** (usuario): define el alcance y aprueba los cambios. **Programador Senior** (Claude): implementa y valida.
- **Objetivo**: un LLM (NVIDIA NIM en la nube u Ollama local, a elección del operador) recupera estándares corporativos
  de Australia (inglés) y los cruza en tiempo real con SAP S/4HANA (Brasil). Responde en el idioma solicitado
  (ES/EN/PT) dentro de una simulación **air-gapped** cuya única salida es un gateway con allowlist.
- **Stack cerrado** (no agregar tecnologías sin aprobación del Arquitecto):
  PostgreSQL relacional (S/4HANA) · Debezium + Kafka · MinIO + Delta Lake + Unity Catalog OSS + Trino ·
  PostgreSQL + pgvector aislado (solo manuales) · FastAPI + LangChain + Ollama · Next.js + TailwindCSS ·
  iter. 4: NVIDIA NIM (cloud) · Langfuse v2 autoalojado · gateway de egress (squid).
- **Seed ESTRICTO: 3 casos C-Level** y nada más. Caso 1 Compliance (KYC, crédito USD 5M, XD01 con CNPJ/IE).
  Caso 2 Lixiviación (bomba de ácido, tormenta, orden IW31 ya creada, SKU-BR-ACID-9902 sin stock, CC-LIX-01).
  Caso 3 Flotación (xantato en Depósito 002, 15 g/t, MIGO). Todo dato nuevo debe pertenecer a un caso aprobado.

## Mapa del sistema

| Servicio | Red(es) | Host | Notas |
|---|---|---|---|
| `s4hana-db` | net, edge | `S4_DB_PORT` | `wal_level=logical`; esquema `sap` con 9 tablas SAP (incl. `TCURR`); init en `init-scripts/s4hana` |
| `kafka` | net | — | KRaft, un nodo; un tópico `s4hana.sap.<tabla>` por tabla publicada |
| `debezium` / `debezium-init` | net, edge / net | 8083 | conector `cdc/connectors/s4hana-cdc.json` (PUT idempotente) |
| `minio` / `minio-init` | net, edge / net | 9000, 9001 | buckets `lakehouse` (Delta) y `raw-manuals` (originales versionados) |
| `unity-catalog` | net, edge | 8081 | tablas `nodara.bronze.*` + volumen `nodara.raw.manuals_au` (H2 en volumen) |
| `trino` | net, edge | 8080 | catálogos `lakehouse` (Delta) y `s4hana` (PostgreSQL, rol `trino_ro`) |
| `delta-sink` | net | — | Kafka → Delta bronze; registra en Trino y UC (esquema derivado de Debezium) |
| `vector-db` | kb, edge | 5433 | esquema `kb`; `documents.source_uri` → raw layer; `chunks.sap_refs` → entidades SAP |
| `ollama` | net | — | contingencia local + embeddings; sin egress; modelos solo vía `make models` (perfil `bootstrap`) |
| `egress-proxy` | net, egress | — | squid: default deny, solo CONNECT 443 a `egress/allowlist.txt` (NVIDIA y FX) |
| `langfuse` / `langfuse-db` | net, obs, edge / obs | 3001 | Langfuse v2 autoalojado; org, proyecto, keys y admin headless desde `.env` |
| `backend` | net, kb | — | no publicado; `POST /api/v1/ask {question\|query, language: ES\|EN\|PT, engine: nim\|ollama}`; sale solo vía `egress-proxy` |
| `frontend` | net, edge | 3000 | única entrada del operador; proxy `/api/*` → backend; UI ES/EN/PT (cookie + SSR) y selector de motor |
| `ui-test` | edge | — | perfil `qa`: Playwright contra el frontend (`make ui-test`) |

## Convenciones

- **Idiomas**: código y comentarios en inglés; documentación en español; manuales en inglés; UI y respuestas del LLM
  en el idioma elegido (ES/EN/PT, por defecto PT).
- **SAP**: tablas y campos SAP originales en minúsculas (cliente `100`, esquema `sap`), respetando longitudes SAP
  (p. ej. `NAME_ORG1`, `KTEXT` y `QMTXT` = 40). Un dato nuevo va en la tabla SAP real que lo contiene, nunca en
  columnas inventadas. ACDOCA debe quedar cuadrado por `belnr` (Σ `hsl` = Σ `wsl` = 0).
- **Base de conocimiento**: los originales viven en `knowledge/raw-manuals/<origen>/<doc_id>.md`, con una sección `##`
  por fragmento, y la curación SAP en `knowledge/kb-curation.json`. `make kb-seed` regenera
  `init-scripts/vectordb/02-seed-manuals.sql`, que **nunca se edita a mano**.
- **Raw layer**: `minio-init` sube los originales a `s3://raw-manuals/<origen>/` solo si cambia su SHA-256 (bucket
  versionado) y registra un volumen EXTERNAL de Unity Catalog por origen. `make smoke` verifica índice ⊆ raw.
- **Ruteo de idioma**: hay un *system prompt* por idioma en `backend/app/orchestrator.py`, y el control de idioma
  re-traduce si la respuesta se desvía. El control de transacciones neutraliza códigos SAP que no aparezcan en el
  contexto. Para agregar un idioma: diccionario en `frontend/app/dictionaries.ts` + prompts y mensajes en el backend.
- **i18n de la UI**: todo texto estático y todo metadato de la respuesta viven en `frontend/app/dictionaries.ts`, que
  también usa el servidor (cookie `nodara.language`). `i18n.tsx` solo contiene el contexto de React. Los diccionarios
  ES/EN están tipados contra PT, así que si falta una clave el build falla.
- **Motores LLM**: `engine` = `nim` (por defecto) u `ollama`. El modelo NIM se cambia solo con `NIM_MODEL`, después de
  probarlo con una llamada real (NVIDIA retira modelos y habilita otros por cuenta). Si un intento supera
  `NIM_TIMEOUT_S` o falla, la pregunta sigue en Ollama y se informa en `model_used`/`attempts`. Los embeddings siempre son locales.
- **Observabilidad**: una traza de Langfuse por pregunta (`user_id` = `TRACE_USER_ID`). Toda llamada LangChain recibe
  `observability.callbacks(trace)`. El SDK v2 obliga a usar LangChain 0.3: no subir a 1.x sin migrar Langfuse (TD-028).
- **Tipo de cambio**: sin tasas fijas. ACDOCA se contabiliza con `TCURR`/`sap.fx_rate()` a la fecha `budat`, y el
  crédito se revalúa con FX en vivo (`backend/app/fx.py`).
- **Versiones fijadas** en imágenes y dependencias (nunca `latest`). Para actualizar, hacerlo a propósito y revalidar con `make smoke`.
- **Secretos**: solo en `.env` (gitignored, lo genera `make env`). En el compose usar `${VAR:?run make env}`; en Debezium,
  `${env:VAR}`. `NVIDIA_API_KEY` se completa a mano (vacía = solo motor local). Nunca commitear credenciales, tokens ni `.env`.
- **Air-gap**: ningún servicio de runtime depende de Internet, salvo NIM y el FX en vivo, que salen solo por
  `egress-proxy`. Agregar un dominio a `egress/allowlist.txt` o conectar otro servicio a `nodara-egress` requiere
  aprobación del Arquitecto. Los servicios de IA y streaming no se conectan a `nodara-edge`. Un puerto nuevo implica
  bind `127.0.0.1`, una variable en `.env.example` y su entrada en `scripts/preflight.sh`.
- **CDC**: para capturar una tabla nueva, agregarla a la publicación (`03-cdc.sql`) y a `table.include.list`;
  `delta-sink` la detecta sola.

## Definición de Hecho (obligatoria antes de commit)

1. `make config` → compose válido.
2. `make up` → sin colisiones (preflight) y todo `healthy` (lo espera `scripts/wait-healthy.sh`).
3. `make smoke` → **0 fallos**. Primero re-siembra (`make fresh`, borra los datos). Incluye el RAG de los 3 casos en
   ES/EN/PT con NIM, la contingencia Ollama, las trazas de Langfuse y el egress, si los modelos están importados.
4. Si se tocó el frontend: `make ui-test` en verde.
5. README, este archivo y `TECH_DEBT.md` actualizados.

## Comandos

`make env` · `make preflight` · `make config` · `make up` · `make ps` · `make logs s=<servicio>` · `make smoke` ·
`make demo` · `make fresh` · `make ui-test` · `make models` · `make embed` · `make kb-seed` · `make simulate n=10` ·
`make reset-data` · `make down` · `make clean` (borra todos los volúmenes, incluidos los modelos)

`./scripts/smoke-test.sh` sin reset sirve solo para diagnóstico: el simulador consume stock.

## Problemas conocidos (entorno WSL + Docker Desktop)

- Si el CLI `docker` devuelve `Input/output error`, Docker Desktop entró en *Resource Saver* (motor detenido sin
  contenedores). Solución: `"/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" desktop restart`.
- PostgreSQL nativo de Windows ocupa 5432 en esta máquina, por eso el `.env` local usa `S4_DB_PORT=5434`.
- Cambiar seed o esquema exige `make reset-data`, luego `make up` y `make embed`. Los init-scripts solo corren con
  volumen vacío y Debezium no hace snapshot de tablas que se agregan a un conector existente.
- `docker compose up --wait` falla con los jobs de una sola ejecución (los da por fallidos aunque terminen en `exit 0`):
  por eso existe `scripts/wait-healthy.sh`.
- La imagen de MinIO (`pgsty/minio`) no trae `grep`/`sed`/`awk`: en sus scripts usar `case` de sh.
- Unity Catalog exige un prefijo de ruta en los volúmenes EXTERNAL (`s3://bucket/<prefijo>`).
- Idempotencia: Unity Catalog responde `400 *_ALREADY_EXISTS` y Trino `ALREADY_EXISTS` ante duplicados.
- Los tests contra el stack en marcha se lanzan con `compose run --no-deps` (no tocan las dependencias).
- GPU GTX 1070 Ti (Pascal, CC 6.1): Ollama usa el runner CUDA 12 (el de CUDA 13 no la soporta).
- NVIDIA NIM: `meta/llama-3.1-70b-instruct` y `meta/llama-3.3-70b-instruct` dan 410 (EOL), y muchos modelos dan
  404 *Not found for account*. Un modelo listado en `/v1/models` puede igual no responder: probarlo con una llamada real.
- Langfuse 2.x (Next.js) escucha en la IP del contenedor salvo con `HOSTNAME=0.0.0.0` (sin eso, el healthcheck falla).
- `ChatNVIDIA` no tiene timeout de red: el límite `NIM_TIMEOUT_S` lo aplica `backend/app/llm.py` con un hilo por intento.
