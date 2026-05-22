#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d)"
log_file="$tmp_dir/launcher.log"
fake_launcher="$tmp_dir/fake-launcher.sh"
fake_bin_dir="$tmp_dir/bin"

cleanup() {
  rm -rf "$tmp_dir"
}

sanitize_name() {
  local value="${1:-}"

  value="${value//[^[:alnum:]_-]/-}"

  while [[ -n "$value" && ( "${value#-}" != "$value" || "${value#_}" != "$value" ) ]]; do
    value="${value#-}"
    value="${value#_}"
  done

  while [[ -n "$value" && ( "${value%-}" != "$value" || "${value%_}" != "$value" ) ]]; do
    value="${value%-}"
    value="${value%_}"
  done

  printf '%s\n' "$value"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'Expected to find %q in:\n%s\n' "$needle" "$haystack" >&2
    exit 1
  fi
}

trap cleanup EXIT

mkdir -p "$fake_bin_dir"

project_name="$(sanitize_name "$(basename "$tmp_dir")")"
base_session_name="copilot-$project_name"

cat >"$fake_launcher" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf '__CALL__\n'
  for arg in "$@"; do
    printf '%s\n' "$arg"
  done
} >>"$AGENTSCOMPANION_TEST_LOG"
EOF

chmod +x "$fake_launcher"

for tool_name in copilot codex claude; do
  cat >"$fake_bin_dir/$tool_name" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$fake_bin_dir/$tool_name"
done

before_shell_flags="$(set -o | awk '$1 == "errexit" || $1 == "nounset" || $1 == "pipefail" { print $1 "=" $2 }')"

export PATH="$fake_bin_dir:$PATH"
export AGENTSCOMPANION_HOME="$repo_dir"
export AGENTSCOMPANION_TMUX_LAUNCHER="$fake_launcher"
export AGENTSCOMPANION_TEST_LOG="$log_file"

cd "$tmp_dir"
source "$repo_dir/agentscompanion.sh"

after_shell_flags="$(set -o | awk '$1 == "errexit" || $1 == "nounset" || $1 == "pipefail" { print $1 "=" $2 }')"

if [ "$before_shell_flags" != "$after_shell_flags" ]; then
  printf 'Sourcing agentscompanion.sh changed shell flags.\nBefore:\n%s\nAfter:\n%s\n' "$before_shell_flags" "$after_shell_flags" >&2
  exit 1
fi

tmux new-session -d -s "$base_session_name" sleep 30
collision_session_name="$(_agentscompanion_session_name copilot)"
tmux kill-session -t "$base_session_name"

if [ "$collision_session_name" != "copilot-1-$project_name" ]; then
  printf 'Unexpected collision session name: %s\n' "$collision_session_name" >&2
  exit 1
fi

copilot chat --model gpt-5.4 "hello world"
single_launch_log="$(cat "$log_file")"

assert_contains "$single_launch_log" "__CALL__"
assert_contains "$single_launch_log" "-a"
assert_contains "$single_launch_log" "-c"
assert_contains "$single_launch_log" "$tmp_dir"
assert_contains "$single_launch_log" "$fake_bin_dir/copilot"
assert_contains "$single_launch_log" "chat"
assert_contains "$single_launch_log" "--model"
assert_contains "$single_launch_log" "gpt-5.4"
assert_contains "$single_launch_log" "hello world"
assert_contains "$single_launch_log" "copilot-$project_name"

printf '' >"$log_file"

agentscompanion launch-set copilot codex
multi_launch_log="$(cat "$log_file")"
call_count="$(grep -c '^__CALL__$' "$log_file")"

if [ "$call_count" -ne 3 ]; then
  printf 'Expected 3 launcher calls, got %s\n%s\n' "$call_count" "$multi_launch_log" >&2
  exit 1
fi

assert_contains "$multi_launch_log" "$fake_bin_dir/copilot"
assert_contains "$multi_launch_log" "$fake_bin_dir/codex"
assert_contains "$multi_launch_log" "coordinator-$project_name"
assert_contains "$multi_launch_log" "-a"

version_output="$(bash "$repo_dir/agentscompanion.sh" --version)"

if [ "$version_output" != "$(cat "$repo_dir/VERSION")" ]; then
  printf 'Unexpected version output: %s\n' "$version_output" >&2
  exit 1
fi
