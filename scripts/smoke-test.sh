#!/usr/bin/env bash
# E2E QA of the Nodara BR-RAG stack. Exit code 0 only if every check passes.
#   make smoke    → infrastructure, CDC→Delta, raw layer + lineage, federation, KB, AI, air-gap
#   (the RAG answer check runs automatically once the models are imported: make models)
set -uo pipefail
cd "$(dirname "$0")/.."
if [[ -f .env ]]; then set -a; source .env; set +a; fi

DC="docker compose"
PASS=0 FAIL=0
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; PASS=$((PASS + 1)); }
ko()   { printf '  \033[31m✘\033[0m %s\n' "$*"; FAIL=$((FAIL + 1)); }
skip() { printf '  \033[33m•\033[0m %s\n' "$*"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
# </dev/null: `compose exec` must never swallow the stdin of the surrounding read loops.
s4()   { $DC exec -T s4hana-db psql -U "$S4_DB_ADMIN_USER" -d s4hana -tAc "$1" </dev/null 2>/dev/null; }
kb()   { $DC exec -T vector-db psql -U "$VECTOR_DB_USER" -d knowledge -tAc "$1" </dev/null 2>/dev/null; }
sql()  { $DC exec -T trino trino --output-format TSV --execute "$1" </dev/null 2>/dev/null; }
api()  { curl -fsS --max-time "${2:-10}" "http://127.0.0.1:${FRONTEND_PORT:-3000}/api/$1"; }
s3()   { curl -fsS --aws-sigv4 "aws:amz:us-east-1:s3" --user "$MINIO_ROOT_USER:$MINIO_ROOT_PASSWORD" \
              "http://127.0.0.1:${MINIO_API_PORT:-9000}/$1"; }
sha()  { sha256sum | cut -d' ' -f1; }
egress_blocked() {  # $1 service: tries to open a TCP connection to the Internet from inside it
  $DC exec -T "$1" sh -c 'timeout 5 bash -c "exec 3<>/dev/tcp/1.1.1.1/443" 2>/dev/null ||
    timeout 5 python -c "import socket; socket.create_connection((\"1.1.1.1\", 443), 4)" 2>/dev/null' \
    </dev/null >/dev/null 2>&1
  [[ $? -ne 0 ]]
}

step "1 · Contenedores y salud"
for svc in s4hana-db kafka debezium minio unity-catalog trino delta-sink vector-db ollama backend frontend; do
  health=$($DC ps --format '{{.Health}}' "$svc" 2>/dev/null)
  [[ $health == healthy ]] && ok "$svc healthy" || ko "$svc → ${health:-no está corriendo}"
done
for job in minio-init debezium-init; do
  code=$(docker inspect -f '{{.State.ExitCode}}' "nodara-$job" 2>/dev/null)
  [[ $code == 0 ]] && ok "$job completado (exit 0)" || ko "$job exit=${code:-n/a}"
done

step "2 · Capa transaccional (SAP S/4HANA simulado)"
matdoc=$(s4 "SELECT count(*) FROM sap.matdoc")
balance=$(s4 "SELECT count(*) FROM (SELECT belnr FROM sap.acdoca GROUP BY belnr HAVING sum(hsl) <> 0) x")
[[ ${matdoc:-0} -gt 0 ]] && ok "MATDOC con $matdoc líneas; BUT000=$(s4 'SELECT count(*) FROM sap.but000'), ACDOCA=$(s4 'SELECT count(*) FROM sap.acdoca')" || ko "MATDOC vacío"
[[ $balance == 0 ]] && ok "ACDOCA cuadrado (Σ HSL = 0 por documento)" || ko "ACDOCA descuadrado en $balance documentos"
[[ $(s4 "SELECT count(*) FROM pg_publication_tables WHERE pubname = 'nodara_s4_pub'") == 3 ]] \
  && ok "publicación CDC nodara_s4_pub con 3 tablas" || ko "publicación CDC incompleta"

step "3 · CDC (Debezium → Kafka)"
status=$(curl -fsS "http://127.0.0.1:${DEBEZIUM_PORT:-8083}/connectors/s4hana-cdc/status" 2>/dev/null)
[[ $(grep -o '"state":"RUNNING"' <<<"$status" | wc -l) -ge 2 ]] && ok "conector s4hana-cdc RUNNING (connector + task)" || ko "conector s4hana-cdc: ${status:-sin respuesta}"
topics=$($DC exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list </dev/null 2>/dev/null | grep -c '^s4hana\.sap\.')
[[ $topics -eq 3 ]] && ok "3 tópicos CDC (s4hana.sap.but000|matdoc|acdoca)" || ko "tópicos CDC encontrados: $topics/3"

step "4 · Lakehouse (Trino federado + Delta bronze + Unity Catalog)"
live=$(sql "SELECT count(*) FROM s4hana.sap.matdoc")
[[ $live == "$matdoc" ]] && ok "Trino → s4hana.sap.matdoc en vivo ($live filas, igual al origen)" || ko "federación Trino: '$live' vs origen '$matdoc'"
bronze=$(sql "SELECT count(*) FROM lakehouse.bronze.matdoc")
[[ ${bronze:-0} -ge ${matdoc:-1} ]] && ok "Delta lakehouse.bronze.matdoc con $bronze eventos CDC (MinIO)" || ko "bronze.matdoc: '${bronze:-error}'"
uc=$(curl -fsS "http://127.0.0.1:${UNITY_CATALOG_PORT:-8081}/api/2.1/unity-catalog/tables?catalog_name=nodara&schema_name=bronze" 2>/dev/null |
     grep -o '"name":"[a-z0-9_]*","catalog_name"' | cut -d'"' -f4 | tr '\n' ' ')
[[ $uc == *matdoc* ]] && ok "Unity Catalog nodara.bronze (EXTERNAL DELTA): $uc" || ko "Unity Catalog sin tablas bronze"

step "5 · Raw layer (MinIO raw-manuals + Unity Catalog) y linaje"
local_files=$(find knowledge/raw-manuals -type f | wc -l)
remote_keys=$(s3 "raw-manuals?list-type=2" 2>/dev/null | grep -o '<Key>[^<]*</Key>' | wc -l)
[[ $local_files -gt 0 && $remote_keys -eq $local_files ]] \
  && ok "bucket raw-manuals con $remote_keys originales (= archivos en knowledge/raw-manuals)" || ko "raw-manuals: $remote_keys objetos vs $local_files archivos locales"
[[ $(s3 "raw-manuals?versioning" 2>/dev/null) == *"<Status>Enabled</Status>"* ]] \
  && ok "versionado habilitado (historial inmutable de originales)" || ko "versionado deshabilitado en raw-manuals"
mismatch=0
while IFS= read -r file; do
  [[ $(s3 "raw-manuals/${file#knowledge/raw-manuals/}" 2>/dev/null | sha) == $(sha < "$file") ]] || mismatch=$((mismatch + 1))
done < <(find knowledge/raw-manuals -type f)
[[ $mismatch -eq 0 ]] && ok "integridad SHA-256: objetos en MinIO idénticos al repositorio" || ko "$mismatch objetos difieren del repositorio"
volumes=$(curl -fsS "http://127.0.0.1:${UNITY_CATALOG_PORT:-8081}/api/2.1/unity-catalog/volumes?catalog_name=nodara&schema_name=raw" 2>/dev/null)
[[ $volumes == *'"full_name":"nodara.raw.manuals_au"'* ]] \
  && ok "Unity Catalog volume nodara.raw.manuals_au → s3://raw-manuals/au" || ko "volumen raw no registrado en Unity Catalog"
orphans=0
ungrounded=0
while IFS='|' read -r doc uri; do
  raw=$(s3 "${uri#s3://}" 2>/dev/null) || { orphans=$((orphans + 1)); continue; }
  while IFS= read -r content; do
    [[ $raw == *"$content"* ]] || ungrounded=$((ungrounded + 1))
  done < <(kb "SELECT content FROM kb.chunks WHERE doc_id = '$doc'")
done < <(kb "SELECT doc_id, source_uri FROM kb.documents")
[[ $orphans -eq 0 && $ungrounded -eq 0 ]] \
  && ok "linaje índice ⊆ raw: $(kb 'SELECT count(*) FROM kb.chunks') trechos de pgvector presentes literalmente en su original (source_uri)" \
  || ko "linaje roto: $orphans source_uri sin objeto, $ungrounded trechos sin respaldo en raw"

step "6 · Tiempo real E2E: S/4 → Debezium → Kafka → Delta → Trino"
mblnr=$(s4 "SELECT mblnr FROM sap.simulate_activity(1) LIMIT 1")
if [[ -z $mblnr ]]; then
  ko "simulador S/4 no generó documento"
else
  start=$(date +%s)
  found=0
  for _ in $(seq 1 45); do
    found=$(sql "SELECT count(*) FROM lakehouse.bronze.matdoc WHERE mblnr = '$mblnr'")
    [[ ${found:-0} -ge 1 ]] && break
    sleep 2
  done
  if [[ ${found:-0} -ge 1 ]]; then
    lag=$(sql "SELECT max(date_diff('millisecond', _source_ts, _ingested_at)) FROM lakehouse.bronze.matdoc WHERE mblnr = '$mblnr'")
    ok "documento $mblnr visible en lakehouse.bronze.matdoc en $(( $(date +%s) - start ))s (latencia CDC ${lag} ms)"
  else
    ko "documento $mblnr no llegó al bronze en 90 s"
  fi
fi

step "7 · Base de conocimiento (pgvector aislado)"
chunks=$(kb "SELECT count(*) FROM kb.chunks")
[[ ${chunks:-0} -gt 0 ]] && ok "pgvector $(kb "SELECT extversion FROM pg_extension WHERE extname = 'vector'") con $chunks trechos de manuales (EN), $(kb 'SELECT count(embedding) FROM kb.chunks') indexados" || ko "kb.chunks vacío"
docker network inspect nodara-kb -f '{{range .Containers}}{{.Name}} {{end}}' | grep -qv 'trino\|kafka\|debezium' \
  && ok "segmento nodara-kb exclusivo: $(docker network inspect nodara-kb -f '{{range .Containers}}{{.Name}} {{end}}')" || ko "nodara-kb compartido con servicios ajenos"

step "8 · Operador → frontend → backend → IA"
home=$(curl -fsS "http://127.0.0.1:${FRONTEND_PORT:-3000}/" 2>/dev/null)
[[ -n $home ]] && ok "frontend HTTP 200 en 127.0.0.1:${FRONTEND_PORT:-3000}" || ko "frontend sin respuesta"
[[ $home == *'aria-label="Español"'* && $home == *'aria-label="English"'* && $home == *'aria-label="Português"'* ]] \
  && ok "selector de idioma ES/EN/PT desplegado (comportamiento: make ui-test)" || ko "selector de idioma ausente en el frontend"
status_json=$(api status 2>/dev/null)
[[ $status_json == *'"s4hana_live":{"ok":true'* ]] && ok "backend vía proxy /api/status (S/4 live OK)" || ko "backend /api/status: ${status_json:0:200}"
if [[ $status_json == *'"chat_ready":true'*'"embed_ready":true'* ]]; then
  answer=$(curl -fsS --max-time 600 -X POST -H 'content-type: application/json' \
    -d '{"question":"Como trocar o filtro hidráulico de retorno do caminhão HT-400? Temos o filtro em estoque?"}' \
    "http://127.0.0.1:${FRONTEND_PORT:-3000}/api/ask" 2>/dev/null)
  [[ $answer == *'"answer":'* && $answer == *AU-HT400-HYD-001* && $answer == *'s3://raw-manuals/au/AU-HT400-HYD-001.md'* ]] \
    && ok "RAG E2E: respuesta pt-BR citando AU-HT400-HYD-001 (+ source_uri raw) y stock SAP" || ko "RAG E2E falló: ${answer:0:200}"
else
  skip "RAG E2E omitido: modelos aún no importados (make models && make embed)"
fi

step "9 · Air-gap"
[[ $(docker network inspect nodara-net -f '{{.Internal}}') == true ]] && ok "red nodara-net internal=true" || ko "nodara-net no es internal"
for svc in ollama backend delta-sink kafka; do
  egress_blocked "$svc" && ok "$svc sin salida a Internet" || ko "$svc TIENE salida a Internet"
done

printf '\n\033[1mResultado: %d OK, %d fallos\033[0m\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
