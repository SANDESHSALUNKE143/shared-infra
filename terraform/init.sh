#!/usr/bin/env bash
# Create the state account when it is missing, then point both roots at it.
# Usage: terraform/init.sh dev|uat|prod
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: terraform/init.sh dev|uat|prod" >&2
  exit 1
fi

env_name="$1"
case "$env_name" in
  dev | uat | prod) ;;
  *)
    echo "Environment must be dev, uat, or prod." >&2
    exit 1
    ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

tfvars="terraform/environments/${env_name}.tfvars"
rg="$(awk -F'"' '/^resource_group_name[[:space:]]*=/{print $2; exit}' "$tfvars")"
if [[ -z "$rg" ]]; then
  echo "Could not read resource_group_name from ${tfvars}." >&2
  exit 1
fi

subscription_id="$(az account show --query id -o tsv)"
# Same formula as state_storage_account_name in terraform/modules/stack/locals.tf.
if command -v md5sum >/dev/null 2>&1; then
  hash="$(printf '%s' "$subscription_id" | md5sum | awk '{print $1}' | cut -c1-10)"
else
  hash="$(python3 -c 'import hashlib,sys; print(hashlib.md5(sys.argv[1].encode()).hexdigest()[:10])' "$subscription_id")"
fi
account="sttf${env_name}${hash}"

if [[ "$env_name" == "prod" ]]; then
  replication="GRS"
else
  replication="LRS"
fi

backend=(
  -backend-config="resource_group_name=${rg}"
  -backend-config="storage_account_name=${account}"
  -backend-config="container_name=tfstate"
  -backend-config="use_azuread_auth=true"
)

apply_bootstrap() {
  terraform -chdir=terraform/bootstrap apply -input=false -auto-approve \
    -var="environment=${env_name}" \
    -var="resource_group_name=${rg}" \
    -var="storage_account_name=${account}" \
    -var="account_replication_type=${replication}"
}

backend_file="$root/terraform/bootstrap/backend.tf"
backend_off="$root/terraform/bootstrap/backend.tf.off"
restore_backend() {
  if [[ -f "$backend_off" && ! -f "$backend_file" ]]; then
    mv "$backend_off" "$backend_file"
  fi
}
trap restore_backend EXIT

if ! az storage account show --name "$account" --resource-group "$rg" >/dev/null 2>&1; then
  # The state account does not exist yet, so this first apply keeps its state locally.
  mv "$backend_file" "$backend_off"
  rm -rf terraform/bootstrap/.terraform
  terraform -chdir=terraform/bootstrap init -input=false -reconfigure
  apply_bootstrap
  mv "$backend_off" "$backend_file"
  migrated=0
  for _ in $(seq 1 10); do
    if terraform -chdir=terraform/bootstrap init -input=false -migrate-state -force-copy \
      "${backend[@]}" -backend-config="key=bootstrap.tfstate"; then
      migrated=1
      break
    fi
    echo "Waiting for permission to write the state blob."
    sleep 15
  done
  if [[ "$migrated" -ne 1 ]]; then
    echo "Could not move bootstrap state into ${account}." >&2
    exit 1
  fi
else
  terraform -chdir=terraform/bootstrap init -input=false -reconfigure \
    "${backend[@]}" -backend-config="key=bootstrap.tfstate"
  apply_bootstrap
fi

terraform -chdir=terraform init -input=false -reconfigure \
  "${backend[@]}" -backend-config="key=shared-infra.tfstate"

echo "State account ${account} in ${rg}."
