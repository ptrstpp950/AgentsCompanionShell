# agentscompanion.sh

`agentscompanion.sh` is a shell-first wrapper around `tmux` for launching agent CLIs like `copilot`, `codex`, and `claude` in their own tmux sessions.

## Project layout

- `agentscompanion.sh` is the sourceable top-level entrypoint.
- `bootstrap.sh` is the bootstrap script intended for `bash <(...)` install flows.
- `lib/tmux-launch.sh` is the standalone tmux launcher used by the wrappers.
- `install.sh` installs the tool into `~/.agentscompanion` and adds a `source` block to a chosen shell rc file.
- `tests/` contains the shell test suite.

## Local install

```bash
bash install.sh
```

Or install into a custom target and update a specific rc file:

```bash
AGENTSCOMPANION_INSTALL_DIR="$HOME/.agentscompanion" bash install.sh --rc-file "$HOME/.zshrc"
```

## Future curl/wget installer shape

The installer already supports downloading files from a hosted base URL:

```bash
curl -fsSL https://example.com/install.sh | AGENTSCOMPANION_BASE_URL="https://example.com/agentscompanion" bash -s -- --rc-file "$HOME/.zshrc"
```

Replace the placeholder URLs once the project is hosted.

## Usage

After reloading your shell:

```bash
copilot
codex --help
claude chat
agentscompanion --version
agentscompanion list-agents
agentscompanion launch-set copilot codex claude
```

`agentscompanion launch-set` starts a coordinator shell session plus one tmux session per agent in the current directory.
Single-agent wrappers like `copilot` auto-attach to the new tmux session by default.
Session names use the pattern `agent-project`, then `agent-1-project`, `agent-2-project`, and so on if a name is already taken.

## Tests

Run the full suite:

```bash
./tests/run.sh
```

Run a single test:

```bash
bash tests/test_install.sh
bash tests/test_zsh.sh
```

Create an isolated manual sandbox without touching your real shell config:

```bash
bash tests/sandbox_manual_test.sh
bash tests/sandbox_manual_test.sh --open-shell
```

Prepare an isolated install sandbox and get a copy-based one-liner you can paste:

```bash
bash tests/prepare_install_sandbox.sh
bash tests/prepare_install_sandbox.sh --open-shell
```

Inside the opened shell, the short command to paste is:

```bash
bash <(cat "$AGENTSCOMPANION_BOOTSTRAP_SCRIPT")
```

That flow now explains what will change and asks for confirmation. For a non-interactive run, append `--yes`.
