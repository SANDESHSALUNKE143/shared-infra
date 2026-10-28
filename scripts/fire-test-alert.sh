#!/usr/bin/env bash
# Post one synthetic alert to Alertmanager so the UI shows a firing alert.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$root/scripts/load-env.sh"

env_name="${ENV_NAME:-dev}"
curl -fsS -X POST "http://127.0.0.1:9093/api/v2/alerts" \
  -H "Content-Type: application/json" \
  -d "[{\"labels\":{\"alertname\":\"TestAlert\",\"severity\":\"warning\",\"env\":\"${env_name}\"},\"annotations\":{\"summary\":\"Synthetic alert from fire-test-alert.sh\"}}]"
echo
echo "Posted TestAlert. Open http://127.0.0.1:9093 or the Alertmanager datasource in Grafana."
