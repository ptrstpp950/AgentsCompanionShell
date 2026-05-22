#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

for test_script in "$script_dir"/test_*.sh; do
  printf '==> %s\n' "$(basename "$test_script")"
  bash "$test_script"
done

printf 'All tests passed.\n'
