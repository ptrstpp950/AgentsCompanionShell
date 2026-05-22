# Copilot instructions

## Test commands

- Run the full test suite with `./tests/run.sh`
- Run a single test with `bash tests/test_install.sh`, `bash tests/test_agentscompanion.sh`, `bash tests/test_tmux_launch.sh`, `bash tests/test_zsh.sh`, or `bash tests/test_prepare_install_sandbox.sh`
- Use `bash tests/sandbox_manual_test.sh` when you need a manual sandbox flow that does not touch the real shell config
- Use `bash tests/prepare_install_sandbox.sh --open-shell` when you want the helper to open a clean sandbox shell and print the short one-liner to paste inside it

## High-level architecture

- `agentscompanion.sh` is the sourceable entrypoint loaded from a shell rc file. It defines the native wrappers (`copilot`, `codex`, `claude`) and the `agentscompanion` dispatcher used for version checks and multi-agent launch commands.
- `bootstrap.sh` is the lightweight bootstrap entrypoint for `bash <(...)` installation flows. It can fetch `install.sh` from a base URL such as GitHub raw content and then hand off to `install.sh`.
- `bootstrap.sh` prints a change summary and asks for confirmation before editing the install directory or rc file; use `--yes` only for unattended flows and tests.
- Single-agent wrappers auto-attach to the new tmux session by default. `launch-set` starts the agent sessions first, then attaches to the coordinator session.
- Wrapper-created session names follow `role-project`, with numeric suffixes inserted only when a name is already taken (`copilot-project`, `copilot-1-project`, ...).
- `lib/tmux-launch.sh` is the standalone tmux launcher. Keep tmux/session management there rather than inside the sourced shell file so the interactive shell environment stays stable across bash and zsh.
- `install.sh` owns installation into `~/.agentscompanion` and updates a chosen rc file with a marked source block. It is designed for both local installs and future curl/wget installs by supporting `AGENTSCOMPANION_BASE_URL`.

## Key conventions

- Do not add top-level `set -euo pipefail` to `agentscompanion.sh`. It is sourced into the user's interactive shell, so shell options must stay unchanged unless explicitly scoped inside a subprocess.
- Wrapper functions must resolve the real executable from `PATH` and pass the resolved binary path into `lib/tmux-launch.sh`. Do not launch `copilot`, `codex`, or `claude` through a login shell name lookup, or the sourced wrapper functions can recurse inside tmux.
- Keep wrapper behavior thin. New agent integrations should reuse the shared helpers in `agentscompanion.sh` for session naming, binary lookup, and tmux launcher invocation rather than duplicating launch logic.
- Tests intentionally fake the tmux launcher in `tests/test_agentscompanion.sh` through `AGENTSCOMPANION_TMUX_LAUNCHER`; preserve that seam when refactoring so wrapper behavior can be validated without starting real tmux sessions.
