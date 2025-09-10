#!/usr/bin/env bash
set -euo pipefail

# =============================================
# 安裝 Docker Engine 與 Docker Compose Plugin
# 支援：Ubuntu 20.04/22.04/24.04、Rocky/Alma/CentOS 8/9
# =============================================

# ---------- Helper ----------
log()  { echo -e "$1"; }
ok()   { echo -e "✅ $1"; }
step() { echo -e "\n\033[1;34m==> $1\033[0m"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ 需求指令不存在：$1"; exit 1; }
}

# ---------- Detect OS ----------
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
else
  echo "❌ 無法判斷作業系統（找不到 /etc/os-release）"
  exit 1
fi

OS_FAMILY=""
case "${ID:-}${ID_LIKE:+,$ID_LIKE}" in
  *ubuntu*|*debian*)
    OS_FAMILY="ubuntu"
    ;;
  *rhel*|*centos*|*fedora*|*rocky*|*almalinux*)
    OS_FAMILY="rhel"
    ;;
  *)
    echo "❌ 未支援的作業系統：ID=${ID:-?}, ID_LIKE=${ID_LIKE:-?}"
    exit 1
    ;;
esac

step "偵測到系統：${PRETTY_NAME:-$ID}（家族：$OS_FAMILY）"

# ---------- Common preflight ----------
if [[ $EUID -ne 0 ]]; then
  step "需要 sudo 權限"
  require_cmd sudo
fi

# ---------- Install (Ubuntu/Debian family) ----------
install_docker_ubuntu() {
  step "更新套件索引與升級系統"
  sudo apt update
  sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade

  step "安裝必要依賴"
  sudo apt install -y ca-certificates curl gnupg lsb-release

  step "設定 Docker 官方 GPG 金鑰與套件庫"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  UB_CODENAME="$(lsb_release -cs)"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UB_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  step "更新 apt 套件索引"
  sudo apt update

  step "安裝 Docker Engine 與 Compose Plugin"
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  step "啟動並設定開機啟動"
  sudo systemctl enable --now docker

  ok "Ubuntu 系列安裝完成"
}

# ---------- Install (RHEL/Rocky/Alma/CentOS family) ----------
install_docker_rhel() {
  step "清理 DNF 快取並升級系統（先確保基礎庫一致）"
  sudo dnf clean all
  sudo dnf -y makecache
  sudo dnf -y upgrade

  step "移除舊版 Docker（若有）"
  sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true

  step "安裝工具並加入 Docker 官方套件庫"
  sudo dnf -y install dnf-plugins-core curl ca-certificates
  # Docker 官方建議 RHEL 家族使用 CentOS repo
  sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

  step "刷新 metadata 後再升級一次（確保依賴解決）"
  sudo dnf -y makecache
  sudo dnf -y upgrade

  step "安裝 Docker Engine 與 Compose Plugin"
  sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  step "啟動並設定開機啟動"
  sudo systemctl enable --now docker

  ok "RHEL/Rocky/Alma/CentOS 系列安裝完成"
}

# ---------- Run installer ----------
case "$OS_FAMILY" in
  ubuntu) install_docker_ubuntu ;;
  rhel)   install_docker_rhel ;;
esac

# ---------- Post install checks ----------
step "測試 Docker 服務狀態"
sudo systemctl --no-pager status docker | sed -n '1,10p' || true

step "測試 Docker Engine"
if sudo docker run --rm hello-world >/dev/null 2>&1; then
  ok "Docker hello-world 下載與執行成功"
else
  log "⚠️ 無法執行 hello-world（可能是網路受限或 registry 被擋）"
fi

step "將目前使用者加入 docker 群組（選擇性）"
if getent group docker >/dev/null 2>&1; then
  sudo usermod -aG docker "$USER" || true
else
  sudo groupadd docker || true
  sudo usermod -aG docker "$USER" || true
fi
ok "已將 $USER 加入 docker 群組"

# 你原本就指定要自動執行；注意：此指令會開新 shell，只對目前會話生效
echo "➡️ 建議『登出並重新登入』以確保 docker 群組權限在所有新 shell 生效。"
sudo newgrp docker

step "測試 Docker Compose Plugin"
if docker compose version >/dev/null 2>&1; then
  ok "docker compose 可用"
else
  log "⚠️ 目前無法讀取 docker compose，請重新登入後再試：docker compose version"
fi

ok "🎉 Docker 與 Docker Compose 安裝流程完成！"
echo "➡️ 建議『登出並重新登入』以確保 docker 群組權限在所有新 shell 生效。"
