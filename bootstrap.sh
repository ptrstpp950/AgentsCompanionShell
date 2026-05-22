#!/usr/bin/env bash

set -euo pipefail

source_dir="${AGENTSCOMPANION_LOCAL_SOURCE_DIR:-}"
install_dir="${AGENTSCOMPANION_INSTALL_DIR:-$HOME/.agentscompanion}"
rc_file="${AGENTSCOMPANION_RC_FILE:-}"
bootstrap_dir="$(mktemp -d "${TMPDIR:-/tmp}/agentscompanion-bootstrap.XXXXXX")"

cleanup() {
  rm -rf "$bootstrap_dir"
}

trap cleanup EXIT

if [ -z "$source_dir" ]; then
  printf 'Error: AGENTSCOMPANION_LOCAL_SOURCE_DIR must point to a staged release directory.\n' >&2
  exit 1
fi

if [ ! -d "$source_dir" ]; then
  printf 'Error: staged release directory does not exist: %s\n' "$source_dir" >&2
  exit 1
fi

cp -R "$source_dir"/. "$bootstrap_dir"

install_args=()

if [ -n "$rc_file" ]; then
  install_args+=(--rc-file "$rc_file")
fi

AGENTSCOMPANION_INSTALL_DIR="$install_dir" bash "$bootstrap_dir/install.sh" "${install_args[@]}"
