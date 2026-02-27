# Dispatch a custom command from <root>/.wt/commands/ or global ~/.wt/commands/
# Project commands take priority over global commands.
# Usage: _wt_custom_cmd <command> [args...]
_wt_custom_cmd() {
  local cmd="$1"; shift
  local root
  root="$(_wt_resolve_root)" || return 1

  local project_cmd="$root/.wt/commands/$cmd"
  local global_cmd="$HOME/.wt/commands/$cmd"

  local script=""
  if [[ -x "$project_cmd" ]]; then
    script="$project_cmd"
  elif [[ -x "$global_cmd" ]]; then
    script="$global_cmd"
  else
    echo "Unknown command: $cmd"
    wt
    return 1
  fi

  WT_BARE_PATH="$root/.bare" \
    WT_BASE_BRANCH="$(_wt_default_branch "$root")" \
    WT_ROOT_PATH="$root" \
    "$script" "$@"
}
