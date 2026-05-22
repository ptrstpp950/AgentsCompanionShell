#!/usr/bin/env bash

set -euo pipefail

source_dir="${AGENTSCOMPANION_LOCAL_SOURCE_DIR:-}"
install_dir="${AGENTSCOMPANION_INSTALL_DIR:-$HOME/.agentscompanion}"
rc_file="${AGENTSCOMPANION_RC_FILE:-}"
bootstrap_dir="$(mktemp -d "${TMPDIR:-/tmp}/agentscompanion-bootstrap.XXXXXX")"
assume_yes="${AGENTSCOMPANION_ASSUME_YES:-0}"
color_title=""
color_heading=""
color_note=""
color_reset=""

usage() {
  cat <<'EOF'
Usage:
  bootstrap.sh [--yes]

Bootstrap a local agentscompanion release into ~/.agentscompanion and update a
shell rc file through install.sh.

Options:
  --yes    Skip the confirmation prompt
  -h       Show this help message
EOF
}

setup_colors() {
  if [ -t 1 ]; then
    color_title=$'\033[1;36m'
    color_heading=$'\033[1;32m'
    color_note=$'\033[1;33m'
    color_reset=$'\033[0m'
  fi
}

print_plan() {
  printf '%bagentscompanion bootstrap%b\n\n' "$color_title" "$color_reset"
  printf '%bThis will:%b\n' "$color_heading" "$color_reset"
  printf '  - install agentscompanion into %s\n' "$install_dir"

  if [ -n "$rc_file" ]; then
    printf '  - update the shell rc file %s\n' "$rc_file"
    printf '  - keep a backup at %s\n' "${rc_file}.agentscompanion.bak"
  else
    printf '  - ask you which shell rc file should be updated\n'
  fi

  printf '\n'
}

confirm() {
  local answer

  if [ "$assume_yes" = "1" ]; then
    return 0
  fi

  printf '%bContinue? [y/N]%b ' "$color_note" "$color_reset"
  read -r answer

  case "$answer" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      printf 'Cancelled.\n'
      exit 1
      ;;
  esac
}

cleanup() {
  rm -rf "$bootstrap_dir"
}

trap cleanup EXIT
setup_colors

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes)
      assume_yes=1
      shift
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

if [ -z "$source_dir" ]; then
  printf 'Error: AGENTSCOMPANION_LOCAL_SOURCE_DIR must point to a staged release directory.\n' >&2
  exit 1
fi

if [ ! -d "$source_dir" ]; then
  printf 'Error: staged release directory does not exist: %s\n' "$source_dir" >&2
  exit 1
fi

print_plan
confirm

cp -R "$source_dir"/. "$bootstrap_dir"

install_args=()

if [ -n "$rc_file" ]; then
  install_args+=(--rc-file "$rc_file")
fi

AGENTSCOMPANION_INSTALL_DIR="$install_dir" bash "$bootstrap_dir/install.sh" "${install_args[@]}"
