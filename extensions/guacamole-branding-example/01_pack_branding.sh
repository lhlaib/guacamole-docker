#!/usr/bin/env bash
# pack-branding.sh — 固定打包為 ../guacamole-branding-example.jar
set -euo pipefail

OUT="../guacamole-branding-example.jar"     # 固定輸出檔名
EXCLUDES=(
  "*/.git/*" "*.gitignore" "*.gitattributes"
  "*.DS_Store"
  "*/node_modules/*" "*/dist/*" "*/build/*"
  "*/.idea/*" "*/.vscode/*"
  "*/tmp/*" "*/logs/*"
)

need_cmd(){ command -v "$1" >/dev/null 2>&1; }
is_root(){ [ "${EUID:-$(id -u)}" -eq 0 ]; }
sudo_cmd(){ if is_root; then "$@"; else sudo "$@"; fi; }

try_install_zip(){
  need_cmd zip && return 0
  if need_cmd apt-get; then
    sudo_cmd apt-get update -y || true
    sudo_cmd apt-get install -y zip || true
  elif need_cmd dnf; then
    sudo_cmd dnf install -y zip || true
  elif need_cmd yum; then
    sudo_cmd yum install -y zip || true
  elif need_cmd apk; then
    sudo_cmd apk add --no-cache zip || true
  elif need_cmd brew; then
    brew install zip || true
  fi
  need_cmd zip
}

print_size(){
  if need_cmd du; then du -h "$1" | awk '{print $1}'; elif need_cmd wc; then wc -c <"$1"; else echo "?"; fi
}

# 檢查基本檔案
if [ ! -f "guac-manifest.json" ]; then
  echo "⚠️  找不到 guac-manifest.json，請確認在品牌擴充『根目錄』執行。" >&2
fi

# 準備輸出路徑
OUT_DIR="$(dirname -- "$OUT")"
mkdir -p "$OUT_DIR"
[ -f "$OUT" ] && rm -f "$OUT"   # 先刪舊檔，避免 zip 追加

USE="zip"
if ! need_cmd zip; then
  echo "ℹ️  zip 未找到，嘗試安裝…"
  if ! try_install_zip; then
    echo "⚠️  安裝 zip 失敗，改用 JDK 的 jar（若可用）。"
    if ! need_cmd jar; then
      echo "❌  找不到 zip 或 jar，無法打包。" >&2
      exit 1
    fi
    USE="jar"
  fi
fi

echo "📦  打包為：$OUT"
if [ "$USE" = "zip" ]; then
  zip -r -X "$OUT" ./ -x "${EXCLUDES[@]}"
else
  # jar 版（用 find 篩掉雜項）
  mapfile -t FILES < <(
    find . -type d \( -name .git -o -name node_modules -o -name dist -o -name build -o -name .idea -o -name .vscode -o -name tmp -o -name logs \) -prune -o \
           -type f ! -name ".DS_Store" -print
  )
  CLEANED=(); for f in "${FILES[@]}"; do CLEANED+=( "${f#./}" ); done
  # shellcheck disable=SC2086
  jar cf "$OUT" ${CLEANED[@]+"${CLEANED[@]}"}
fi

if need_cmd unzip; then unzip -t "$OUT" >/dev/null 2>&1 && echo "✅  壓縮檔測試通過"; fi
echo "📁  完成：$OUT  （大小：$(print_size "$OUT")）"
echo "ℹ️  將此 .jar 放到 /etc/guacamole/extensions/（或對應 volume）後重啟 guacamole 容器生效。"
