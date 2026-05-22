#!/usr/bin/env bash
# agentscompanion bootstrap version: 0.1.2

set -euo pipefail

source_dir="${AGENTSCOMPANION_LOCAL_SOURCE_DIR:-}"
base_url="${AGENTSCOMPANION_BASE_URL:-}"
github_repository="${AGENTSCOMPANION_GITHUB_REPOSITORY:-}"
github_ref="${AGENTSCOMPANION_GITHUB_REF:-main}"
install_dir="${AGENTSCOMPANION_INSTALL_DIR:-$HOME/.agentscompanion}"
rc_file="${AGENTSCOMPANION_RC_FILE:-}"
bootstrap_dir="$(mktemp -d "${TMPDIR:-/tmp}/agentscompanion-bootstrap.XXXXXX")"
assume_yes="${AGENTSCOMPANION_ASSUME_YES:-0}"
default_base_url="https://raw.githubusercontent.com/ptrstpp950/AgentsCompanionShell/master"
color_title=""
color_heading=""
color_note=""
color_reset=""

usage() {
  cat <<'EOF'
Usage:
  bootstrap.sh [--yes]

Bootstrap a local agentscompanion release into ~/.agentscompanion and update a
shell rc file through install.sh. The bootstrap script can fetch installer files
from a base URL, such as GitHub raw content.

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

resolve_base_url() {
  if [ -n "$base_url" ]; then
    printf '%s\n' "$base_url"
    return 0
  fi

  if [ -n "$github_repository" ]; then
    printf 'https://raw.githubusercontent.com/%s/%s\n' "$github_repository" "$github_ref"
    return 0
  fi

  printf '%s\n' "$default_base_url"
}

describe_source() {
  if [ -n "$source_dir" ]; then
    printf 'the staged local release\n'
    return 0
  fi

  resolved_base_url="$(resolve_base_url)" || {
    printf 'the configured release source\n'
    return 0
  }

  case "$resolved_base_url" in
    file://*)
      printf 'the staged sandbox bundle\n'
      ;;
    https://raw.githubusercontent.com/*)
      printf 'GitHub\n'
      ;;
    *)
      printf '%s\n' "$resolved_base_url"
      ;;
  esac
}

print_plan() {
  printf '%bagentscompanion bootstrap%b\n\n' "$color_title" "$color_reset"
  printf '%bThis will:%b\n' "$color_heading" "$color_reset"
  printf '  - download installer files from %s\n' "$(describe_source)"
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

download_file() {
  local url="$1"
  local destination_path="$2"

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
  if ! resolved_base_url="$(resolve_base_url)"; then
    printf 'Error: set AGENTSCOMPANION_BASE_URL, AGENTSCOMPANION_GITHUB_REPOSITORY, or AGENTSCOMPANION_LOCAL_SOURCE_DIR.\n' >&2
    exit 1
  fi
else
  if [ ! -d "$source_dir" ]; then
    printf 'Error: staged release directory does not exist: %s\n' "$source_dir" >&2
    exit 1
  fi
fi

print_plan
confirm

if [ -n "$source_dir" ]; then
  cp -R "$source_dir"/. "$bootstrap_dir"
  if [ -n "$rc_file" ]; then
    AGENTSCOMPANION_INSTALL_DIR="$install_dir" bash "$bootstrap_dir/install.sh" --rc-file "$rc_file"
  else
    AGENTSCOMPANION_INSTALL_DIR="$install_dir" bash "$bootstrap_dir/install.sh"
  fi
else
  download_file "${resolved_base_url%/}/install.sh" "$bootstrap_dir/install.sh"
  chmod +x "$bootstrap_dir/install.sh"
  if [ -n "$rc_file" ]; then
    AGENTSCOMPANION_INSTALL_DIR="$install_dir" bash "$bootstrap_dir/install.sh" --base-url "$resolved_base_url" --rc-file "$rc_file"
  else
    AGENTSCOMPANION_INSTALL_DIR="$install_dir" bash "$bootstrap_dir/install.sh" --base-url "$resolved_base_url"
  fi
fi
