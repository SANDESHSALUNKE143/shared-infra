#!/bin/bash
# First boot and every reboot: mount the data disk, install Docker, write .env, start Compose.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export GIT_TERMINAL_PROMPT=0

echo "shared-infra boot starting"

apt-get update
apt-get install -y ca-certificates curl openssl python3 python3-jinja2 git jq e2fsprogs

disk=/dev/disk/azure/scsi1/lun0
found=0
for _ in $(seq 1 60); do
  if [ -b "$disk" ]; then
    found=1
    break
  fi
  echo "waiting for the data disk"
  sleep 10
done
if [ "$found" -ne 1 ]; then
  echo "Data disk did not appear at $disk" >&2
  exit 1
fi

if ! blkid "$disk" >/dev/null 2>&1; then
  mkfs.ext4 -F -L dockerdata "$disk"
fi
mkdir -p /var/lib/docker
if ! grep -q 'LABEL=dockerdata' /etc/fstab; then
  echo 'LABEL=dockerdata /var/lib/docker ext4 defaults,nofail 0 2' >> /etc/fstab
fi
if ! mountpoint -q /var/lib/docker; then
  mount /var/lib/docker
fi

if [ ! -d /opt/shared-infra/.git ]; then
  rm -rf /opt/shared-infra
  git clone --depth 1 --branch ${github_branch} "https://github.com/${github_repository}.git" /opt/shared-infra
fi
if ! git config --system --get-all safe.directory 2>/dev/null | grep -qx /opt/shared-infra; then
  git config --system --add safe.directory /opt/shared-infra
fi

bash /opt/shared-infra/scripts/bootstrap-vm.sh

token_url="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net&client_id=${identity_client_id}"
secret_url="https://${key_vault_name}.vault.azure.net/secrets/storage-connection-string?api-version=7.4"
conn=""
for _ in $(seq 1 40); do
  if token_json=$(curl -fsS -H Metadata:true "$token_url"); then
    access=$(printf '%s' "$token_json" | jq -r .access_token)
    if secret_json=$(curl -fsS -H "Authorization: Bearer $access" "$secret_url"); then
      conn=$(printf '%s' "$secret_json" | jq -r .value)
      if [ -n "$conn" ] && [ "$conn" != "null" ]; then
        break
      fi
    fi
  fi
  echo "waiting for the storage connection string"
  sleep 15
done
if [ -z "$conn" ] || [ "$conn" = "null" ]; then
  echo "Key Vault did not return the storage connection string." >&2
  exit 1
fi

# A Standard public IP stays blank in instance metadata, so the address is rendered here.
public_host='${public_ip}'
if [ -z "$public_host" ]; then
  echo "Terraform did not render a public IP." >&2
  exit 1
fi

if [ ! -f /opt/shared-infra/.env ]; then
  bash /opt/shared-infra/scripts/init-env.sh
fi

export SHARED_INFRA_ENV_NAME='${environment}'
export SHARED_INFRA_PUBLIC_HOST="$public_host"
export SHARED_INFRA_CONNECTION_STRING="$conn"
python3 - << 'PY'
import os
import pathlib

path = pathlib.Path("/opt/shared-infra/.env")
text = path.read_text(encoding="utf-8")
updates = {
    "ENV_NAME": os.environ["SHARED_INFRA_ENV_NAME"],
    "PUBLIC_HOST": os.environ["SHARED_INFRA_PUBLIC_HOST"],
    "AZURE_STORAGE_CONNECTION_STRING": os.environ["SHARED_INFRA_CONNECTION_STRING"],
}

def quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"

lines = text.splitlines()
seen = set()
out = []
for line in lines:
    key, sep, _value = line.partition("=")
    if sep and key in updates:
        out.append(key + "=" + quote(updates[key]))
        seen.add(key)
    else:
        out.append(line)
for key, value in updates.items():
    if key not in seen:
        out.append(key + "=" + quote(value))
path.write_text("\n".join(out) + "\n", encoding="utf-8")
path.chmod(0o600)
PY

export SHARED_INFRA_QUIET=1
bash /opt/shared-infra/scripts/up.sh

admin='${admin_username}'
if id "$admin" >/dev/null 2>&1; then
  usermod -aG docker "$admin"
  chown -R "$admin:$admin" /opt/shared-infra
fi
chmod 600 /opt/shared-infra/.env
for f in \
  grafana/provisioning/datasources/datasources.yml \
  alertmanager/alertmanager.yml \
  loki/loki.yml \
  prometheus/prometheus.yml
do
  if [ -f "/opt/shared-infra/$f" ]; then
    chmod 600 "/opt/shared-infra/$f"
  fi
done

echo "shared-infra boot finished"
