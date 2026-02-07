#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "🔎 正在检索可用项目目录..."
mapfile -t PROJECT_DIRS < <(find "$SCRIPT_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | grep -vE '^(ralph-claude-code|\.claude|\.git)$' | sort)

if [ ${#PROJECT_DIRS[@]} -eq 0 ]; then
  echo "❌ 未找到可用项目目录"
  exit 1
fi

echo "请选择项目目录:"
for i in "${!PROJECT_DIRS[@]}"; do
  echo "  $((i+1))) ${PROJECT_DIRS[$i]}"
done

read -p "请输入序号: " SELECT_IDX
if ! [[ "$SELECT_IDX" =~ ^[0-9]+$ ]] || [ "$SELECT_IDX" -lt 1 ] || [ "$SELECT_IDX" -gt ${#PROJECT_DIRS[@]} ]; then
  echo "❌ 无效选择"
  exit 1
fi

ROOT_DIR="${PROJECT_DIRS[$((SELECT_IDX-1))]}"
ROOT_DIR=$(cd "$SCRIPT_DIR/$ROOT_DIR" && pwd)

pick_dir() {
  local label="$1"
  shift
  local candidates=("$@")
  if [ ${#candidates[@]} -eq 0 ]; then
    echo ""
    return
  fi
  echo "请选择${label}目录:"
  for i in "${!candidates[@]}"; do
    echo "  $((i+1))) ${candidates[$i]}"
  done
  read -p "请输入序号: " CHOICE
  if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#candidates[@]} ]; then
    echo ""
    return
  fi
  echo "${candidates[$((CHOICE-1))]}"
}

BACKEND_DIR=""
FRONTEND_DIR=""

if [ -d "$ROOT_DIR/factory-explorer/backend" ] && [ -d "$ROOT_DIR/factory-explorer/frontend" ]; then
  BACKEND_DIR="$ROOT_DIR/factory-explorer/backend"
  FRONTEND_DIR="$ROOT_DIR/factory-explorer/frontend"
elif [ -d "$ROOT_DIR/backend" ] && [ -d "$ROOT_DIR/frontend" ]; then
  BACKEND_DIR="$ROOT_DIR/backend"
  FRONTEND_DIR="$ROOT_DIR/frontend"
else
  mapfile -t BACKEND_CANDIDATES < <(find "$ROOT_DIR" -maxdepth 3 -type d -name backend -printf '%p\n' | sort)
  mapfile -t FRONTEND_CANDIDATES < <(find "$ROOT_DIR" -maxdepth 3 -type d -name frontend -printf '%p\n' | sort)

  BACKEND_DIR=$(pick_dir "后端" "${BACKEND_CANDIDATES[@]}")
  FRONTEND_DIR=$(pick_dir "前端" "${FRONTEND_CANDIDATES[@]}")
fi

if [ -z "$BACKEND_DIR" ] || [ -z "$FRONTEND_DIR" ]; then
  echo "❌ 未找到后端或前端目录"
  exit 1
fi

backend_pid=""
frontend_pid=""
backend_kill_target=""
frontend_kill_target=""
cleaned_up=false

get_pids_by_port() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -ti ":${port}" 2>/dev/null | sort -u
    return
  fi
  if command -v ss >/dev/null 2>&1; then
    ss -ltnp "sport = :${port}" 2>/dev/null | awk -F'pid=' 'NR>1 {split($2,a,","); print a[1]}' | sort -u
  fi
  if command -v fuser >/dev/null 2>&1; then
    fuser -n tcp "${port}" 2>/dev/null | tr ' ' '\n' | sort -u
  fi
}

show_port_owners() {
  local port="$1"
  echo "占用端口 ${port} 的进程信息:"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true
    return
  fi
  if command -v ss >/dev/null 2>&1; then
    ss -ltnp "sport = :${port}" 2>/dev/null || true
  fi
}

ensure_port_free() {
  local port="$1"
  local pids
  for _ in {1..5}; do
    pids=$(get_pids_by_port "$port" || true)
    if [ -z "$pids" ]; then
      return
    fi
    echo "⚠️ 端口 ${port} 已被占用: ${pids}"
    show_port_owners "$port"
    read -p "是否结束占用进程? [y/N]: " KILL_IT
    if [[ "$KILL_IT" =~ ^[Yy]$ ]]; then
      if command -v fuser >/dev/null 2>&1; then
        fuser -k -n tcp "${port}" 2>/dev/null || true
      else
        echo "$pids" | xargs -r kill
      fi
      sleep 0.3
      continue
    fi
    echo "❌ 端口 ${port} 未释放，退出。"
    exit 1
  done

  pids=$(get_pids_by_port "$port" || true)
  if [ -n "$pids" ]; then
    echo "❌ 端口 ${port} 仍被占用: ${pids}"
    show_port_owners "$port"
    exit 1
  fi
}

cleanup() {
  if [ "$cleaned_up" = true ]; then
    return
  fi
  cleaned_up=true
  echo "\nStopping services..."
  if [[ -n "${frontend_pid}" ]] && kill -0 "${frontend_pid}" 2>/dev/null; then
    kill -INT ${frontend_kill_target:-"${frontend_pid}"} || true
  fi
  if [[ -n "${backend_pid}" ]] && kill -0 "${backend_pid}" 2>/dev/null; then
    kill -INT ${backend_kill_target:-"${backend_pid}"} || true
  fi
  for _ in {1..20}; do
    if [[ -n "${frontend_pid}" ]] && kill -0 "${frontend_pid}" 2>/dev/null; then
      sleep 0.2
      continue
    fi
    if [[ -n "${backend_pid}" ]] && kill -0 "${backend_pid}" 2>/dev/null; then
      sleep 0.2
      continue
    fi
    break
  done
  if [[ -n "${frontend_pid}" ]] && kill -0 "${frontend_pid}" 2>/dev/null; then
    kill -TERM ${frontend_kill_target:-"${frontend_pid}"} || true
  fi
  if [[ -n "${backend_pid}" ]] && kill -0 "${backend_pid}" 2>/dev/null; then
    kill -TERM ${backend_kill_target:-"${backend_pid}"} || true
  fi
  for _ in {1..10}; do
    if [[ -n "${frontend_pid}" ]] && kill -0 "${frontend_pid}" 2>/dev/null; then
      sleep 0.2
      continue
    fi
    if [[ -n "${backend_pid}" ]] && kill -0 "${backend_pid}" 2>/dev/null; then
      sleep 0.2
      continue
    fi
    break
  done
  if [[ -n "${frontend_pid}" ]] && kill -0 "${frontend_pid}" 2>/dev/null; then
    kill -KILL ${frontend_kill_target:-"${frontend_pid}"} || true
  fi
  if [[ -n "${backend_pid}" ]] && kill -0 "${backend_pid}" 2>/dev/null; then
    kill -KILL ${backend_kill_target:-"${backend_pid}"} || true
  fi
  wait || true
  local p8000 p3000
  p8000=$(get_pids_by_port 8000 || true)
  p3000=$(get_pids_by_port 3000 || true)
  if [ -z "$p8000" ] && [ -z "$p3000" ]; then
    echo "Ports 8000/3000 are free."
  else
    if [ -n "$p8000" ]; then
      echo "⚠️ 端口 8000 仍被占用: $p8000"
    fi
    if [ -n "$p3000" ]; then
      echo "⚠️ 端口 3000 仍被占用: $p3000"
    fi
  fi
  echo "Done."
}

trap cleanup EXIT

ensure_port_free 8000
ensure_port_free 3000

# Start backend
if command -v setsid >/dev/null 2>&1; then
  (
    cd "$BACKEND_DIR"
    exec setsid .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
  ) &
  backend_pid=$!
  backend_kill_target="-${backend_pid}"
else
  (
    cd "$BACKEND_DIR"
    exec .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
  ) &
  backend_pid=$!
  backend_kill_target="${backend_pid}"
fi

echo "Backend started (PID: $backend_pid)"

# Start frontend
ensure_port_free 3000
if command -v setsid >/dev/null 2>&1; then
  (
    cd "$FRONTEND_DIR"
    exec setsid pnpm exec next dev -p 3000 --hostname 0.0.0.0
  ) &
  frontend_pid=$!
  frontend_kill_target="-${frontend_pid}"
else
  (
    cd "$FRONTEND_DIR"
    exec pnpm exec next dev -p 3000 --hostname 0.0.0.0
  ) &
  frontend_pid=$!
  frontend_kill_target="${frontend_pid}"
fi

echo "Frontend started (PID: $frontend_pid)"

echo "Press Enter to stop both..."
read -r _

cleanup
