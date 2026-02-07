#!/bin/bash
set -euo pipefail

NOTES_FILE="$HOME/.terminal_notes"

print_help() {
  cat <<'EOF'
Usage: ./terminal_manager.sh <command> [args]

Commands:
  list                             List user processes with notes and ports
  note <pid> "comment"             Add/update note for a PID
  note-pane <session:win.pane> "comment"  Add/update note for a tmux pane
  kill <pid> [--force]             Kill process by PID
  kill-port <port> [--force]       Kill process(es) listening on port
  attach <session>                 Attach to tmux session
  kill-session <session>           Kill tmux session
  menu                             Interactive menu
  help                             Show this help

Notes are stored in: ~/.terminal_notes
EOF
}

ensure_notes_file() {
  if [ ! -f "$NOTES_FILE" ]; then
    touch "$NOTES_FILE"
  fi
}

require_arg() {
  local value="$1"
  local message="$2"
  if [ -z "$value" ]; then
    echo "$message" >&2
    exit 1
  fi
}

confirm_kill() {
  local target="$1"
  local force="${2:-}"
  if [ "$force" = "--force" ]; then
    return 0
  fi
  read -r -p "Confirm kill $target? [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

require_tmux() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux not found. Install tmux to use this command." >&2
    exit 1
  fi
}

set_note() {
  local key="$1"
  local note="$2"
  ensure_notes_file
  awk -F= -v k="$key" '$1!=k' "$NOTES_FILE" > "${NOTES_FILE}.tmp" || true
  printf "%s=%s\n" "$key" "$note" >> "${NOTES_FILE}.tmp"
  mv "${NOTES_FILE}.tmp" "$NOTES_FILE"
}

get_note() {
  local key="$1"
  if [ -f "$NOTES_FILE" ]; then
    awk -F= -v k="$key" '$1==k{print substr($0, index($0,"=")+1); exit}' "$NOTES_FILE"
  fi
}

list_tmux_panes() {
  if command -v tmux >/dev/null 2>&1; then
    tmux list-panes -a -F '#S:#I.#P #{pane_pid} #{pane_current_command}' 2>/dev/null || true
  fi
}

port_for_pid() {
  local pid="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -Pan -p "$pid" -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1{print $9}' | sed 's/.*://'
    return 0
  fi
  if command -v ss >/dev/null 2>&1; then
    ss -lptn 2>/dev/null | awk -v pid="$pid" '$0 ~ "pid="pid"," {print $4}' | sed 's/.*://'
    return 0
  fi
  echo "-"
}

list_processes() {
  echo "PID  PPID TTY   STAT ELAPSED PORT CMD"
  ps -u "$USER" -o pid=,ppid=,tty=,stat=,etimes=,args= | while read -r pid ppid tty stat etimes cmd; do
    port=$(port_for_pid "$pid" | head -n1 || true)
    note=$(get_note "pid:${pid}")
    if [ -n "$note" ]; then
      printf "%s %s %s %s %s %s %s  # %s\n" "$pid" "$ppid" "$tty" "$stat" "$etimes" "${port:--}" "$cmd" "$note"
    else
      printf "%s %s %s %s %s %s %s\n" "$pid" "$ppid" "$tty" "$stat" "$etimes" "${port:--}" "$cmd"
    fi
  done

  echo ""
  echo "TMUX PANES"
  list_tmux_panes | while read -r pane_line; do
    pane_id=$(echo "$pane_line" | awk '{print $1}')
    note=$(get_note "pane:${pane_id}")
    if [ -n "$note" ]; then
      echo "$pane_line  # $note"
    else
      echo "$pane_line"
    fi
  done
}

kill_port() {
  local port="$1"
  require_arg "$port" "Missing port"
  if command -v lsof >/dev/null 2>&1; then
    pids=$(lsof -t -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
  elif command -v ss >/dev/null 2>&1; then
    pids=$(ss -lptn 2>/dev/null | awk -v p=":$port" '$4 ~ p {print $NF}' | sed -E 's/.*pid=([0-9]+).*/\1/' | sort -u)
  else
    echo "Neither lsof nor ss found. Install lsof or iproute2." >&2
    exit 1
  fi
  if [ -z "$pids" ]; then
    echo "No process found listening on port $port."
    exit 0
  fi
  if confirm_kill "port $port" "${2:-}"; then
    echo "$pids" | xargs -r kill
  fi
}

menu() {
  echo "1) List processes"
  echo "2) Add note to PID"
  echo "3) Add note to tmux pane"
  echo "4) Kill PID"
  echo "5) Kill port"
  echo "6) Attach tmux session"
  echo "7) Kill tmux session"
  echo "8) Quit"
  read -r -p "Select: " choice
  case "$choice" in
    1) list_processes ;;
    2) read -r -p "PID: " pid; read -r -p "Note: " note; set_note "pid:${pid}" "$note" ;;
    3) read -r -p "Pane (session:win.pane): " pane; read -r -p "Note: " note; set_note "pane:${pane}" "$note" ;;
    4) read -r -p "PID: " pid; if confirm_kill "pid ${pid}"; then kill "$pid"; fi ;;
    5) read -r -p "Port: " port; kill_port "$port" ;;
    6) read -r -p "Session: " sess; require_tmux; tmux attach -t "$sess" ;;
    7) read -r -p "Session: " sess; require_tmux; tmux kill-session -t "$sess" ;;
    *) exit 0 ;;
  esac
}

cmd="${1:-help}"
case "$cmd" in
  list) list_processes ;;
  note)
    require_arg "${2:-}" "Missing PID"
    require_arg "${3:-}" "Missing note"
    set_note "pid:${2}" "${3}"
    ;;
  note-pane)
    require_arg "${2:-}" "Missing pane"
    require_arg "${3:-}" "Missing note"
    set_note "pane:${2}" "${3}"
    ;;
  kill)
    require_arg "${2:-}" "Missing PID"
    if confirm_kill "pid ${2}" "${3:-}"; then
      kill "${2}"
    fi
    ;;
  kill-port) kill_port "${2:-}" "${3:-}" ;;
  attach) require_tmux; tmux attach -t "${2:-}" ;;
  kill-session) require_tmux; tmux kill-session -t "${2:-}" ;;
  menu) menu ;;
  help|--help|-h) print_help ;;
  *) print_help; exit 1 ;;
esac
