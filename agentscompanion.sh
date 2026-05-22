#!/usr/bin/env bash
# agentscompanion runtime version: 0.1.4

_agentscompanion_is_sourced() {
  if [ -n "${BASH_VERSION:-}" ]; then
    [ "${BASH_SOURCE[0]}" != "$0" ]
    return
  fi

  if [ -n "${ZSH_VERSION:-}" ]; then
    [ "${ZSH_ARGZERO:-$0}" != "$0" ]
    return
  fi

  return 1
}

_agentscompanion_script_path() {
  if [ -n "${BASH_VERSION:-}" ] && [ -n "${BASH_SOURCE[0]:-}" ]; then
    printf '%s\n' "${BASH_SOURCE[0]}"
    return 0
  fi

  if [ -n "${ZSH_VERSION:-}" ]; then
    printf '%s\n' "${(%):-%x}"
    return 0
  fi

  return 1
}

_agentscompanion_script_dir() {
  local script_path
  local script_dir

  script_path="$(_agentscompanion_script_path)" || return 1
  script_dir="$(cd "$(dirname "$script_path")" 2>/dev/null && pwd -P)" || return 1

  printf '%s\n' "$script_dir"
}

_agentscompanion_home() {
  if [ -n "${AGENTSCOMPANION_HOME:-}" ]; then
    printf '%s\n' "$AGENTSCOMPANION_HOME"
    return 0
  fi

  _agentscompanion_script_dir
}

_agentscompanion_version() {
  local home_dir
  local version_file

  if [ -n "${AGENTSCOMPANION_VERSION:-}" ]; then
    printf '%s\n' "$AGENTSCOMPANION_VERSION"
    return 0
  fi

  home_dir="$(_agentscompanion_home)" || {
    printf '0.1.0\n'
    return 0
  }

  version_file="$home_dir/VERSION"

  if [ -f "$version_file" ]; then
    IFS= read -r version_line <"$version_file"
    printf '%s\n' "$version_line"
    return 0
  fi

  printf '0.1.0\n'
}

_agentscompanion_tmux_launcher() {
  if [ -n "${AGENTSCOMPANION_TMUX_LAUNCHER:-}" ]; then
    printf '%s\n' "$AGENTSCOMPANION_TMUX_LAUNCHER"
    return 0
  fi

  printf '%s/lib/tmux-launch.sh\n' "$(_agentscompanion_home)"
}

_agentscompanion_sanitize_name() {
  local value="${1:-}"

  value="${value//[^[:alnum:]_-]/-}"

  while [ -n "$value" ] && { [ "${value#-}" != "$value" ] || [ "${value#_}" != "$value" ]; }; do
    value="${value#-}"
    value="${value#_}"
  done

  while [ -n "$value" ] && { [ "${value%-}" != "$value" ] || [ "${value%_}" != "$value" ]; }; do
    value="${value%-}"
    value="${value%_}"
  done

  printf '%s\n' "$value"
}

_agentscompanion_project_name() {
  local project_name

  project_name="$(basename "$PWD")"
  project_name="$(_agentscompanion_sanitize_name "$project_name")"

  if [ -z "$project_name" ]; then
    project_name="workspace"
  fi

  printf '%s\n' "$project_name"
}

_agentscompanion_session_base_name() {
  local role="$1"

  role="$(_agentscompanion_sanitize_name "$role")"

  if [ -z "$role" ]; then
    role="session"
  fi

  printf '%s-%s\n' "$role" "$(_agentscompanion_project_name)"
}

_agentscompanion_session_name() {
  local role="$1"
  local base_name
  local candidate
  local index=1

  base_name="$(_agentscompanion_session_base_name "$role")"
  candidate="$base_name"

  if ! command -v tmux >/dev/null 2>&1; then
    printf '%s\n' "$candidate"
    return 0
  fi

  while tmux has-session -t "$candidate" 2>/dev/null; do
    candidate="$role-$index-$(_agentscompanion_project_name)"
    index=$((index + 1))
  done

  printf '%s\n' "$candidate"
}

