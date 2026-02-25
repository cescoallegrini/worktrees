# wt list
_wt_list() {
  local root
  root="$(_wt_root)" || return 1

  git -C "$root/.bare" worktree list
}
