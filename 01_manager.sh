#!/usr/bin/env bash
# manager.sh - 管理 Guacamole Compose 與錄影轉檔（符合你的 01/02/03 流程）

set -euo pipefail

# === 基本設定（依你的環境可用環境變數覆蓋） ===
PROJECT_NAME=${PROJECT_NAME:-guac}
COMPOSE_FILE=${COMPOSE_FILE:-docker-compose.yml}
ROOT_DIR=$(cd "$(dirname "$0")" && pwd)

# 錄影與轉檔
REC_DIR=${REC_DIR:-"$ROOT_DIR/recordings"}   # 與 compose 綁定: ./recordings:/var/lib/guacamole/recordings
ENC_DIR=${ENC_DIR:-"$ROOT_DIR/encoded"}      # 本機轉檔輸出
REC_UID=${REC_UID:-1000}                     # 依你的 02_init_recordings.sh
REC_GID=${REC_GID:-1001}
REC_MODE=${REC_MODE:-2750}

# DB 初始化 SQL 檔
INIT_SQL=${INIT_SQL:-"$ROOT_DIR/initdb.sql"}

# guacenc 容器（如有 encoder.Dockerfile）
ENC_IMAGE=${ENC_IMAGE:-"guac-encoder:1.6.0"}

# Logs 目錄
LOG_DIR=${LOG_DIR:-"$ROOT_DIR/log"}

# sudo 包裝（root 則不加 sudo）
SUDO=""; [[ ${EUID:-$(id -u)} -ne 0 ]] && SUDO="sudo"

# 自動偵測 docker compose 指令
dc() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
note(){ printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
ok(){ printf "\033[32m[OK]\033[0m %s\n" "$*"; }
err(){ printf "\033[31m[ERR]\033[0m %s\n" "$*" >&2; }

usage(){
cat <<EOF
用法：$0 <command> [args]

主要：
  up                   啟動（自動 init-recordings，背景）
  down                 停止並移除容器
  restart              重啟（down -> up）
  status               顯示狀態（compose + docker）
  ps                   docker compose ps
  logs [svc]           追蹤日誌（螢幕顯示，可指定 guacdb|guacd|guacamole）
  exec <svc> [cmd]     進入或在指定 service 內執行命令（預設 bash -> sh）

初始化：
  initdb               產生 initdb.sql（若不存在；等同 01_install_guac_init_db.sh）
  init-recordings      建立 recordings/ 並設定擁有者與權限（等同 02_init_recordings.sh）
  init-all             依序 initdb -> init-recordings -> up

轉檔（需有 ENC_IMAGE 或主機已安裝 guacenc）：
  build-encoder        用 encoder.Dockerfile 建置 $ENC_IMAGE
  encode <UUID>        將 recordings/<UUID>/recording -> encoded/<UUID>.m4v
  encode-raw <PATH>    指定協定轉儲檔（如 /recordings/<UUID>/recording）轉 m4v

Logs 存檔：
  logs-save [svc]      一次性把 logs 存到檔案（不跟隨）
  logs-follow [svc]    一邊顯示、一邊把 logs 追加到檔案（Ctrl+C 結束）
  logs-start [svc]     在背景持續把 logs 追加到檔案（建立 PID 檔）
  logs-stop  [svc]     停止背景 logs 寫檔

清理：
  prune                docker system prune -f

環境：
  env                  顯示目前設定
EOF
}

ensure_dirs_and_perms() {
  mkdir -p "$REC_DIR" "$ENC_DIR"
  $SUDO chown -R "${REC_UID}:${REC_GID}" "$REC_DIR" || true
  $SUDO chmod -R "${REC_MODE}" "$REC_DIR" || true
}

ensure_log_dir() {
  mkdir -p "$LOG_DIR"
}

timestamp() { date +%Y%m%d_%H%M%S; }

# 產生 log 檔案路徑
log_file_path() {
  local label="$1"    # all 或服務名
  local mode="$2"     # snap / follow
  local ts="$(timestamp)"
  case "$mode" in
    snap)   echo "$LOG_DIR/${PROJECT_NAME}_${label}_${ts}.log" ;;
    follow) echo "$LOG_DIR/${PROJECT_NAME}_${label}_follow.log" ;;
    *)      echo "$LOG_DIR/${PROJECT_NAME}_${label}_${ts}.log" ;;
  esac
}

