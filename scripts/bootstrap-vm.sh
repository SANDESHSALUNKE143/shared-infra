#!/usr/bin/env bash
# Install Docker and the Elasticsearch memory settings on Ubuntu.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script as root: sudo scripts/bootstrap-vm.sh" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl openssl python3 python3-jinja2

if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

install -d /etc/sysctl.d
echo "vm.max_map_count=262144" > /etc/sysctl.d/99-shared-infra.conf
sysctl -w vm.max_map_count=262144

if command -v systemctl >/dev/null 2>&1; then
  install -d /etc/systemd/system/docker.service.d
  cat > /etc/systemd/system/docker.service.d/memlock.conf << 'EOF'
[Service]
LimitMEMLOCK=infinity
EOF
  systemctl daemon-reload
  systemctl enable docker
  systemctl restart docker
fi

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  usermod -aG docker "$SUDO_USER"
  echo "Added ${SUDO_USER} to the docker group. Open a new shell before docker compose."
fi

echo "Docker is installed. Clone this folder to /opt/shared-infra and run scripts/up.sh."
