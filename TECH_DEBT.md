# Registro de Deuda Técnica — Nodara BR-RAG

Se actualiza en cada iteración junto con el punto 4 de la respuesta (ver [CLAUDE.md](CLAUDE.md)).
Impacto: **A** alto · **M** medio · **B** bajo.

| ID | Iter. | Deuda | Imp. | Propuesta | Estado |
|---|---|---|---|---|---|
| TD-001 | 1 | El PAT de GitHub va embebido en la URL del remote (`.git/config`) y quedó expuesto en el prompt. | A | Revocar o rotar el token; `git remote set-url` sin token + `gh auth login` o credential helper. | Abierta |
| TD-002 | 1 | Trino, Unity Catalog, Debezium REST y MinIO sin autenticación ni TLS; Kafka en PLAINTEXT (mitigado: bind 127.0.0.1 y redes internal). | A | Auth en Trino y UC, SASL/TLS en Kafka, TLS interno. | Abierta |
| TD-003 | 1 | MinIO corre desde el fork comunitario `pgsty/minio`: las imágenes oficiales ya no se publican (riesgo de supply chain). | M | Build propio y firmado desde el código fuente, o evaluar SeaweedFS/Garage. | Abierta |
| TD-004 | 1 | Doble registro de las tablas Delta: Trino (file metastore) + Unity Catalog; pueden divergir. | M | Integración nativa (UC Iceberg REST / UniForm) o metastore compartido. | Abierta |
| TD-005 | 1 | Bronze *at-least-once*: posibles duplicados tras una caída; no hay capa silver/gold. | M | `MERGE` con deduplicación por `_source_lsn` + PK hacia silver. | Abierta |
| TD-006 | 1 | Latencia CDC acotada por el micro-batch de 5 s del sink (medida: 1–6 s). | B | Flush adaptativo o motor de streaming. | Aceptada (simulación) |
| TD-007 | 1 | El LLM de 8B comete imprecisiones de traducción y de razonamiento sobre stock; no hay golden set de evaluación. | A | Evaluación automática pt-BR, modelo mayor o fine-tuning de dominio. | Abierta |
| TD-008 | 1 | No hay migraciones de esquema: los init-scripts solo corren con volumen vacío (en la iter. 2, `source_uri` obligó a recrear pgvector). | M | Flyway o Alembic con migraciones versionadas. | Abierta |
| TD-009 | 1 | Unity Catalog usa H2 embebido. | M | Backend PostgreSQL para UC. | Abierta |
| TD-010 | 1 | El proxy de Next.js hereda el timeout de undici (~300 s): con el LLM en CPU puede cortarse. | B | Streaming (SSE) de la respuesta y timeout configurable. | Abierta |
| TD-011 | 2 | El texto de los manuales está duplicado: originales en `knowledge/raw-manuals` y fragmentos en el seed SQL de pgvector (mitigado: `make smoke` verifica índice ⊆ raw). | M | Pipeline de ingesta raw-manuals → chunking → embeddings, con MinIO como fuente única. | Abierta |
| TD-012 | 2 | Los originales son Markdown sintéticos; no hay extracción PDF→texto para manuales reales. | M | Parser PDF (y OCR) dentro del pipeline de TD-011. | Abierta |
| TD-013 | 2 | La i18n cubre solo textos estáticos: la respuesta del LLM y los errores del backend siguen en pt-BR (la UI lo avisa) y en ES se muestran las descripciones de material en PT. | M | Parámetro `language` en `/api/v1/ask` + descripciones multiidioma en `kb.part_xref`. | Abierta |
| TD-014 | 2 | El idioma no se resuelve en el servidor: el HTML sale en PT y el idioma guardado se aplica tras la hidratación (parpadeo breve). | B | Cookie de idioma + render en servidor (o rutas `/[locale]`). | Abierta |
| TD-015 | 2 | `make ui-test` depende de la imagen de Playwright (~3,4 GB) y no hay CI que corra smoke y UI. | M | Pipeline CI con caché de imágenes. | Abierta |
| TD-016 | 1 | Docker Desktop *Resource Saver* detiene el motor del entorno de desarrollo (mitigación en CLAUDE.md). | B | Desactivar Resource Saver para este equipo. | Abierta |
| TD-017 | 2 | Si falla el registro del raw layer en Unity Catalog, `minio-init` solo emite un WARNING (no bloquea el plano de datos). | B | Alertar desde observabilidad; hoy lo detecta `make smoke`. | Aceptada |
