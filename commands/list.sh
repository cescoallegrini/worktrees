# wt list
_wt_list() {
  local root
  root="$(_wt_resolve_root)" || return 1

  local project_name
  project_name="$(basename "$root")"
  local base_branch
  base_branch="$(_wt_default_branch "$root")"
  local base_dir="$root/$base_branch"

  echo "$project_name — $root"
  echo ""

  # Base branch
  echo "Base:"
  local commit
  commit="$(git -C "$base_dir" log --oneline -1 2>/dev/null)"
  echo "  $base_branch  $commit"

  # Worktrees
  local has_worktrees=false
  for d in "$root"/worktrees/*/; do
    [[ -d "$d" ]] || continue
    if [[ "$has_worktrees" == false ]]; then
      echo ""
      echo "Worktrees:"
      has_worktrees=true
    fi
    local name
    name="$(basename "$d")"
    commit="$(git -C "$d" log --oneline -1 2>/dev/null)"
    echo "  $name  $commit"
  done

  if [[ "$has_worktrees" == false ]]; then
    echo ""
    echo "No worktrees."
  fi
}
