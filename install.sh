#!/usr/bin/env bash
# agentscompanion install version: 0.1.4

set -euo pipefail

install_dir="${AGENTSCOMPANION_INSTALL_DIR:-$HOME/.agentscompanion}"
base_url="${AGENTSCOMPANION_BASE_URL:-}"
rc_file=""
color_success=""
color_heading=""
color_reset=""

usage() {
  cat <<'EOF'
Usage:
  install.sh [--rc-file PATH] [--base-url URL]

Install agentscompanion into ~/.agentscompanion by default and wire it into a shell rc file.

Options:
  --rc-file PATH   Update this rc file instead of prompting
  --base-url URL   Download files from this base URL instead of the local checkout
  -h, --help       Show this help message
EOF
}

setup_colors() {
  if [ -t 1 ]; then
    color_success=$'\033[1;32m'
    color_heading=$'\033[1;36m'
    color_reset=$'\033[0m'
  fi
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
setup_colors

print_tmux_note() {
  if command -v tmux >/dev/null 2>&1; then
    return 0
  fi

  printf 'Note: tmux is not installed yet. agentscompanion needs tmux to launch sessions.\n'

  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        printf 'Install it with: brew install tmux\n'
      else
        printf 'Install Homebrew from https://brew.sh/ and then run: brew install tmux\n'
      fi
      ;;
    Linux)
      printf 'Install tmux with your package manager, for example:\n'
      printf '  sudo apt-get install -y tmux\n'
      printf '  sudo dnf install -y tmux\n'
      printf '  sudo pacman -S tmux\n'
      ;;
    *)
      printf 'Install tmux using your system package manager.\n'
      ;;
  esac
}

copy_local_file() {
  local source_path="$1"
  local destination_path="$2"

  mkdir -p "$(dirname "$destination_path")"
  cp "$source_path" "$destination_path"
}

download_file() {
  local relative_path="$1"
  local destination_path="$2"
  local url

  mkdir -p "$(dirname "$destination_path")"
  url="${base_url%/}/$relative_path"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$destination_path"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$destination_path" "$url"
    return 0
  fi

  printf 'Error: curl or wget is required to download %s\n' "$url" >&2
  exit 1
}

install_file() {
  local relative_path="$1"
  local destination_path="$install_dir/$relative_path"

  if [ -n "$base_url" ]; then
    download_file "$relative_path" "$destination_path"
  else
    copy_local_file "$script_dir/$relative_path" "$destination_path"
  fi
}

choose_rc_file() {
  local default_shell="${SHELL:-}"
  local choice
  local options=()

  if [ -f "$HOME/.zshrc" ] || [ "${default_shell##*/}" = "zsh" ]; then
    options+=("$HOME/.zshrc")
  fi

  if [ -f "$HOME/.bashrc" ] || [ "${default_shell##*/}" = "bash" ]; then
    options+=("$HOME/.bashrc")
  fi

  if [ "$(uname -s)" = "Darwin" ]; then
    options+=("$HOME/.bash_profile")
  fi

  if [ "${#options[@]}" -eq 0 ]; then
    rc_file="$HOME/.bashrc"
    return 0
  fi

  printf 'Choose the rc file to update:\n'
  for i in "${!options[@]}"; do
    printf '  %s) %s\n' "$((i + 1))" "${options[$i]}"
  done

  printf 'Enter a number [1-%s]: ' "${#options[@]}"
  read -r choice

  case "$choice" in
    ''|*[!0-9]*)
      printf 'Error: please enter a valid number.\n' >&2
      exit 1
      ;;
  esac

  if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#options[@]}" ]; then
    printf 'Error: choice out of range.\n' >&2
    exit 1
  fi

  rc_file="${options[$((choice - 1))]}"
}

ensure_rc_file() {
  if [ -z "$rc_file" ]; then
    choose_rc_file
  fi

  mkdir -p "$(dirname "$rc_file")"
  touch "$rc_file"
}

update_rc_file() {
  local tmp_file
  local backup_file

  tmp_file="$(mktemp)"
  backup_file="${rc_file}.agentscompanion.bak"

  cp "$rc_file" "$backup_file"

  awk '
    BEGIN { skip = 0 }
    /^# >>> agentscompanion >>>$/ { skip = 1; next }
    /^# <<< agentscompanion <<<$/{ skip = 0; next }
    skip == 0 { print }
  ' "$rc_file" >"$tmp_file"

  cat >>"$tmp_file" <<EOF
# >>> agentscompanion >>>
if [ -f "\$HOME/.agentscompanion/agentscompanion.sh" ]; then
  . "\$HOME/.agentscompanion/agentscompanion.sh"
fi
# <<< agentscompanion <<<
EOF

  mv "$tmp_file" "$rc_file"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --rc-file)
      rc_file="$2"
      shift 2
      ;;
    --base-url)
      base_url="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

mkdir -p "$install_dir/lib"

install_file VERSION
install_file agentscompanion.sh
install_file lib/tmux-launch.sh

chmod +x "$install_dir/agentscompanion.sh" "$install_dir/lib/tmux-launch.sh"

ensure_rc_file
update_rc_file
print_tmux_note

printf '\n%bInstallation complete.%b New terminals will load agentscompanion automatically.\n' "$color_success" "$color_reset"
printf '%bUse agentscompanion in this terminal:%b\n  source %q\n' "$color_heading" "$color_reset" "$rc_file"
