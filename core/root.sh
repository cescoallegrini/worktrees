# Find the worktree container root (directory containing .bare/)
_wt_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.bare" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "Error: not inside a worktree container (no .bare/ found above $PWD)" >&2
  return 1
}

# Resolve the project root using the full resolution chain:
#   1. -c flag: use current project from $PWD directly (fail if not inside one)
#   2. Explicit _WT_PROJECT (set by -p flag at entry point)
#   3. Upward traversal from $PWD + interactive picker
#   4. Interactive picker from DEFAULT_TARGET_DIR
#   5. Error
_wt_resolve_root() {
  # 1. -c flag — current project, no picker
  if [[ "${_WT_CURRENT:-false}" == true ]]; then
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
      if [[ -d "$dir/.bare" ]]; then
        echo "$dir"
        return 0
      fi
      dir="$(dirname "$dir")"
    done
    echo "Error: not inside a worktree container (no .bare/ found above $PWD)." >&2
    return 1
  fi

  # 2. Explicit -p flag
  if [[ -n "${_WT_PROJECT:-}" ]]; then
    local resolved

    # Try as a direct path first
    if resolved="$(cd "$_WT_PROJECT" 2>/dev/null && pwd)"; then
      if [[ -d "$resolved/.bare" ]]; then
        echo "$resolved"
        return 0
      fi
      echo "Error: $resolved is not a worktree container." >&2
      return 1
    fi

    # Try as a project name under DEFAULT_TARGET_DIR
    if [[ -n "${DEFAULT_TARGET_DIR:-}" && -d "$DEFAULT_TARGET_DIR/$_WT_PROJECT" ]]; then
      if [[ -d "$DEFAULT_TARGET_DIR/$_WT_PROJECT/.bare" ]]; then
        echo "$(cd "$DEFAULT_TARGET_DIR/$_WT_PROJECT" && pwd)"
        return 0
      fi
      echo "Error: $DEFAULT_TARGET_DIR/$_WT_PROJECT is not a worktree container." >&2
      return 1
    fi

    echo "Error: $_WT_PROJECT is not a valid path or project name." >&2
    return 1
  fi

  # 2. Upward traversal
  local detected=""
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.bare" ]]; then
      detected="$dir"
      break
    fi
    dir="$(dirname "$dir")"
  done

  if [[ -n "$detected" ]]; then
    # No DEFAULT_TARGET_DIR — use current project directly
    if [[ -z "${DEFAULT_TARGET_DIR:-}" ]]; then
      echo "$detected"
      return 0
    fi

    # Build list: current project first, then others from DEFAULT_TARGET_DIR
    local current_name
    current_name="$(basename "$detected")"
    local items=("$current_name (current)")
    for d in "$DEFAULT_TARGET_DIR"/*/; do
      [[ -d "${d}.bare" ]] || continue
      local name
      name="$(basename "$d")"
      [[ "$name" == "$current_name" ]] && continue
      items+=("$name")
    done

    local choice
    choice="$(printf '%s\n' "${items[@]}" | wt_pick "Select project")" || return 1
    if [[ "$choice" == "$current_name (current)" ]]; then
      echo "$detected"
    else
      echo "$DEFAULT_TARGET_DIR/$choice"
    fi
    return 0
  fi

  # 3. Interactive picker
  if [[ -n "${DEFAULT_TARGET_DIR:-}" ]]; then
    _wt_pick_project "$DEFAULT_TARGET_DIR"
    return $?
  fi

  # 4. Error
  echo "Error: not inside a project. Use -p <path> or set DEFAULT_TARGET_DIR in ~/.wt/config." >&2
  return 1
}

# Present an interactive project picker from a parent directory.
# Non-interactive environments get an error with guidance.
_wt_pick_project() {
  local search_dir="$1"
  local projects=()

  if [[ ! -d "$search_dir" ]]; then
    echo "Error: DEFAULT_TARGET_DIR ($search_dir) does not exist." >&2
    return 1
  fi

  for d in "$search_dir"/*/; do
    [[ -d "${d}.bare" ]] && projects+=("${d%/}")
  done

  if [[ ${#projects[@]} -eq 0 ]]; then
    echo "Error: no worktree containers found in $search_dir." >&2
    return 1
  fi

  # Non-interactive: error with guidance
  if ! : </dev/tty >/dev/tty 2>/dev/null; then
    echo "Error: not inside a project and no TTY for interactive selection." >&2
    echo "  Use -p <path> to specify the project." >&2
    return 1
  fi

  local names=()
  for p in "${projects[@]}"; do names+=("$(basename "$p")"); done

  local choice
  choice="$(printf '%s\n' "${names[@]}" | wt_pick "Select project")" || return 1
  echo "$search_dir/$choice"
}

# Get the default branch name from the bare repo's HEAD
_wt_default_branch() {
  local root="$1"
  local ref
  ref="$(git -C "$root/.bare" symbolic-ref HEAD 2>/dev/null)"
  echo "${ref#refs/heads/}"
}

# Get the path to the main worktree (named after the default branch)
_wt_main_dir() {
  local root="$1"
  local branch
  branch="$(_wt_default_branch "$root")"
  echo "$root/$branch"
}

# Normalize a branch name to a filesystem-safe directory name
# Replaces / with -
_wt_normalize_branch() {
  echo "${1//\//-}"
}
