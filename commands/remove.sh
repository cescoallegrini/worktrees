# wt remove <branch>
_wt_remove() {
  local branch="$1"
  local root
  root="$(_wt_resolve_root)" || return 1

  local base_branch
  base_branch="$(_wt_default_branch "$root")"

  if [[ -z "$branch" ]]; then
    local branches=()
    local name
    for d in "$root"/*/; do
      [[ -d "$d" ]] || continue
      name="$(basename "$d")"
      [[ "$name" == .bare || "$name" == .wt ]] && continue
      [[ "$name" == "$base_branch" ]] && continue
      branches+=("$name")
    done
    if [[ ${#branches[@]} -eq 0 ]]; then
      echo "No worktrees to remove."
      return 1
    fi
    branch="$(printf '%s\n' "${branches[@]}" | wt_pick "Select branch to remove")" || return 1
  fi

  local dir_name
  dir_name="$(_wt_normalize_branch "$branch")"

  if [[ "$dir_name" == "$base_branch" ]]; then
    echo "Error: cannot remove the base branch."
    return 1
  fi

  local wt_path="$root/$dir_name"

  if [[ ! -d "$wt_path" ]]; then
    echo "Error: worktree $dir_name does not exist."
    return 1
  fi

  # Check for uncommitted changes
  if ! git -C "$wt_path" diff --quiet HEAD 2>/dev/null || \
     [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]]; then
    echo "WARNING: $dir_name has uncommitted changes."
    printf "Proceed anyway? [y/N] "
    read -r reply
    if [[ "$reply" != [yY] ]]; then
      echo "Aborted."
      return 1
    fi
  fi

  WT_BRANCH="$branch" WT_DIR_NAME="$dir_name" WT_WORKTREE_PATH="$wt_path" \
    _wt_run_hook pre-remove || return 1

  echo "==> Removing worktree $dir_name ..."
  git -C "$root/.bare" worktree remove "$wt_path" --force

  echo "==> Deleting local branch $branch ..."
  git -C "$root/.bare" branch -D "$branch" 2>/dev/null || true

  echo "==> Pruning worktree metadata ..."
  git -C "$root/.bare" worktree prune

  WT_BRANCH="$branch" WT_DIR_NAME="$dir_name" WT_WORKTREE_PATH="$wt_path" \
    _wt_run_hook post-remove

  echo "Done. Worktree $dir_name removed."
}