# 產生/取得 PID 檔路徑（背景 logger 用）
log_pid_file() {
  local label="$1"
  echo "$LOG_DIR/.logs.${label}.pid"
}

# 檢查背景 logger 是否在跑
is_logger_running() {
  local pidfile; pidfile="$(log_pid_file "$1")"
  [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

cmd="${1:-}"; shift || true
case "$cmd" in
  up)
    ensure_dirs_and_perms
    dc up -d
    ok "Stack started. 用 '$0 status' 查看狀態。"
    ;;
  down)
    dc down
    ;;
  restart)
    ensure_dirs_and_perms
    dc down
    dc up -d
    ;;
  status)
    bold "== docker compose ps =="
    dc ps || true
    echo
    # bold "== docker ps (filtered by project '${PROJECT_NAME}_') =="
    # docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "^${PROJECT_NAME}_" || true
    ;;
  ps)
    dc ps
    ;;
  logs)
    svc="${1:-}"; shift || true
    if [[ -n "$svc" ]]; then
      dc logs -f --tail=200 "$svc"
    else
      dc logs -f --tail=200
    fi
    ;;
  exec)
    svc="${1:-}"; shift || true
    if [[ -z "$svc" ]]; then err "請指定 service（guacdb|guacd|guacamole）"; exit 2; fi
    if dc exec -T "$svc" bash -lc 'exit' 2>/dev/null; then
      dc exec -it "$svc" bash -lc "${*:-bash}"
    else
      dc exec -it "$svc" sh -lc "${*:-sh}"
    fi
    ;;
  init-db|initdb)
    if [[ -f "$INIT_SQL" ]]; then
      ok "initdb.sql 已存在：$INIT_SQL"
    else
      bold "生成 initdb.sql ..."
      docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --mysql > "$INIT_SQL"
      ok "已產生：$INIT_SQL"
      note "首次啟動時會由 compose 的 guacdb 自動匯入此 SQL。"
    fi
    ;;
  init-recordings)
    ensure_dirs_and_perms
    ok "recordings 目錄權限已設定為 UID=${REC_UID} GID=${REC_GID} MODE=${REC_MODE}：$REC_DIR"
    ;;
  init-all)
    "$0" init-db
    "$0" init-recordings
    "$0" up
    ;;
  env)
    echo "PROJECT_NAME = $PROJECT_NAME"
    echo "COMPOSE_FILE = $COMPOSE_FILE"
    echo "ROOT_DIR     = $ROOT_DIR"
    echo "REC_DIR      = $REC_DIR"
    echo "ENC_DIR      = $ENC_DIR"
    echo "REC_UID:GID  = ${REC_UID}:${REC_GID}"
    echo "REC_MODE     = $REC_MODE"
    echo "INIT_SQL     = $INIT_SQL"
    echo "ENC_IMAGE    = $ENC_IMAGE"
    echo "LOG_DIR      = $LOG_DIR"
    ;;
  build-encoder)
    bold "建置 $ENC_IMAGE ..."
    docker build -f encoder.Dockerfile -t "$ENC_IMAGE" "$ROOT_DIR"
    ok "完成：$ENC_IMAGE"
    ;;
  encode)
    UUID="${1:-}"; shift || true
    if [[ -z "$UUID" ]]; then err "請提供 UUID"; exit 2; fi
    SRC="$REC_DIR/$UUID/recording"
    if [[ ! -f "$SRC" ]]; then err "找不到 $SRC"; exit 3; fi
    mkdir -p "$ENC_DIR"
    docker run --rm \
      -v "$REC_DIR":/recordings:ro \
      -v "$ENC_DIR":/encoded \
      "$ENC_IMAGE" \
      "/recordings/$UUID/recording"
    if [[ -f "$REC_DIR/$UUID/recording.m4v" ]]; then
      mv "$REC_DIR/$UUID/recording.m4v" "$ENC_DIR/$UUID.m4v"
      ok "完成：$ENC_DIR/$UUID.m4v"
    else
      err "轉檔未找到 output：$REC_DIR/$UUID/recording.m4v"
      exit 4
    fi
    ;;
  encode-raw)
    RAW="${1:-}"; shift || true
    if [[ -z "$RAW" ]]; then err "請提供 dump 檔路徑"; exit 2; fi
    base=$(basename "$RAW"); uuid=${base:-manual}
    mkdir -p "$ENC_DIR"
    docker run --rm \
      -v "$REC_DIR":/recordings:ro \
      -v "$ENC_DIR":/encoded \
      "$ENC_IMAGE" \
      "$RAW"
    if [[ -f "${RAW}.m4v" ]]; then
      mv "${RAW}.m4v" "$ENC_DIR/${uuid}.m4v"
      ok "完成：$ENC_DIR/${uuid}.m4v"
    else
      err "轉檔未找到 output：${RAW}.m4v"
      exit 4
    fi
    ;;
  # ===== Logs 存檔 =====
  logs-save)
    ensure_log_dir
    svc="${1:-}"; shift || true
    label="${svc:-all}"
    outfile="$(log_file_path "$label" snap)"
    bold "儲存 logs -> $outfile"
    if [[ -n "$svc" ]]; then
      dc logs --no-color --timestamps "$svc" > "$outfile"
    else
      dc logs --no-color --timestamps > "$outfile"
    fi
    ok "完成：$outfile"
    ;;
  logs-follow)
    ensure_log_dir
    svc="${1:-}"; shift || true
    label="${svc:-all}"
    outfile="$(log_file_path "$label" follow)"
    bold "跟隨 logs（同時寫入）-> $outfile"
    if [[ -n "$svc" ]]; then
      dc logs -f --no-color --timestamps "$svc" | tee -a "$outfile"
    else
      dc logs -f --no-color --timestamps | tee -a "$outfile"
    fi
    ;;
  logs-start)
    ensure_log_dir
    svc="${1:-}"; shift || true
    label="${svc:-all}"
    pidfile="$(log_pid_file "$label")"
    outfile="$(log_file_path "$label" follow)"
    if is_logger_running "$label"; then
      note "背景 logger 已在執行（$(cat "$pidfile")），檔案：$outfile"
      exit 0
    fi
    bold "在背景持續寫入 logs -> $outfile"
    # 用 nohup 背景執行，將 stderr/stdout 追加進檔案
    if [[ -n "$svc" ]]; then
      nohup bash -lc "docker compose logs -f --no-color --timestamps '$svc' >> '$outfile' 2>&1" >/dev/null 2>&1 &
    else
      nohup bash -lc "docker compose logs -f --no-color --timestamps >> '$outfile' 2>&1" >/dev/null 2>&1 &
    fi
    echo $! > "$pidfile"
    ok "背景 logger PID：$(cat "$pidfile")"
    ;;
  logs-stop)
    svc="${1:-}"; shift || true
    label="${svc:-all}"
    pidfile="$(log_pid_file "$label")"
    if ! [[ -f "$pidfile" ]]; then
      err "找不到背景 logger PID 檔：$pidfile"
      exit 1
    fi
    pid="$(cat "$pidfile")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" || true
      sleep 0.5
      if kill -0 "$pid" 2>/dev/null; then
        note "進程仍在，改送 SIGKILL"
        kill -9 "$pid" || true
      fi
      ok "已停止背景 logger（PID $pid）"
    else
      note "背景 logger 已不在執行"
    fi
    rm -f "$pidfile"
    ;;
  prune)
    docker system prune -f
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    err "未知指令：$cmd"
    usage
    exit 2
    ;;
esac
