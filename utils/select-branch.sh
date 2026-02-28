# Collect all worktree branches and present an interactive picker.
# Returns the selected branch name.
# Usage: branch="$(wt_select_branch)"
# Requires WT_ROOT_PATH and WT_BASE_BRANCH to be set.
wt_select_branch() {
  local branches=("$WT_BASE_BRANCH")
  for d in "$WT_ROOT_PATH"/worktrees/*/; do
    [[ -d "$d" ]] || continue
    branches+=("$(basename "$d")")
  done
  printf '%s\n' "${branches[@]}" | wt_pick "Select branch"
}
