#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tmux-launch.sh [-s SESSION_NAME] [-c DIRECTORY] [-a] -- COMMAND [ARG...]
  tmux-launch.sh [-s SESSION_NAME] [-c DIRECTORY] [-a] COMMAND [ARG...]

Start COMMAND in a new tmux session.

Options:
  -s SESSION_NAME  Use this tmux session name
  -c DIRECTORY     Run the command from this directory (default: current directory)
  -a               Attach to the session after creating it
  -h               Show this help message
EOF
}

sanitize_session_name() {
  local value="${1:-}"

  value="${value//[^[:alnum:]_-]/-}"

  while [[ -n "$value" && ( "${value#-}" != "$value" || "${value#_}" != "$value" ) ]]; do
    value="${value#-}"
    value="${value#_}"
  done

  while [[ -n "$value" && ( "${value%-}" != "$value" || "${value%_}" != "$value" ) ]]; do
    value="${value%-}"
    value="${value%_}"
  done

  printf '%s' "$value"
}

join_command() {
  local quoted parts=()

  for arg in "$@"; do
    printf -v quoted '%q' "$arg"
    parts+=("$quoted")
  done

  printf '%s' "${parts[*]}"
}

print_tmux_install_help() {
  local os_name="unknown"

  if command -v uname >/dev/null 2>&1; then
    os_name="$(uname -s)"
  fi

  printf 'Error: tmux is required but was not found in PATH.\n' >&2

  case "$os_name" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        printf 'Install it with: brew install tmux\n' >&2
      else
        printf 'Install Homebrew from https://brew.sh/ and then run: brew install tmux\n' >&2
      fi
      ;;
    Linux)
      printf 'Install it with one of:\n' >&2

      if command -v apt-get >/dev/null 2>&1; then
        printf '  sudo apt-get update && sudo apt-get install -y tmux\n' >&2
      fi

      if command -v dnf >/dev/null 2>&1; then
        printf '  sudo dnf install -y tmux\n' >&2
      fi

      if command -v yum >/dev/null 2>&1; then
        printf '  sudo yum install -y tmux\n' >&2
      fi

      if command -v pacman >/dev/null 2>&1; then
        printf '  sudo pacman -S tmux\n' >&2
      fi

      if command -v zypper >/dev/null 2>&1; then
        printf '  sudo zypper install tmux\n' >&2
      fi

      if command -v apk >/dev/null 2>&1; then
        printf '  sudo apk add tmux\n' >&2
      fi

      printf 'Or install tmux using your preferred package manager.\n' >&2
      ;;
    *)
      printf 'Please install tmux using your system package manager.\n' >&2
      ;;
  esac
}

resolve_command() {
  local candidate="$1"
  local resolved=""

  if [[ "$candidate" == */* ]]; then
    if [[ ! -x "$candidate" ]]; then
      printf 'Error: command is not executable: %s\n' "$candidate" >&2
      exit 1
    fi

    printf '%s' "$candidate"
    return 0
  fi

  resolved="$(command -v -- "$candidate" || true)"

  if [[ -z "$resolved" ]]; then
    printf 'Error: command not found: %s\n' "$candidate" >&2
    exit 1
  fi

  printf '%s' "$resolved"
}

make_auto_session_name() {
  local command_name="$1"
  local timestamp

  timestamp="$(date +%Y%m%d-%H%M%S)"

  printf '%s' "${command_name:-session}-${timestamp}-$$"
}

ensure_unique_session_name() {
  local base_name="$1"
  local candidate="$base_name"
  local suffix=2

  while tmux has-session -t "$candidate" 2>/dev/null; do
    candidate="${base_name}-${suffix}"
    suffix=$((suffix + 1))
  done

  printf '%s' "$candidate"
}

session_name=""
working_dir="$PWD"
attach=0

while getopts ":s:c:ah" opt; do
  case "$opt" in
    s) session_name="$OPTARG" ;;
    c) working_dir="$OPTARG" ;;
    a) attach=1 ;;
    h)
      usage
      exit 0
      ;;
    :)
      printf 'Error: -%s requires a value.\n\n' "$OPTARG" >&2
      usage >&2
      exit 1
      ;;
    \?)
      printf 'Error: unknown option -%s.\n\n' "$OPTARG" >&2
      usage >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

if [[ "${1:-}" == "--" ]]; then
  shift
fi

if [[ $# -eq 0 ]]; then
  printf 'Error: no command provided.\n\n' >&2
  usage >&2
  exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
  print_tmux_install_help
  exit 1
fi

if [[ ! -d "$working_dir" ]]; then
  printf 'Error: directory does not exist: %s\n' "$working_dir" >&2
  exit 1
fi

resolved_command="$(resolve_command "$1")"
shift

if [[ -z "$session_name" ]]; then
  base_name="$(sanitize_session_name "$(basename "$resolved_command")")"
  session_name="$(ensure_unique_session_name "$(make_auto_session_name "${base_name:-session}")")"
elif tmux has-session -t "$session_name" 2>/dev/null; then
  printf 'Error: tmux session already exists: %s\n' "$session_name" >&2
  exit 1
fi

display_command="$(join_command "$resolved_command" "$@")"

tmux new-session -d -s "$session_name" -c "$working_dir" "$resolved_command" "$@"

printf 'Started tmux session: %s\n' "$session_name"
printf 'Command: %s\n' "$display_command"
printf 'Attach with: tmux attach -t %q\n' "$session_name"

if [[ $attach -eq 1 ]]; then
  exec tmux attach -t "$session_name"
fi
