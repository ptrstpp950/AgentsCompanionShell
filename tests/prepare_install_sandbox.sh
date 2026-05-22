#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/agentscompanion-install-sandbox.XXXXXX")"
shell_name="bash"
open_shell=0

join_command() {
  local quoted parts=()

  for arg in "$@"; do
    printf -v quoted '%q' "$arg"
    parts+=("$quoted")
  done

  printf '%s' "${parts[*]}"
}

usage() {
  cat <<'EOF'
Usage:
  prepare_install_sandbox.sh [--open-shell] [--shell bash|zsh]

Create an isolated install sandbox that stages a fake HOME and a local release
bundle. It can open a clean shell and print a short bootstrap-style one-liner
you can paste to simulate the future install flow without using curl or wget.
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
    rc_file="$sandbox_root/home/.bashrc"
    verify_command=(bash --noprofile --norc -ic "source \"$rc_file\" && agentscompanion --version && type copilot")
    session_rc="$sandbox_root/bash.sessionrc"
    launch_shell_cmd=(bash --noprofile --rcfile "$session_rc" -i)
    ;;
  zsh)
    rc_file="$sandbox_root/home/.zshrc"
    verify_command=(zsh -f -ic "source \"$rc_file\" && agentscompanion --version && type copilot")
    session_rc="$sandbox_root/zsh-session/.zshrc"
    launch_shell_cmd=(zsh -i)
    ;;
  *)
    printf 'Error: unsupported shell: %s\n' "$shell_name" >&2
    exit 1
    ;;
esac

sandbox_home="$sandbox_root/home"
release_dir="$sandbox_root/release"
install_dir="$sandbox_home/.agentscompanion"
bootstrap_script="$release_dir/bootstrap.sh"
paste_one_liner='bash <(cat "$AGENTSCOMPANION_BOOTSTRAP_SCRIPT")'
paste_one_liner_yes='bash <(cat "$AGENTSCOMPANION_BOOTSTRAP_SCRIPT") --yes'

mkdir -p "$sandbox_home" "$release_dir/lib" "$(dirname "$session_rc")"
touch "$rc_file"

cp "$repo_dir/bootstrap.sh" "$release_dir/bootstrap.sh"
cp "$repo_dir/install.sh" "$release_dir/install.sh"
cp "$repo_dir/agentscompanion.sh" "$release_dir/agentscompanion.sh"
cp "$repo_dir/VERSION" "$release_dir/VERSION"
cp "$repo_dir/lib/tmux-launch.sh" "$release_dir/lib/tmux-launch.sh"

chmod +x "$release_dir/bootstrap.sh" "$release_dir/install.sh" "$release_dir/agentscompanion.sh" "$release_dir/lib/tmux-launch.sh"

printf -v install_one_liner 'HOME=%q AGENTSCOMPANION_LOCAL_SOURCE_DIR=%q AGENTSCOMPANION_INSTALL_DIR=%q AGENTSCOMPANION_RC_FILE=%q bash <(cat %q)' \
  "$sandbox_home" "$release_dir" "$install_dir" "$rc_file" "$bootstrap_script"
printf -v install_one_liner_yes 'HOME=%q AGENTSCOMPANION_LOCAL_SOURCE_DIR=%q AGENTSCOMPANION_INSTALL_DIR=%q AGENTSCOMPANION_RC_FILE=%q bash <(cat %q) --yes' \
  "$sandbox_home" "$release_dir" "$install_dir" "$rc_file" "$bootstrap_script"

verify_script="$(join_command "${verify_command[@]}")"
printf -v verify_one_liner 'HOME=%q %s' "$sandbox_home" "$verify_script"
printf -v cleanup_one_liner 'rm -rf %q' "$sandbox_root"

cat >"$session_rc" <<EOF
export AGENTSCOMPANION_LOCAL_SOURCE_DIR=$(printf '%q' "$release_dir")
export AGENTSCOMPANION_INSTALL_DIR=$(printf '%q' "$install_dir")
export AGENTSCOMPANION_RC_FILE=$(printf '%q' "$rc_file")
export AGENTSCOMPANION_BOOTSTRAP_SCRIPT=$(printf '%q' "$bootstrap_script")

printf 'Install sandbox shell ready. Paste this one-liner to review and confirm changes:\\n  %s\\n\\n' '$(printf '%s' "$paste_one_liner")'
printf 'Skip confirmation with:\\n  %s\\n\\n' '$(printf '%s' "$paste_one_liner_yes")'
printf 'Then verify with:\\n  source %q\\n  agentscompanion --version\\n  type copilot\\n\\n' $(printf '%q' "$rc_file")
printf 'Cleanup later with:\\n  %s\\n\\n' '$(printf '%s' "$cleanup_one_liner")'
EOF

cat <<EOF
Install sandbox ready.

Home:
  $sandbox_home

Staged release:
  $release_dir

Bootstrap script:
  $bootstrap_script

Open sandbox shell:
  bash tests/prepare_install_sandbox.sh --open-shell$( [ "$shell_name" = "zsh" ] && printf ' --shell zsh' )

Paste inside the sandbox shell:
  $paste_one_liner

Skip confirmation inside the sandbox shell:
  $paste_one_liner_yes

Standalone install one-liner:
  $install_one_liner

Standalone install one-liner without confirmation:
  $install_one_liner_yes

Verify after install:
  $verify_one_liner

Cleanup:
  $cleanup_one_liner

Machine-readable values:
SANDBOX_ROOT=$(printf '%q' "$sandbox_root")
SANDBOX_HOME=$(printf '%q' "$sandbox_home")
STAGED_RELEASE=$(printf '%q' "$release_dir")
BOOTSTRAP_SCRIPT=$(printf '%q' "$bootstrap_script")
PASTE_ONE_LINER=$(printf '%q' "$paste_one_liner")
PASTE_ONE_LINER_YES=$(printf '%q' "$paste_one_liner_yes")
INSTALL_ONE_LINER=$(printf '%q' "$install_one_liner")
INSTALL_ONE_LINER_YES=$(printf '%q' "$install_one_liner_yes")
VERIFY_ONE_LINER=$(printf '%q' "$verify_one_liner")
CLEANUP_ONE_LINER=$(printf '%q' "$cleanup_one_liner")
EOF

if [ "$open_shell" -eq 1 ]; then
  if ! command -v "$shell_name" >/dev/null 2>&1; then
    printf 'Error: %s is not installed.\n' "$shell_name" >&2
    exit 1
  fi

  printf '\nOpening sandbox shell...\n\n'

  if [ "$shell_name" = "bash" ]; then
    HOME="$sandbox_home" "${launch_shell_cmd[@]}"
  else
    HOME="$sandbox_home" ZDOTDIR="$(dirname "$session_rc")" "${launch_shell_cmd[@]}"
  fi
fi
