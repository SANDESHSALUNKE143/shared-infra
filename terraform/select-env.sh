#!/usr/bin/env bash
# Map the GitHub branch to dev, uat, or prod and publish the client id for azure/login.
set -euo pipefail

if [[ -z "${TF_TARGET:-}" ]]; then
  echo "TF_TARGET is empty." >&2
  exit 1
fi

if [[ "$TF_TARGET" == "main" ]]; then
  env_name="prod"
else
  env_name="$TF_TARGET"
fi

case "$env_name" in
  dev | uat | prod) ;;
  *)
    echo "Run this workflow from the dev, uat, or main branch. The branch was ${TF_TARGET}." >&2
    exit 1
    ;;
esac

client_var="AZURE_CLIENT_ID_$(printf '%s' "$env_name" | tr '[:lower:]' '[:upper:]')"
client_id="${!client_var:-}"
if [[ -z "${ARM_TENANT_ID:-}" || -z "${ARM_SUBSCRIPTION_ID:-}" || -z "$client_id" ]]; then
  echo "Set the repository variables AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, and ${client_var}." >&2
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "tf_env=${env_name}"
    echo "client_id=${client_id}"
  } >> "$GITHUB_OUTPUT"
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "TF_ENV=${env_name}" >> "$GITHUB_ENV"
fi
