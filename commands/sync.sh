# wt sync
_wt_sync() {
  local root
  root="$(_wt_root)" || return 1

  local main_dir
  main_dir="$(_wt_main_dir "$root")"

  _wt_run_hook pre-sync || return 1

  echo "==> Fetching origin (with prune) ..."
  git -C "$root/.bare" fetch origin --prune

  echo "==> Updating $(_wt_default_branch "$root") worktree (ff-only) ..."
  git -C "$main_dir" pull --ff-only

  _wt_run_hook post-sync

  echo ""
  echo "$(_wt_default_branch "$root") is now at: $(git -C "$main_dir" log --oneline -1)"
}
