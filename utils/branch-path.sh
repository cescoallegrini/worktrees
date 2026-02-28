# Resolve the full filesystem path for a branch's worktree.
# Usage: wt_branch_path "feature-login"
# Requires WT_ROOT_PATH and WT_BASE_BRANCH to be set.
wt_branch_path() {
  local branch="$1"
  if [[ "$branch" = "$WT_BASE_BRANCH" ]]; then
    echo "$WT_ROOT_PATH/$WT_BASE_BRANCH"
  else
    echo "$WT_ROOT_PATH/worktrees/$branch"
  fi
}
