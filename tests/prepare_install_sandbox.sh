#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
sandbox_root="$(mktemp -d "${TMPDIR:-/tmp}/agentscompanion-install-sandbox.XXXXXX")"
shell_name="bash"

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
  prepare_install_sandbox.sh [--shell bash|zsh]

Create an isolated install sandbox that stages a fake HOME and a local release
bundle. The script prints a copy-based one-liner you can paste to simulate the
future install flow without using curl or wget.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
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
    ;;
  zsh)
    rc_file="$sandbox_root/home/.zshrc"
    verify_command=(zsh -f -ic "source \"$rc_file\" && agentscompanion --version && type copilot")
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

mkdir -p "$sandbox_home" "$release_dir/lib"
touch "$rc_file"

cp "$repo_dir/bootstrap.sh" "$release_dir/bootstrap.sh"
cp "$repo_dir/install.sh" "$release_dir/install.sh"
cp "$repo_dir/agentscompanion.sh" "$release_dir/agentscompanion.sh"
cp "$repo_dir/VERSION" "$release_dir/VERSION"
cp "$repo_dir/lib/tmux-launch.sh" "$release_dir/lib/tmux-launch.sh"

chmod +x "$release_dir/bootstrap.sh" "$release_dir/install.sh" "$release_dir/agentscompanion.sh" "$release_dir/lib/tmux-launch.sh"

printf -v install_one_liner 'HOME=%q AGENTSCOMPANION_LOCAL_SOURCE_DIR=%q AGENTSCOMPANION_INSTALL_DIR=%q AGENTSCOMPANION_RC_FILE=%q bash <(cat %q)' \
  "$sandbox_home" "$release_dir" "$install_dir" "$rc_file" "$bootstrap_script"

verify_script="$(join_command "${verify_command[@]}")"
printf -v verify_one_liner 'HOME=%q %s' "$sandbox_home" "$verify_script"
printf -v cleanup_one_liner 'rm -rf %q' "$sandbox_root"

cat <<EOF
Install sandbox ready.

Home:
  $sandbox_home

Staged release:
  $release_dir

Bootstrap script:
  $bootstrap_script

Install one-liner:
  $install_one_liner

Verify after install:
  $verify_one_liner

Cleanup:
  $cleanup_one_liner

Machine-readable values:
SANDBOX_ROOT=$(printf '%q' "$sandbox_root")
SANDBOX_HOME=$(printf '%q' "$sandbox_home")
STAGED_RELEASE=$(printf '%q' "$release_dir")
BOOTSTRAP_SCRIPT=$(printf '%q' "$bootstrap_script")
INSTALL_ONE_LINER=$(printf '%q' "$install_one_liner")
VERIFY_ONE_LINER=$(printf '%q' "$verify_one_liner")
CLEANUP_ONE_LINER=$(printf '%q' "$cleanup_one_liner")
EOF
