# wt init <git-remote-url> [target-dir]
_wt_init() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: wt init <git-remote-url> [target-dir]"
    return 1
  fi

  local remote="$1"
  local target="${2:-}"

  # Derive target from remote URL if not provided
  if [[ -z "$target" ]]; then
    if [[ -z "${DEFAULT_TARGET_DIR:-}" ]]; then
      echo "Error: no target dir provided and DEFAULT_TARGET_DIR is not set."
      echo "  Set it in ~/.wt/config or pass a target dir."
      return 1
    fi
    local repo_name
    repo_name="$(basename "$remote" .git)"
    target="$DEFAULT_TARGET_DIR/$repo_name"
  fi

  if [[ -e "$target" ]]; then
    echo "Error: $target already exists. Remove it first or pick a different path."
    return 1
  fi

  target="$(mkdir -p "$target" && cd "$target" && pwd)"

  echo "==> Cloning bare repo into $target/.bare ..."
  git clone --bare "$remote" "$target/.bare"

  echo "==> Configuring fetch refspec ..."
  git -C "$target/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

  echo "==> Fetching all branches ..."
  git -C "$target/.bare" fetch origin || return 1

  local branch
  branch="$(git -C "$target/.bare" symbolic-ref HEAD 2>/dev/null)"
  branch="${branch#refs/heads/}"
  if [[ -z "$branch" ]]; then
    echo "Error: could not detect default branch from remote."
    echo "  The remote may be empty. Push an initial commit first."
    return 1
  fi

  echo "==> Detected default branch: $branch"
  echo "==> Creating $branch worktree ..."
  git -C "$target/.bare" worktree add "$target/$branch" "$branch"

  echo "==> Creating .wt/ directory ..."
  mkdir -p "$target/.wt/hooks" "$target/.wt/commands"

  echo ""
  echo "============================================"
  echo "  Worktree container ready!"
  echo "============================================"
  echo "  Root:       $target"
  echo "  Bare repo:  $target/.bare"
  echo "  Main:       $target/$branch  (tracking $branch)"
  echo "  Hooks:      $target/.wt/hooks/"
  echo "  Commands:   $target/.wt/commands/"
  echo ""
  echo "  cd $target/$branch to get started."
  echo "============================================"
}
