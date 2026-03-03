# wt pr <number>
_wt_pr() {
  local pr_number=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*) echo "Unknown option: $1"; echo "Usage: wt pr <number>"; return 1 ;;
      *) pr_number="$1"; shift ;;
    esac
  done

  if [[ -z "$pr_number" ]]; then
    echo "Usage: wt pr <number>"
    return 1
  fi

  if ! command -v gh &>/dev/null; then
    echo "Error: gh CLI is required. Install it from https://cli.github.com"
    return 1
  fi

  local root
  root="$(_wt_resolve_root)" || return 1

  echo "==> Fetching PR #$pr_number metadata ..."
  local branch
  branch="$(gh pr view "$pr_number" --repo "$(git -C "$root/.bare" remote get-url origin)" --json headRefName --jq '.headRefName')" || {
    echo "Error: could not fetch PR #$pr_number"
    return 1
  }

  local dir_name
  dir_name="$(_wt_normalize_branch "$branch")"

  if [[ -d "$root/$dir_name" ]]; then
    echo "Worktree $dir_name already exists."
    echo "  cd $root/$dir_name"
    return 1
  fi

  WT_BRANCH="$branch" WT_DIR_NAME="$dir_name" WT_WORKTREE_PATH="$root/$dir_name" \
    _wt_run_hook pre-create || return 1

  echo "==> Fetching latest from origin ..."
  git -C "$root/.bare" fetch origin || return 1

  echo "==> Checking out PR #$pr_number branch '$branch' ..."
  git -C "$root/.bare" worktree add "$root/$dir_name" "$branch" || return 1

  WT_BRANCH="$branch" WT_DIR_NAME="$dir_name" WT_WORKTREE_PATH="$root/$dir_name" \
    _wt_run_hook post-create

  echo ""
  echo "Worktree ready: $root/$dir_name"
  echo ""
  echo "  cd $root/$dir_name"
}
