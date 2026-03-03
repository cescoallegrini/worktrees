# Resolve the full filesystem path for a branch's worktree.
# Usage: wt_branch_path "feature-login"
# Requires WT_ROOT_PATH and WT_BASE_BRANCH to be set.
wt_branch_path() {
  local branch="$1"
  echo "$WT_ROOT_PATH/$branch"
}
