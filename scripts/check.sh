#!/usr/bin/env bash
# Confirm each login or ready URL. When the storage connection string is set,
# enqueue one event and read it back from Elasticsearch.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
# shellcheck disable=SC1091
source "$root/scripts/load-env.sh"

compose=(docker compose --env-file "$root/.env")
if [[ -n "${AZURE_STORAGE_CONNECTION_STRING:-}" ]]; then
  compose+=(--profile worker)
fi

wait_http() {
  local name="$1"
  local url="$2"
  shift 2
  local attempt
  for attempt in $(seq 1 90); do
    if curl -fsS "$@" "$url" >/dev/null; then
      echo "ok $name"
      return 0
    fi
    sleep 5
  done
  echo "failed $name $url" >&2
  return 1
}

grafana_user="${GRAFANA_ADMIN_USER:-admin}"
langfuse_email="${LANGFUSE_INIT_USER_EMAIL:-ops@localhost}"
n8n_email="${N8N_OWNER_EMAIL:-ops@localhost}"
mlflow_user="${MLFLOW_ADMIN_USER:-admin}"

wait_http prometheus "http://127.0.0.1:9090/-/ready"
wait_http alertmanager "http://127.0.0.1:9093/-/ready"
wait_http loki "http://127.0.0.1:3100/ready"
wait_http collector "http://127.0.0.1:13133/"
wait_http elasticsearch "http://127.0.0.1:9200" --user "elastic:${ELASTIC_PASSWORD}"
wait_http grafana "http://127.0.0.1:3000/api/org" --user "${grafana_user}:${GRAFANA_ADMIN_PASSWORD}"
wait_http kibana "http://127.0.0.1:5601/api/status" --user "elastic:${ELASTIC_PASSWORD}"
wait_http langfuse "http://127.0.0.1:3003/api/public/health"
wait_http mlflow "http://127.0.0.1:5000/api/2.0/mlflow/experiments/search" \
  --user "${mlflow_user}:${MLFLOW_ADMIN_PASSWORD}"
wait_http qdrant "http://127.0.0.1:6333/collections" --header "api-key: ${QDRANT_API_KEY}"
wait_http n8n "http://127.0.0.1:5678/healthz"

owner_body="$(curl -sS -X POST "http://127.0.0.1:5678/rest/owner/setup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${n8n_email}\",\"firstName\":\"Ops\",\"lastName\":\"Owner\",\"password\":\"${N8N_OWNER_PASSWORD}\"}")"
if printf "%s" "$owner_body" | grep -Eqi "already|${n8n_email}|\"id\""; then
  echo "ok n8n owner"
else
  echo "failed n8n owner $owner_body" >&2
  exit 1
fi

neo_ok=0
for _attempt in $(seq 1 60); do
  if curl -fsS --user "neo4j:${NEO4J_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{"statements":[{"statement":"RETURN 1"}]}' \
    "http://127.0.0.1:7474/db/neo4j/tx/commit" >/dev/null; then
    echo "ok neo4j"
    neo_ok=1
    break
  fi
  sleep 5
done
if [[ "$neo_ok" -ne 1 ]]; then
  echo "failed neo4j" >&2
  exit 1
fi

sql_ok=0
for _attempt in $(seq 1 30); do
  if "${compose[@]}" exec -T -e "PGPASSWORD=${SQL_PASSWORD}" sql \
    psql -U app -d app -tAc "select 1" | grep -q 1; then
    echo "ok sql"
    sql_ok=1
    break
  fi
  sleep 5
done
if [[ "$sql_ok" -ne 1 ]]; then
  echo "failed sql" >&2
  exit 1
fi

user_ok=0
for _attempt in $(seq 1 60); do
  if "${compose[@]}" exec -T -e "PGPASSWORD=${LANGFUSE_POSTGRES_PASSWORD}" langfuse-postgres \
    psql -U postgres -d postgres -tAc "select email from users where email='${langfuse_email}'" \
    | grep -q "${langfuse_email}"; then
    echo "ok langfuse user"
    user_ok=1
    break
  fi
  sleep 5
done
if [[ "$user_ok" -ne 1 ]]; then
  echo "failed langfuse user" >&2
  exit 1
fi

if [[ -z "${AZURE_STORAGE_CONNECTION_STRING:-}" ]]; then
  echo "skipped log-worker"
  exit 0
fi

worker_ok=0
for _attempt in $(seq 1 30); do
  if "${compose[@]}" exec -T log-worker \
    python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')"; then
    echo "ok log-worker"
    worker_ok=1
    break
  fi
  sleep 5
done
if [[ "$worker_ok" -ne 1 ]]; then
  echo "failed log-worker" >&2
  exit 1
fi

"${compose[@]}" exec -T log-worker python -m log_worker.roundtrip
