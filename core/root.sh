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
#   1. Explicit _WT_PROJECT (set by -p flag at entry point)
#   2. Upward traversal from $PWD
#   3. Interactive picker from DEFAULT_TARGET_DIR (TTY only)
#   4. Error
_wt_resolve_root() {
  # 1. Explicit -p flag
  if [[ -n "${_WT_PROJECT:-}" ]]; then
    local resolved
    resolved="$(cd "$_WT_PROJECT" 2>/dev/null && pwd)" || {
      echo "Error: $_WT_PROJECT does not exist." >&2; return 1
    }
    if [[ -d "$resolved/.bare" ]]; then
      echo "$resolved"
      return 0
    fi
    echo "Error: $resolved is not a worktree container (no .bare/ found)." >&2
    return 1
  fi

  # 2. Upward traversal
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.bare" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

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
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "Error: not inside a project and no TTY for interactive selection." >&2
    echo "  Use -p <path> to specify the project." >&2
    return 1
  fi

  # Interactive: fzf if available, otherwise numbered menu
  if command -v fzf &>/dev/null; then
    local names=()
    for p in "${projects[@]}"; do names+=("$(basename "$p")"); done
    local choice
    choice="$(printf '%s\n' "${names[@]}" | fzf --prompt="Select project: ")" || return 1
    echo "$search_dir/$choice"
    return 0
  fi

  # Numbered menu fallback
  echo "Select a project:" >&2
  local i=1
  for p in "${projects[@]}"; do
    echo "  $i) $(basename "$p")" >&2
    ((i++))
  done
  printf "Choice [1-%d]: " "${#projects[@]}" >&2
  local choice
  read -r choice
  if [[ "$choice" -ge 1 && "$choice" -le "${#projects[@]}" ]] 2>/dev/null; then
    echo "${projects[$((choice))]}"
    return 0
  fi
  echo "Error: invalid selection." >&2
  return 1
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
