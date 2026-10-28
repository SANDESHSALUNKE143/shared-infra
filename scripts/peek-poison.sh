#!/usr/bin/env bash
# Print messages in the poison queue. This does not delete them.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
# shellcheck disable=SC1091
source "$root/scripts/load-env.sh"

if [[ -z "${AZURE_STORAGE_CONNECTION_STRING:-}" ]]; then
  echo "AZURE_STORAGE_CONNECTION_STRING is empty." >&2
  exit 1
fi

docker compose --env-file "$root/.env" --profile worker exec -T log-worker \
  python -m log_worker.peek
