#!/usr/bin/env bash
# Print URLs and passwords from .env. Run this on the VM. Do not commit the output.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$root/scripts/load-env.sh"

host="${PUBLIC_HOST:-<PUBLIC_HOST>}"

cat << EOF
shared-infra credentials for ${ENV_NAME:-<ENV_NAME>} on ${host}

Grafana                 http://${host}:3000
  user                  ${GRAFANA_ADMIN_USER:-admin}
  password              ${GRAFANA_ADMIN_PASSWORD:-}

Kibana                  http://${host}:5601
  data view             Application logs
  break-glass user      elastic
  password              ${ELASTIC_PASSWORD:-}
  reader user           logs_reader
  password              ${LOGS_READER_PASSWORD:-}

Langfuse                http://${host}:3003
  email                 ${LANGFUSE_INIT_USER_EMAIL:-ops@example.com}
  password              ${LANGFUSE_INIT_USER_PASSWORD:-}
  project public key    ${LANGFUSE_INIT_PROJECT_PUBLIC_KEY:-}
  project secret key    ${LANGFUSE_INIT_PROJECT_SECRET_KEY:-}

n8n                     http://${host}:5678
  email                 ${N8N_OWNER_EMAIL:-ops@example.com}
  password              ${N8N_OWNER_PASSWORD:-}

MLflow                  http://${host}:5000
  user                  ${MLFLOW_ADMIN_USER:-admin}
  password              ${MLFLOW_ADMIN_PASSWORD:-}

Qdrant                  http://${host}:6333
  api key               ${QDRANT_API_KEY:-}

Neo4j                   http://${host}:7474
  bolt                  bolt://${host}:7687
  user                  neo4j
  password              ${NEO4J_PASSWORD:-}

App Postgres            127.0.0.1:5432 on this VM
  database              app
  user                  app
  password              ${SQL_PASSWORD:-}

Elasticsearch           http://127.0.0.1:9200 on this VM
  user                  elastic
  password              ${ELASTIC_PASSWORD:-}
  writer user           logs_writer
  password              ${LOGS_WRITER_PASSWORD:-}

Prometheus              http://127.0.0.1:9090 on this VM, or through Grafana
Alertmanager            http://127.0.0.1:9093 on this VM, or through Grafana
Loki                    http://127.0.0.1:3100 on this VM, or through Grafana

Storage queue           ${AZURE_QUEUE_NAME:-app-logs}
Poison queue            ${AZURE_POISON_QUEUE_NAME:-app-logs-poison}
Connection string       ${AZURE_STORAGE_CONNECTION_STRING:-<not set>}

SSH tunnels from a laptop:
  ssh -L 9090:127.0.0.1:9090 -L 9200:127.0.0.1:9200 <user>@${host}
EOF
