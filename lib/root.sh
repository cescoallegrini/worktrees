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
