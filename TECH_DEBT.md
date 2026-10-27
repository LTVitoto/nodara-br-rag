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
| TD-007 | 1·3 | Calidad del LLM de 8B: a veces no cita en el texto la transacción prescrita (XD01), confunde aviso con orden (IW21/IW31) y no aplica por sí mismo las fórmulas del manual (cobertura a 15 g/t ≈ 11,7 días < 14). Mitigado con controles y paneles deterministas. | A | Golden set por caso e idioma; herramienta de cálculo (*tool calling*); evaluar un modelo mayor. | Abierta |
| TD-008 | 1 | No hay migraciones de esquema: los init-scripts solo corren con volumen vacío. | M | Flyway o Alembic con migraciones versionadas. | Abierta |
| TD-009 | 1 | Unity Catalog usa H2 embebido. | M | Backend PostgreSQL para UC. | Abierta |
| TD-010 | 1 | El proxy de Next.js hereda el timeout de undici (~300 s): con el LLM en CPU puede cortarse. | B | Streaming (SSE) de la respuesta y timeout configurable. | Abierta |
| TD-011 | 2·3 | El texto de los manuales vive en dos artefactos (originales Markdown + seed SQL de pgvector). Mitigado en la iter. 3: el seed se genera desde los originales (`make kb-seed`) y `make smoke` verifica índice ⊆ raw. | B | Ingesta en runtime desde MinIO (raw → chunking → embeddings) como fuente única. | Mitigada |
| TD-012 | 2 | Los originales son Markdown sintéticos; no hay extracción PDF→texto para manuales reales. | M | Parser PDF (y OCR) dentro de la ingesta de TD-011. | Abierta |
| TD-013 | 2 | La i18n cubría solo textos estáticos; la respuesta del LLM y los errores del backend salían en pt-BR. | M | Iter. 3: `language` (ES/EN/PT) en `/api/v1/ask`, *system prompt* por idioma, control de idioma, errores y descripciones SAP por idioma. | **Resuelta** |
| TD-014 | 2 | El idioma no se resuelve en el servidor: el HTML sale en PT y el idioma guardado se aplica tras la hidratación (parpadeo breve). | B | Cookie de idioma + render en servidor (o rutas `/[locale]`). | Abierta |
| TD-015 | 2 | `make ui-test` depende de la imagen de Playwright (~3,4 GB) y no hay CI que corra smoke y UI. | M | Pipeline CI con caché de imágenes. | Abierta |
| TD-016 | 1 | Docker Desktop *Resource Saver* detiene el motor del entorno de desarrollo (mitigación en CLAUDE.md). | B | Desactivar Resource Saver para este equipo. | Abierta |
| TD-017 | 2 | Si falla el registro del raw layer en Unity Catalog, `minio-init` solo emite un WARNING (no bloquea el plano de datos). | B | Alertar desde observabilidad; hoy lo detecta `make smoke`. | Aceptada |
| TD-018 | 3 | El control de idioma usa `langdetect` (estadístico) y su corrección agrega una llamada al LLM (~+15 s) cuando se activa. | B | Salida estructurada con campo de idioma o un modelo con mejor adherencia. | Abierta |
| TD-019 | 3 | El control de transacciones es por patrones: fuera de una mención explícita solo neutraliza códigos con dígitos (un inventado solo con letras, p. ej. "FICO", pasaría). | B | Catálogo de transacciones SAP permitidas (allowlist) por proceso. | Abierta |
| TD-020 | 3 | El simulador y cada `make smoke` consumen xantato del caso 3 (reposición automática bajo 3.000 kg): el stock de una demo cambia con el uso. | M | `make reset-data` antes de una demo C-Level; dataset de QA separado. | Abierta |
| TD-021 | 3 | Simplificaciones SAP: la exposición de crédito solo incluye partidas abiertas (sin pedidos ni entregas); tipo de cambio fijo de 5,30 BRL/USD; plantas, depósitos y motivos de bloqueo como constantes; equipo de AFIH aplanado en AUFK. | M | Modelar pedidos abiertos (VBAK/VBAP), TCURR, T001W/T001L y AFIH. | Abierta |
| TD-022 | 3 | Cambiar seed o esquema obliga a `make reset-data`: Debezium no hace snapshot de tablas nuevas en un conector existente (ligado a TD-008). | M | Snapshots incrementales con la tabla de señales de Debezium + migraciones. | Abierta |
| TD-023 | 3 | No hay datos de proceso (throughput, dosis actual): no existe un cálculo determinista de escenarios para cambios de dosis. | M | Integrar el historiador de planta (PI) o un servicio de cálculo. | Abierta |
| TD-024 | 3 | Arranque en frío: el backend precarga los modelos al iniciar, pero tras 30 min sin uso la siguiente pregunta tarda ~30 s más. | B | `keep_alive` mayor en entorno de demo o precarga periódica. | Abierta |
