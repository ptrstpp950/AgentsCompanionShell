#!/usr/bin/env bash

set -euo pipefail

if ! command -v zsh >/dev/null 2>&1; then
  printf 'Skipping installed zsh smoke test: zsh not installed.\n'
  exit 0
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_home="$(mktemp -d)"
rc_file="$tmp_home/.zshrc"
install_dir="$tmp_home/.agentscompanion"

cleanup() {
  rm -rf "$tmp_home"
}

trap cleanup EXIT

touch "$rc_file"

env -i HOME="$tmp_home" PATH="$PATH" bash "$repo_dir/install.sh" --rc-file "$rc_file" >/tmp/agentscompanion-install-zsh.out
install_dir_real="$(cd "$install_dir" && pwd -P)"

zsh_output="$(
  env -i \
    HOME="$tmp_home" \
    PATH="$PATH" \
    zsh -fc '
      source "$HOME/.zshrc"
      print -- "$(_agentscompanion_home)"
      print -- "$(_agentscompanion_tmux_launcher)"
      agentscompanion --version
    '
)"

expected_output="$install_dir_real
$install_dir_real/lib/tmux-launch.sh
$(cat "$repo_dir/VERSION")"

if [ "$zsh_output" != "$expected_output" ]; then
  printf 'Unexpected installed zsh output:\n%s\n' "$zsh_output" >&2
  exit 1
fi
