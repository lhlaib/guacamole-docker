#!/bin/bash
set -e

# =============================================
# 安裝 Docker Engine 與 Docker Compose Plugin
# 適用於 Ubuntu 24.04
# =============================================

echo "🔧 Step 1: 移除舊版本 Docker"
# sudo apt remove -y docker docker-engine docker.io containerd runc || true

echo "🧰 Step 2: 安裝必要依賴並新增 Docker 官方套件庫"
# 更新套件索引與升級系統
sudo apt update && sudo apt upgrade -y

# 安裝必要套件
sudo apt install -y ca-certificates curl gnupg

# 建立金鑰資料夾並加入 Docker GPG 金鑰
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 設定 Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新 apt 套件索引
sudo apt update

echo "🐳 Step 3: 安裝 Docker Engine 與 Compose Plugin"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "🚀 Step 4: 啟動 Docker 並設定開機啟動"
sudo systemctl start docker
sudo systemctl enable docker

echo "✅ Step 5: 測試 Docker 安裝"
sudo docker run hello-world

echo "👥 Step 6: 將當前使用者加入 docker 群組（選擇性）"
sudo usermod -aG docker $USER
echo "➡️ 請登出並重新登入，或手動執行 'newgrp docker' 使設定生效"
sudo newgrp docker

echo "🔎 Step 7: 測試 Docker Compose Plugin"
docker compose version || echo "請重新登入後再測試 docker compose 指令"

echo "🎉 Docker 與 Docker Compose 安裝完成！"

