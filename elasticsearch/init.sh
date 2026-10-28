#!/bin/bash
# Apply passwords, roles, the log index template, and retention. Idempotent.
set -euo pipefail

es="${ELASTICSEARCH_URL:-http://elasticsearch:9200}"
auth="elastic:${ELASTIC_PASSWORD}"

for _attempt in $(seq 1 60); do
  if curl -fsS -u "$auth" "$es" >/dev/null; then
    break
  fi
  sleep 2
done
curl -fsS -u "$auth" "$es" >/dev/null

curl -fsS -u "$auth" -H "Content-Type: application/json" \
  -X POST "$es/_security/user/kibana_system/_password" \
  -d "{\"password\":\"${KIBANA_SYSTEM_PASSWORD}\"}"

curl -fsS -u "$auth" -H "Content-Type: application/json" \
  -X PUT "$es/_security/role/logs_writer" \
  --data-binary @/elasticsearch/logs-writer.json

curl -fsS -u "$auth" -H "Content-Type: application/json" \
  -X PUT "$es/_security/user/logs_writer" \
  -d "{\"password\":\"${LOGS_WRITER_PASSWORD}\",\"roles\":[\"logs_writer\"]}"

curl -fsS -u "$auth" -H "Content-Type: application/json" \
  -X PUT "$es/_security/role/logs_reader" \
  --data-binary @/elasticsearch/logs-reader.json

curl -fsS -u "$auth" -H "Content-Type: application/json" \
  -X PUT "$es/_security/user/logs_reader" \
  -d "{\"password\":\"${LOGS_READER_PASSWORD}\",\"roles\":[\"logs_reader\"]}"

curl -fsS -u "$auth" -H "Content-Type: application/json" \
  -X PUT "$es/_ilm/policy/logs-retention" \
  -d "{\"policy\":{\"phases\":{\"hot\":{\"min_age\":\"0ms\",\"actions\":{}},\"delete\":{\"min_age\":\"${LOG_RETENTION_DAYS}d\",\"actions\":{\"delete\":{}}}}}}"

curl -fsS -u "$auth" -H "Content-Type: application/json" \
  -X PUT "$es/_ingest/pipeline/logs-shared-logger" \
  --data-binary @/elasticsearch/ingest-pipeline.json

curl -fsS -u "$auth" -H "Content-Type: application/json" \
  -X PUT "$es/_index_template/logs" \
  --data-binary @/elasticsearch/index-template.json

echo "elasticsearch init complete"
