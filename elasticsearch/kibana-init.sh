#!/bin/bash
# Create the Kibana data view operators use to search application logs.
set -euo pipefail

kibana="${KIBANA_URL:-http://kibana:5601}"
auth="elastic:${ELASTIC_PASSWORD}"

for _attempt in $(seq 1 90); do
  if curl -fsS "$kibana/api/status" >/dev/null; then
    break
  fi
  sleep 2
done
curl -fsS "$kibana/api/status" >/dev/null

body='{"data_view":{"id":"application-logs","name":"Application logs","title":"logs-*","timeFieldName":"@timestamp"}}'
status="$(curl -sS -o /tmp/kibana-data-view.json -w "%{http_code}" \
  -u "$auth" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -X POST "$kibana/api/data_views/data_view" \
  -d "$body")"

if [[ "$status" == "200" || "$status" == "409" ]]; then
  echo "kibana data view ready"
  exit 0
fi

echo "kibana data view failed with HTTP $status" >&2
cat /tmp/kibana-data-view.json >&2
exit 1
