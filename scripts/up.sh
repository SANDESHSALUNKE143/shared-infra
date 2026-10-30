#!/usr/bin/env bash
# Generate .env when needed, render config, and start the stack.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
"$root/scripts/init-env.sh"
# shellcheck disable=SC1091
source "$root/scripts/load-env.sh"

if [[ -z "${ENV_NAME:-}" ]]; then
  echo "Set ENV_NAME in .env, for example dev, staging, or prod." >&2
  exit 1
fi
if [[ -z "${PUBLIC_HOST:-}" ]]; then
  echo "Set PUBLIC_HOST in .env to this VM's hostname or IP, without http://." >&2
  exit 1
fi

python3 "$root/scripts/render_config.py"
# shellcheck disable=SC1091
source "$root/scripts/load-env.sh"

compose=(docker compose --env-file "$root/.env")
if [[ -z "${AZURE_STORAGE_CONNECTION_STRING:-}" ]]; then
  echo "AZURE_STORAGE_CONNECTION_STRING is empty. Starting without log-worker."
  echo "Prometheus will show log-worker down until you set the connection string and run this script again."
  "${compose[@]}" up -d --build
else
  "${compose[@]}" --profile worker up -d --build
fi

# The boot service sets this so passwords stay out of the journal.
if [[ "${SHARED_INFRA_QUIET:-}" != "1" ]]; then
  "$root/scripts/print-credentials.sh"
fi
