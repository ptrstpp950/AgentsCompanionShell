#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
output_file="$(mktemp)"

cleanup() {
  rm -f "$output_file"
}

trap cleanup EXIT

bash "$repo_dir/tests/prepare_install_sandbox.sh" >"$output_file"

eval "$(
  grep -E '^(SANDBOX_ROOT|SANDBOX_HOME|STAGED_RELEASE|BOOTSTRAP_SCRIPT|PASTE_ONE_LINER|PASTE_ONE_LINER_YES|INSTALL_ONE_LINER|INSTALL_ONE_LINER_YES|VERIFY_ONE_LINER|CLEANUP_ONE_LINER)=' "$output_file"
)"

for path in \
  "$STAGED_RELEASE/install.sh" \
  "$BOOTSTRAP_SCRIPT" \
  "$STAGED_RELEASE/agentscompanion.sh" \
  "$STAGED_RELEASE/VERSION" \
  "$STAGED_RELEASE/lib/tmux-launch.sh"
do
  if [ ! -f "$path" ]; then
    printf 'Expected staged file missing: %s\n' "$path" >&2
    exit 1
  fi
done

if [[ "$INSTALL_ONE_LINER" != *"bash <("* ]]; then
  printf 'Expected install one-liner to use bash <(...), got:\n%s\n' "$INSTALL_ONE_LINER" >&2
  exit 1
fi

if [ "$PASTE_ONE_LINER" != 'bash <(cat "$AGENTSCOMPANION_BOOTSTRAP_SCRIPT")' ]; then
  printf 'Unexpected in-shell one-liner: %s\n' "$PASTE_ONE_LINER" >&2
  exit 1
fi

if [ "$PASTE_ONE_LINER_YES" != 'bash <(cat "$AGENTSCOMPANION_BOOTSTRAP_SCRIPT") --yes' ]; then
  printf 'Unexpected in-shell no-prompt one-liner: %s\n' "$PASTE_ONE_LINER_YES" >&2
  exit 1
fi

if [[ "$INSTALL_ONE_LINER_YES" != *"--yes" ]]; then
  printf 'Expected standalone no-prompt one-liner to include --yes, got:\n%s\n' "$INSTALL_ONE_LINER_YES" >&2
  exit 1
fi

install_output="$(printf 'y\n' | eval "$INSTALL_ONE_LINER")"

if [[ "$install_output" != *"This will:"* ]] || [[ "$install_output" != *"Continue? [y/N]"* ]]; then
  printf 'Expected install output to explain changes and ask for confirmation, got:\n%s\n' "$install_output" >&2
  exit 1
fi

for path in \
  "$SANDBOX_HOME/.agentscompanion/agentscompanion.sh" \
  "$SANDBOX_HOME/.agentscompanion/lib/tmux-launch.sh" \
  "$SANDBOX_HOME/.agentscompanion/VERSION"
do
  if [ ! -f "$path" ]; then
    printf 'Expected installed file missing: %s\n' "$path" >&2
    exit 1
  fi
done

if ! grep -Fq '. "$HOME/.agentscompanion/agentscompanion.sh"' "$SANDBOX_HOME/.bashrc"; then
  printf 'Expected sandbox rc file to source agentscompanion.sh\n' >&2
  exit 1
fi

verify_output="$(eval "$VERIFY_ONE_LINER")"

if [[ "$verify_output" != *"copilot is a function"* ]]; then
  printf 'Expected verify command to show copilot wrapper, got:\n%s\n' "$verify_output" >&2
  exit 1
fi

rm -rf "$SANDBOX_HOME/.agentscompanion" "$SANDBOX_HOME/.bashrc" "$SANDBOX_HOME/.bashrc.agentscompanion.bak"

paste_output="$(
  HOME="$SANDBOX_HOME" \
  AGENTSCOMPANION_LOCAL_SOURCE_DIR="$STAGED_RELEASE" \
  AGENTSCOMPANION_INSTALL_DIR="$SANDBOX_HOME/.agentscompanion" \
  AGENTSCOMPANION_RC_FILE="$SANDBOX_HOME/.bashrc" \
  AGENTSCOMPANION_BOOTSTRAP_SCRIPT="$BOOTSTRAP_SCRIPT" \
  bash -lc "$PASTE_ONE_LINER_YES"
)"

if [[ "$paste_output" != *"Installed agentscompanion into"* ]]; then
  printf 'Expected in-shell one-liner to install successfully, got:\n%s\n' "$paste_output" >&2
  exit 1
fi

eval "$CLEANUP_ONE_LINER"

if [ -e "$SANDBOX_ROOT" ]; then
  printf 'Expected sandbox cleanup to remove %s\n' "$SANDBOX_ROOT" >&2
  exit 1
fi
