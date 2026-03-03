# wt list
_wt_list() {
  local root
  root="$(_wt_resolve_root)" || return 1

  local project_name
  project_name="$(basename "$root")"
  local base_branch
  base_branch="$(_wt_default_branch "$root")"

  echo "$project_name — $root"
  echo ""

  # Base branch first
  local commit
  commit="$(git -C "$root/$base_branch" log --oneline -1 2>/dev/null)"
  echo "  $base_branch  $commit"

  # Other worktrees
  local name
  for d in "$root"/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    [[ "$name" == .bare || "$name" == .wt ]] && continue
    [[ "$name" == "$base_branch" ]] && continue
    commit="$(git -C "$d" log --oneline -1 2>/dev/null)"
    echo "  $name  $commit"
  done
}
