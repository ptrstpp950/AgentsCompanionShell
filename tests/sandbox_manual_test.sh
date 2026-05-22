#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
sandbox_home="$(mktemp -d "${TMPDIR:-/tmp}/agentscompanion-sandbox.XXXXXX")"
shell_name="bash"
open_shell=0

usage() {
  cat <<'EOF'
Usage:
  sandbox_manual_test.sh [--open-shell] [--shell bash|zsh]

Create an isolated fake HOME, install agentscompanion into it, and print the
exact commands to manually verify the install without touching your real shell
configuration.

Options:
  --open-shell        Open an interactive shell in the sandbox after setup
  --shell SHELL       Choose the shell to target (bash or zsh, default: bash)
  -h, --help          Show this help message
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --open-shell)
      open_shell=1
      shift
      ;;
    --shell)
      shell_name="$2"
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

case "$shell_name" in
  bash)
    rc_file="$sandbox_home/.bashrc"
    launch_shell_cmd=(bash --rcfile "$rc_file" -i)
    ;;
  zsh)
    rc_file="$sandbox_home/.zshrc"
    launch_shell_cmd=(zsh -i)
    ;;
  *)
    printf 'Error: unsupported shell: %s\n' "$shell_name" >&2
    exit 1
    ;;
esac

touch "$rc_file"

HOME="$sandbox_home" \
AGENTSCOMPANION_INSTALL_DIR="$sandbox_home/.agentscompanion" \
bash "$repo_dir/install.sh" --rc-file "$rc_file"

cat <<EOF
Sandbox ready.

Home:
  $sandbox_home

RC file:
  $rc_file

Installed files:
  $sandbox_home/.agentscompanion

Try these commands in the sandbox shell:
  source "$rc_file"
  agentscompanion --version
  type copilot
  cd "$repo_dir"
  copilot --help
  agentscompanion launch-set copilot codex claude
  tmux ls

Cleanup when done:
  rm -rf "$sandbox_home"
EOF

if [ "$open_shell" -eq 1 ]; then
  if ! command -v "$shell_name" >/dev/null 2>&1; then
    printf 'Error: %s is not installed.\n' "$shell_name" >&2
    exit 1
  fi

  printf '\nOpening sandbox shell...\n'
  printf 'Run `source %q` first if the shell does not load the rc file automatically.\n\n' "$rc_file"

  if [ "$shell_name" = "bash" ]; then
    HOME="$sandbox_home" "${launch_shell_cmd[@]}"
  else
    HOME="$sandbox_home" ZDOTDIR="$sandbox_home" "${launch_shell_cmd[@]}"
  fi
fi
