#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d)"
command_script="$tmp_dir/record-command.sh"
args_file="$tmp_dir/args.txt"
cwd_file="$tmp_dir/cwd.txt"
output_file="$tmp_dir/output.txt"
bash_bin="$(command -v bash)"

cleanup() {
  rm -rf "$tmp_dir"
}

trap cleanup EXIT

cat >"$command_script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
pwd >"$cwd_file"
printf '%s\n' "\$@" >"$args_file"
printf 'done\n' >"$output_file"
EOF

chmod +x "$command_script"

bash "$repo_dir/lib/tmux-launch.sh" -s agentscompanion-test-session -c "$tmp_dir" -- "$command_script" "arg one" 'arg"two'

sleep 1

if [ "$(cat "$cwd_file")" != "$tmp_dir" ]; then
  printf 'Expected command to run in %s\n' "$tmp_dir" >&2
  exit 1
fi

expected_args=$'arg one\narg"two'
actual_args="$(cat "$args_file")"

if [ "$actual_args" != "$expected_args" ]; then
  printf 'Unexpected arguments.\nExpected:\n%s\nActual:\n%s\n' "$expected_args" "$actual_args" >&2
  exit 1
fi

if [ "$(cat "$output_file")" != "done" ]; then
  printf 'Expected the launched command to finish successfully.\n' >&2
  exit 1
fi

missing_tmux_output="$(PATH="/nonexistent" "$bash_bin" "$repo_dir/lib/tmux-launch.sh" "$command_script" 2>&1 || true)"

if [[ "$missing_tmux_output" != *"tmux is required"* ]]; then
  printf 'Expected missing tmux guidance, got:\n%s\n' "$missing_tmux_output" >&2
  exit 1
fi

if [[ "$missing_tmux_output" != *"Install"* && "$missing_tmux_output" != *"install"* ]]; then
  printf 'Expected install help in missing tmux guidance, got:\n%s\n' "$missing_tmux_output" >&2
  exit 1
fi
