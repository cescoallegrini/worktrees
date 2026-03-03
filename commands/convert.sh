# wt convert [target-dir]
# Convert a normal git repo into a wt bare-repo worktree layout.
# Run from inside the repo to convert.
_wt_convert() {
  local repo_dir
  repo_dir="$(pwd)"

  # Must be a normal git repo (not already a worktree or bare repo)
  if [[ ! -d "$repo_dir/.git" ]]; then
    if [[ -f "$repo_dir/.git" ]]; then
      echo "Error: this looks like a git worktree (not a regular repo)."
    elif [[ -d "$repo_dir/.bare" ]]; then
      echo "Error: this repo already uses the wt layout."
    else
      echo "Error: not a git repository."
    fi
    return 1
  fi

  # Require a remote
  if ! git -C "$repo_dir" remote get-url origin &>/dev/null; then
    echo "Error: no 'origin' remote configured. wt requires a remote."
    return 1
  fi

  # Detect current branch before we move .git
  local current_branch
  current_branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"

  local target="${1:-$repo_dir}"

  if [[ "$target" != "$repo_dir" ]]; then
    if [[ -e "$target" ]]; then
      echo "Error: $target already exists."
      return 1
    fi
    target="$(mkdir -p "$target" && cd "$target" && pwd)"
    # Move everything into the new target
    mv "$repo_dir"/.git "$target/.git"
    mv "$repo_dir"/* "$repo_dir"/.* "$target/" 2>/dev/null
    repo_dir="$target"
  fi

  # Save the index so we can restore working tree state after conversion
  local saved_index
  saved_index="$(mktemp)"
  cp "$repo_dir/.git/index" "$saved_index"

  echo "==> Converting $repo_dir to wt layout ..."

  # Convert .git to bare repo at .bare
  mv "$repo_dir/.git" "$repo_dir/.bare"
  git -C "$repo_dir/.bare" config core.bare true

  echo "==> Configuring fetch refspec ..."
  git -C "$repo_dir/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

  echo "==> Fetching all branches ..."
  git -C "$repo_dir/.bare" fetch origin || return 1

  # Detect default branch from the remote, not from HEAD (which tracks the current branch)
  local default_branch
  default_branch="$(git -C "$repo_dir/.bare" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)"
  default_branch="${default_branch#refs/remotes/origin/}"
  # Fallback: check for common default branch names
  if [[ -z "$default_branch" ]]; then
    for candidate in main master; do
      if git -C "$repo_dir/.bare" show-ref --verify --quiet "refs/heads/$candidate" 2>/dev/null; then
        default_branch="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$default_branch" ]]; then
    echo "Error: could not detect default branch."
    echo "  Set it with: git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/<branch>"
    return 1
  fi
  # Point HEAD at the default branch (it may still reference the current branch)
  git -C "$repo_dir/.bare" symbolic-ref HEAD "refs/heads/$default_branch"

  echo "==> Detected default branch: $default_branch"

  # Move working tree files to a temp dir, then checkout cleanly
  local tmpdir
  tmpdir="$(mktemp -d "$repo_dir/.wt-convert-XXXXXX")"

  # Move everything except .bare and the temp dir itself
  for item in "$repo_dir"/* "$repo_dir"/.[!.]* "$repo_dir"/..?*; do
    [[ -e "$item" ]] || continue
    local name
    name="$(basename "$item")"
    [[ "$name" == ".bare" ]] && continue
    [[ "$item" == "$tmpdir" ]] && continue
    mv "$item" "$tmpdir/"
  done

  local on_different_branch=""
  if [[ -n "$current_branch" && "$current_branch" != "$default_branch" && "$current_branch" != "HEAD" ]]; then
    on_different_branch=1
  fi

  if [[ -n "$on_different_branch" ]]; then
    # On a feature branch — fresh checkout for default, preserve files for current
    echo "==> Creating $default_branch worktree ..."
    git -C "$repo_dir/.bare" worktree add "$repo_dir/$default_branch" "$default_branch"

    local dir_name
    dir_name="$(_wt_normalize_branch "$current_branch")"
    echo "==> Restoring $current_branch worktree with your working changes ..."
    git -C "$repo_dir/.bare" worktree add --no-checkout "$repo_dir/$dir_name" "$current_branch"
    mv "$tmpdir"/* "$tmpdir"/.[!.]* "$tmpdir"/..?* "$repo_dir/$dir_name/" 2>/dev/null
    # Restore the original index to preserve staged/unstaged state
    local wt_gitdir
    wt_gitdir="$(git -C "$repo_dir/$dir_name" rev-parse --git-dir)"
    cp "$saved_index" "$wt_gitdir/index"
  else
    # On the default branch — preserve files directly
    echo "==> Restoring $default_branch worktree with your working changes ..."
    git -C "$repo_dir/.bare" worktree add --no-checkout "$repo_dir/$default_branch" "$default_branch"
    mv "$tmpdir"/* "$tmpdir"/.[!.]* "$tmpdir"/..?* "$repo_dir/$default_branch/" 2>/dev/null
    # Restore the original index to preserve staged/unstaged state
    local wt_gitdir
    wt_gitdir="$(git -C "$repo_dir/$default_branch" rev-parse --git-dir)"
    cp "$saved_index" "$wt_gitdir/index"
  fi

  # Clean up temp files
  rm -rf "$tmpdir" "$saved_index"

  echo "==> Creating .wt/ directory ..."
  mkdir -p "$repo_dir/.wt/hooks" "$repo_dir/.wt/commands"

  echo ""
  echo "============================================"
  echo "  Conversion complete!"
  echo "============================================"
  echo "  Root:       $repo_dir"
  echo "  Bare repo:  $repo_dir/.bare"
  echo "  Main:       $repo_dir/$default_branch  (tracking $default_branch)"
  if [[ -n "$on_different_branch" ]]; then
    local dir_name
    dir_name="$(_wt_normalize_branch "$current_branch")"
    echo "  Branch:     $repo_dir/$dir_name  (tracking $current_branch)"
  fi
  echo "  Hooks:      $repo_dir/.wt/hooks/"
  echo "  Commands:   $repo_dir/.wt/commands/"
  echo ""
  if [[ -n "$on_different_branch" ]]; then
    local dir_name
    dir_name="$(_wt_normalize_branch "$current_branch")"
    echo "  cd $repo_dir/$dir_name to continue where you left off."
  else
    echo "  cd $repo_dir/$default_branch to get started."
  fi
  echo "============================================"
}
