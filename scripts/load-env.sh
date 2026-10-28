#!/usr/bin/env bash
# Export .env into the current shell. Source this file; do not execute it.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$root/.env" ]]; then
  echo "Missing $root/.env. Run scripts/init-env.sh first." >&2
  return 1 2>/dev/null || exit 1
fi
eval "$(python3 "$root/scripts/export_env.py" "$root/.env")"