_agentscompanion_find_binary() {
  local command_name="$1"
  local candidate

  if [ -n "${BASH_VERSION:-}" ]; then
    candidate="$(type -P -- "$command_name" 2>/dev/null)" || return 1
  elif [ -n "${ZSH_VERSION:-}" ]; then
    candidate="$(whence -p "$command_name" 2>/dev/null)" || return 1
  else
    candidate="$(command -v -- "$command_name" 2>/dev/null)" || return 1
  fi

  if [ -n "$candidate" ] && [ -f "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

_agentscompanion_default_shell() {
  if [ -n "${SHELL:-}" ] && [ -x "${SHELL:-}" ]; then
    printf '%s\n' "$SHELL"
    return 0
  fi

  printf '/bin/sh\n'
}

_agentscompanion_should_attach() {
  case "${AGENTSCOMPANION_AUTO_ATTACH:-1}" in
    0|false|FALSE|no|NO)
      return 1
      ;;
  esac

  return 0
}

_agentscompanion_launch_with_session() {
  local role="$1"
  local attach_mode="$2"
  shift
  shift

  local launcher
  local session_name

  launcher="$(_agentscompanion_tmux_launcher)"
  session_name="$(_agentscompanion_session_name "$role")"

  if [ "$attach_mode" = "attach" ]; then
    "$launcher" -a -c "$PWD" -s "$session_name" -- "$@"
    return $?
  fi

  "$launcher" -c "$PWD" -s "$session_name" -- "$@"
}

_agentscompanion_launch_agent() {
  local agent_name="$1"
  local attach_mode="${2:-attach}"
  shift
  shift

  local binary_path

  if ! binary_path="$(_agentscompanion_find_binary "$agent_name")"; then
    printf 'Error: %s is not installed or not in PATH.\n' "$agent_name" >&2
    return 1
  fi

  _agentscompanion_launch_with_session "$agent_name" "$attach_mode" "$binary_path" "$@"
}

_agentscompanion_launch_coordinator() {
  local attach_mode="${1:-attach}"
  shift || true

  if [ "$#" -eq 0 ]; then
    _agentscompanion_launch_with_session coordinator "$attach_mode" "$(_agentscompanion_default_shell)"
    return $?
  fi

  _agentscompanion_launch_with_session coordinator "$attach_mode" "$@"
}

_agentscompanion_list_agents() {
  printf 'copilot\ncodex\nclaude\n'
}

_agentscompanion_usage() {
  cat <<'EOF'
Usage:
  source ~/.agentscompanion/agentscompanion.sh
  agentscompanion --version
  agentscompanion list-agents
  agentscompanion launch AGENT [ARG...]
  agentscompanion launch-coordinator
  agentscompanion launch-set [AGENT...]

Native wrappers:
  copilot [ARG...]
  codex [ARG...]
  claude [ARG...]
EOF
}

agentscompanion() {
  local command_name="${1:-}"

  case "$command_name" in
    ""|-h|--help|help)
      _agentscompanion_usage
      ;;
    --version|version)
      _agentscompanion_version
      ;;
    list-agents)
      _agentscompanion_list_agents
      ;;
    launch)
      shift || true

      if [ "$#" -eq 0 ]; then
        printf 'Error: launch requires an agent name.\n' >&2
        return 1
      fi

      local agent_name="$1"
      shift
      if _agentscompanion_should_attach; then
        _agentscompanion_launch_agent "$agent_name" attach "$@"
      else
        _agentscompanion_launch_agent "$agent_name" detach "$@"
      fi
      ;;
    launch-coordinator)
      shift || true
      if _agentscompanion_should_attach; then
        _agentscompanion_launch_coordinator attach "$@"
      else
        _agentscompanion_launch_coordinator detach "$@"
      fi
      ;;
    launch-set)
      local agent_name

      shift || true

      if [ "$#" -eq 0 ]; then
        set -- copilot codex claude
      fi

      for agent_name in "$@"; do
        _agentscompanion_launch_agent "$agent_name" detach || return 1
      done

      if _agentscompanion_should_attach; then
        _agentscompanion_launch_coordinator attach || return 1
      else
        _agentscompanion_launch_coordinator detach || return 1
      fi
      ;;
    *)
      printf 'Error: unknown agentscompanion command: %s\n' "$command_name" >&2
      _agentscompanion_usage >&2
      return 1
      ;;
  esac
}

copilot() {
  if _agentscompanion_should_attach; then
    _agentscompanion_launch_agent copilot attach "$@"
  else
    _agentscompanion_launch_agent copilot detach "$@"
  fi
}

codex() {
  if _agentscompanion_should_attach; then
    _agentscompanion_launch_agent codex attach "$@"
  else
    _agentscompanion_launch_agent codex detach "$@"
  fi
}

claude() {
  if _agentscompanion_should_attach; then
    _agentscompanion_launch_agent claude attach "$@"
  else
    _agentscompanion_launch_agent claude detach "$@"
  fi
}

if ! _agentscompanion_is_sourced; then
  agentscompanion "$@"
fi
