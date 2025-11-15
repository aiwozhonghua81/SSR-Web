#!/usr/bin/env bash
set -e

# 安装 Docker
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | bash
fi

# 安装 docker compose plugin（适配新版本）
if ! docker compose version &>/dev/null; then
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p $DOCKER_CONFIG/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-$(uname -s)-$(uname -m) -o $DOCKER_CONFIG/cli-plugins/docker-compose
  chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
fi

echo "[+] 拉起 ssr-web-manager"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR/.."

docker compose up -d --build

echo "[+] 访问 http://<服务器IP>:8080"
