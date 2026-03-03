# Collect all worktree branches and present an interactive picker.
# Returns the selected branch name.
# Usage: branch="$(wt_select_branch)"
# Requires WT_ROOT_PATH to be set.
wt_select_branch() {
  local branches=()
  local name
  for d in "$WT_ROOT_PATH"/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    [[ "$name" == .* ]] && continue
    branches+=("$name")
  done
  printf '%s\n' "${branches[@]}" | wt_pick "Select branch"
}
