#!/usr/bin/env bash
# E2E QA of the Nodara BR-RAG stack. Exit code 0 only if every check passes.
#   make smoke    → infrastructure, the 3 business cases, CDC→Delta, raw layer + lineage, federation,
#                   KB, RAG per case and language (ES / EN / PT), air-gap
#   SMOKE_RAG=0 make smoke skips the LLM calls (~2 min); they also skip until `make models` was run.
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
rag_check() {  # $1 language, $2 expected top document, $3 expected SAP transaction, $4 question, $5… JSON fragments
  local language=$1 doc=$2 tcode=$3 question=$4 response top detected guard declared cited missing=()
  shift 4
  response=$(curl -fsS --max-time 600 -X POST -H 'content-type: application/json' \
    -d "{\"question\":\"$question\",\"language\":\"$language\"}" "http://127.0.0.1:${FRONTEND_PORT:-3000}/api/ask" 2>/dev/null)
  top=$(grep -o '"doc_id":"[^"]*"' <<<"$response" | head -1 | cut -d'"' -f4)
  detected=$(grep -o '"detected":"[a-z]*"' <<<"$response" | cut -d'"' -f4)
  guard=$(grep -o '"status":"[a-z]*"' <<<"$response" | tail -1 | cut -d'"' -f4)
  declared=$(grep -o '"declared":\[[^]]*\]' <<<"$response" | grep -o '[A-Z0-9]\{3,\}' | tr '\n' ' ')
  cited=$(grep -o '"cited":\[[^]]*\]' <<<"$response" | grep -o '[A-Z0-9]\{3,\}' | tr '\n' ' ')
  for fragment in "$@"; do [[ $response == *"$fragment"* ]] || missing+=("$fragment"); done
  if [[ $top == "$doc" && $detected == "${language,,}" && " $declared" == *" $tcode "* && ${#missing[@]} -eq 0 ]]; then
    ok "RAG $language → $doc · respuesta en '$detected' (control de idioma: $guard) · transacción prescrita $tcode" \
       "(citada en el texto: $([[ " $cited" == *" $tcode "* ]] && echo sí || echo no)) · evidencia SAP"
  else
    ko "RAG $language → top='$top' idioma='$detected' prescritas='$declared' faltan: ${missing[*]:-ninguno} ${response:0:160}"
  fi
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
tables=$(s4 "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'sap'")
published=$(s4 "SELECT count(*) FROM pg_publication_tables WHERE pubname = 'nodara_s4_pub'")
counts=$(s4 "SELECT string_agg(relname || '=' || n_live_tup, ' ' ORDER BY relname) FROM pg_stat_user_tables WHERE schemaname = 'sap'")
matdoc=$(s4 "SELECT count(*) FROM sap.matdoc")
[[ ${tables:-0} -ge 8 ]] && ok "$tables tablas SAP: $counts" || ko "tablas SAP: ${tables:-0}"
[[ $(s4 "SELECT count(*) FROM (SELECT belnr FROM sap.acdoca GROUP BY belnr HAVING sum(hsl) <> 0 OR sum(wsl) <> 0) x") == 0 ]] \
  && ok "ACDOCA cuadrado por documento (Σ HSL = Σ WSL = 0)" || ko "ACDOCA descuadrado"
[[ $published == "$tables" ]] && ok "publicación CDC nodara_s4_pub cubre las $published tablas" || ko "publicación CDC: $published de $tables tablas"

step "3 · Casos de negocio C-Level (seed estricto)"
case1=$(s4 "SELECT count(*) FROM sap.ukmbp_cms_sgm c WHERE c.xblocked = 'X' AND c.credit_limit = 5000000 AND c.currency = 'USD'
             AND (SELECT sum(wsl) FROM sap.acdoca a WHERE a.koart = 'D' AND a.augbl IS NULL AND a.kunnr = c.partner) > c.credit_limit
             AND (SELECT count(*) FROM sap.dfkkbptaxnum t WHERE t.partner = c.partner AND t.taxtype IN ('BR1', 'BR3')) = 2")
[[ $case1 == 1 ]] && ok "Caso 1 Compliance: refinadora bloqueada, exposición > límite USD 5M, CNPJ + IE registrados" || ko "Caso 1 incompleto"
case2=$(s4 "SELECT count(*) FROM sap.aufk a JOIN sap.qmel q ON q.aufnr = a.aufnr AND q.qmart = 'M2'
              JOIN sap.resb r ON r.aufnr = a.aufnr AND r.matnr = 'SKU-BR-ACID-9902' AND r.bdmng > r.enmng
             WHERE a.kostl = 'CC-LIX-01' AND a.phas1 = 'X' AND a.phas2 = ''
               AND (SELECT coalesce(sum(CASE m.shkzg WHEN 'S' THEN m.menge ELSE -m.menge END), 0)
                      FROM sap.matdoc m WHERE m.matnr = 'SKU-BR-ACID-9902') = 0")
[[ $case2 == 1 ]] && ok "Caso 2 Lixiviación: orden PM abierta (CC-LIX-01, aviso M2 tormenta), reserva SKU-BR-ACID-9902 con stock 0" || ko "Caso 2 incompleto"
case3=$(s4 "SELECT sum(CASE shkzg WHEN 'S' THEN menge ELSE -menge END) FROM sap.matdoc
             WHERE matnr = 'SKU-BR-REAG-4410' AND werks = 'BR10' AND lgort = '0002' HAVING bool_and(tcode2 = 'MIGO')")
[[ ${case3%%.*} -gt 0 ]] 2>/dev/null && ok "Caso 3 Flotación: xantato SKU-BR-REAG-4410 = ${case3%.*} KG en Depósito 002 (movimientos MIGO)" || ko "Caso 3 incompleto"
traces=$(( $(s4 "SELECT count(*) FROM sap.matdoc WHERE sgtxt ILIKE '%HT-400%'") + \
           $(kb "SELECT count(*) FROM kb.chunks c JOIN kb.documents d USING (doc_id) WHERE c.content ILIKE '%HT-400%' OR d.title ILIKE '%HT-400%'") + \
           $(s3 "raw-manuals?list-type=2" 2>/dev/null | grep -c 'HT400') ))
[[ $traces -eq 0 ]] && ok "cero rastros del caso genérico HT-400 (S/4, pgvector y raw layer)" || ko "$traces rastros de HT-400"

step "4 · CDC (Debezium → Kafka)"
status=$(curl -fsS "http://127.0.0.1:${DEBEZIUM_PORT:-8083}/connectors/s4hana-cdc/status" 2>/dev/null)
[[ $(grep -o '"state":"RUNNING"' <<<"$status" | wc -l) -ge 2 ]] && ok "conector s4hana-cdc RUNNING (connector + task)" || ko "conector s4hana-cdc: ${status:-sin respuesta}"
topics=$($DC exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list </dev/null 2>/dev/null | grep -c '^s4hana\.sap\.')
[[ $topics -eq $published ]] && ok "$topics tópicos CDC s4hana.sap.* (uno por tabla publicada)" || ko "tópicos CDC: $topics de $published"

step "5 · Lakehouse (Trino federado + Delta bronze + Unity Catalog)"
live=$(sql "SELECT count(*) FROM s4hana.sap.matdoc")
[[ $live == "$matdoc" ]] && ok "Trino → s4hana.sap.matdoc en vivo ($live filas, igual al origen)" || ko "federación Trino: '$live' vs origen '$matdoc'"
bronze=$(sql "SELECT count(*) FROM lakehouse.bronze.matdoc")
[[ ${bronze:-0} -ge ${matdoc:-1} ]] && ok "Delta lakehouse.bronze.matdoc con $bronze eventos CDC (MinIO)" || ko "bronze.matdoc: '${bronze:-error}'"
uc=$(curl -fsS "http://127.0.0.1:${UNITY_CATALOG_PORT:-8081}/api/2.1/unity-catalog/tables?catalog_name=nodara&schema_name=bronze" 2>/dev/null |
     grep -o '"name":"[a-z0-9_]*","catalog_name"' | cut -d'"' -f4 | tr '\n' ' ')
[[ $(wc -w <<<"$uc") -eq $published ]] && ok "Unity Catalog nodara.bronze (EXTERNAL DELTA): $uc" || ko "Unity Catalog bronze: '$uc'"

step "6 · Raw layer (MinIO raw-manuals + Unity Catalog) y linaje"
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
  && ok "linaje índice ⊆ raw: $(kb 'SELECT count(*) FROM kb.chunks') fragmentos de pgvector presentes literalmente en su original (source_uri)" \
  || ko "linaje roto: $orphans source_uri sin objeto, $ungrounded fragmentos sin respaldo en raw"

step "7 · Tiempo real E2E: S/4 → Debezium → Kafka → Delta → Trino"
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
    ok "documento $mblnr (consumo MIGO de xantato) visible en lakehouse.bronze.matdoc en $(( $(date +%s) - start ))s (latencia CDC ${lag} ms)"
  else
    ko "documento $mblnr no llegó al bronze en 90 s"
  fi
fi

step "8 · Base de conocimiento (pgvector aislado)"
chunks=$(kb "SELECT count(*) FROM kb.chunks")
[[ ${chunks:-0} -gt 0 ]] && ok "pgvector $(kb "SELECT extversion FROM pg_extension WHERE extname = 'vector'"): $(kb 'SELECT count(*) FROM kb.documents') manuales AU, $chunks fragmentos, $(kb 'SELECT count(embedding) FROM kb.chunks') indexados" || ko "kb.chunks vacío"
docker network inspect nodara-kb -f '{{range .Containers}}{{.Name}} {{end}}' | grep -qv 'trino\|kafka\|debezium' \
  && ok "segmento nodara-kb exclusivo: $(docker network inspect nodara-kb -f '{{range .Containers}}{{.Name}} {{end}}')" || ko "nodara-kb compartido con servicios ajenos"

step "9 · Operador → frontend → backend → IA (ruteo de idioma)"
home=$(curl -fsS "http://127.0.0.1:${FRONTEND_PORT:-3000}/" 2>/dev/null)
[[ -n $home ]] && ok "frontend HTTP 200 en 127.0.0.1:${FRONTEND_PORT:-3000}" || ko "frontend sin respuesta"
[[ $home == *'aria-label="Español"'* && $home == *'aria-label="English"'* && $home == *'aria-label="Português"'* ]] \
  && ok "selector de idioma ES/EN/PT desplegado (comportamiento: make ui-test)" || ko "selector de idioma ausente en el frontend"
status_json=$(api status 2>/dev/null)
[[ $status_json == *'"s4hana_live":{"ok":true'* ]] && ok "backend vía proxy /api/status (S/4 live OK)" || ko "backend /api/status: ${status_json:0:200}"
if [[ ${SMOKE_RAG:-1} == 0 ]]; then
  skip "RAG E2E omitido (SMOKE_RAG=0)"
elif [[ $status_json == *'"chat_ready":true'*'"embed_ready":true'* ]]; then
  rag_check ES AU-CMP-KYC-001 XD01 "El cliente refinador está bloqueado por límite de crédito. ¿Qué necesito para regularizarlo según el estándar KYC?" \
    '"xblocked":"X"' '"credit_limit":5000000.0' '"cnpj":"11.222.333/0001-81"'
  rag_check EN AU-LIX-SOP-002 IW31 "The leaching acid pump failed after the tropical storm. Is there already an open order and do we have spare SKU-BR-ACID-9902?" \
    '"aufnr":"4000200101"' '"matnr":"SKU-BR-ACID-9902"' '"stock_qty":0.0' '"open_qty":1.0'
  rag_check PT AU-FLO-STR-003 MIGO "O teor do minério caiu. Como ajustar a dosagem de xantato para 15 g/t e o estoque do Depósito 002 é suficiente?" \
    '"matnr":"SKU-BR-REAG-4410"' '"lgort":"0002"' '"tcode2":"MIGO"'
else
  skip "RAG E2E omitido: modelos aún no importados (make models && make embed)"
fi

step "10 · Air-gap"
[[ $(docker network inspect nodara-net -f '{{.Internal}}') == true ]] && ok "red nodara-net internal=true" || ko "nodara-net no es internal"
for svc in ollama backend delta-sink kafka; do
  egress_blocked "$svc" && ok "$svc sin salida a Internet" || ko "$svc TIENE salida a Internet"
done

printf '\n\033[1mResultado: %d OK, %d fallos\033[0m\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
