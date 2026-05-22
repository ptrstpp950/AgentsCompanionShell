#!/usr/bin/env bash

set -euo pipefail

if ! command -v zsh >/dev/null 2>&1; then
  printf 'Skipping zsh smoke test: zsh not installed.\n'
  exit 0
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d)"
fake_launcher="$tmp_dir/fake-launcher.sh"
fake_bin_dir="$tmp_dir/bin"
log_file="$tmp_dir/zsh-launcher.log"

cleanup() {
  rm -rf "$tmp_dir"
}

trap cleanup EXIT

mkdir -p "$fake_bin_dir"

cat >"$fake_launcher" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$AGENTSCOMPANION_TEST_LOG"
EOF

chmod +x "$fake_launcher"

cat >"$fake_bin_dir/copilot" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x "$fake_bin_dir/copilot"

zsh_output="$(
  env \
    PATH="$fake_bin_dir:$PATH" \
    AGENTSCOMPANION_HOME="$repo_dir" \
    AGENTSCOMPANION_TMUX_LAUNCHER="$fake_launcher" \
    AGENTSCOMPANION_TEST_LOG="$log_file" \
    zsh <<'EOF'
setopt no_nomatch
source "$AGENTSCOMPANION_HOME/agentscompanion.sh"
copilot chat
agentscompanion --version
EOF
)"

if [ "$zsh_output" != "$(cat "$repo_dir/VERSION")" ]; then
  printf 'Unexpected zsh version output: %s\n' "$zsh_output" >&2
  exit 1
fi

if ! grep -Fq "$fake_bin_dir/copilot" "$log_file"; then
  printf 'Expected zsh wrapper to resolve the real copilot binary.\n' >&2
  exit 1
fi
