#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_home="$(mktemp -d)"
rc_file="$tmp_home/.bashrc"
install_dir="$tmp_home/.agentscompanion"

cleanup() {
  rm -rf "$tmp_home"
}

trap cleanup EXIT

touch "$rc_file"

HOME="$tmp_home" AGENTSCOMPANION_INSTALL_DIR="$install_dir" bash "$repo_dir/install.sh" --rc-file "$rc_file" >/tmp/agentscompanion-install.out
HOME="$tmp_home" AGENTSCOMPANION_INSTALL_DIR="$install_dir" bash "$repo_dir/install.sh" --rc-file "$rc_file" >/tmp/agentscompanion-install.out

for path in "$install_dir/agentscompanion.sh" "$install_dir/lib/tmux-launch.sh" "$install_dir/VERSION"; do
  if [ ! -f "$path" ]; then
    printf 'Expected installed file missing: %s\n' "$path" >&2
    exit 1
  fi
done

marker_count="$(grep -c '^# >>> agentscompanion >>>$' "$rc_file")"

if [ "$marker_count" -ne 1 ]; then
  printf 'Expected a single agentscompanion block in %s, got %s\n' "$rc_file" "$marker_count" >&2
  exit 1
fi

if ! grep -Fq '. "$HOME/.agentscompanion/agentscompanion.sh"' "$rc_file"; then
  printf 'Expected rc file to source agentscompanion.sh\n' >&2
  exit 1
fi
