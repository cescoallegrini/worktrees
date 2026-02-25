# wt create <branch> [--from <base>]
_wt_create() {
  local branch=""
  local base=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) base="$2"; shift 2 ;;
      -*) echo "Unknown option: $1"; echo "Usage: wt create <branch> [--from <base>]"; return 1 ;;
      *) branch="$1"; shift ;;
    esac
  done

  if [[ -z "$branch" ]]; then
    echo "Usage: wt create <branch> [--from <base>]"
    return 1
  fi

  local root
  root="$(_wt_root)" || return 1

  # Default base to origin's default branch
  if [[ -z "$base" ]]; then
    base="origin/$(_wt_default_branch "$root")"
  else
    # Auto-resolve: if ref doesn't exist, try origin/<ref>
    if ! git -C "$root/.bare" rev-parse --verify "$base" &>/dev/null; then
      if git -C "$root/.bare" rev-parse --verify "origin/$base" &>/dev/null; then
        base="origin/$base"
      fi
    fi
  fi

  # Normalize branch name for the directory
  local dir_name
  dir_name="$(_wt_normalize_branch "$branch")"

  if [[ -d "$root/worktrees/$dir_name" ]]; then
    echo "Worktree worktrees/$dir_name already exists."
    echo "  cd $root/worktrees/$dir_name"
    return 1
  fi

  WT_BRANCH="$branch" WT_DIR_NAME="$dir_name" WT_WORKTREE_PATH="$root/worktrees/$dir_name" \
    _wt_run_hook pre-create || return 1

  echo "==> Fetching latest from origin ..."
  git -C "$root/.bare" fetch origin

  # Check if branch exists on remote
  if git -C "$root/.bare" show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
    echo "==> Branch '$branch' exists on remote. Checking out ..."
    git -C "$root/.bare" worktree add "$root/worktrees/$dir_name" "$branch" || return 1
  else
    echo "==> Creating new branch '$branch' from $base ..."
    git -C "$root/.bare" worktree add "$root/worktrees/$dir_name" -b "$branch" "$base" || return 1
  fi

  WT_BRANCH="$branch" WT_DIR_NAME="$dir_name" WT_WORKTREE_PATH="$root/worktrees/$dir_name" \
    _wt_run_hook post-create

  echo ""
  echo "Worktree ready: $root/worktrees/$dir_name"
  echo ""
  echo "  cd $root/worktrees/$dir_name"
}
