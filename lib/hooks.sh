# Run a lifecycle hook if it exists in <root>/.wt/hooks/
# pre-* hooks abort on non-zero exit. post-* hooks warn but continue.
# Usage: WT_BRANCH=... WT_DIR_NAME=... WT_WORKTREE_PATH=... _wt_run_hook <event>
_wt_run_hook() {
  local event="$1"
  local root
  root="$(_wt_root 2>/dev/null)" || return 0

  local hook="$root/.wt/hooks/$event"
  [[ -x "$hook" ]] || return 0

  echo "==> Running hook: $event ..."
  WT_BARE_PATH="$root/.bare" \
    WT_BASE_BRANCH="$(_wt_default_branch "$root")" \
    WT_BRANCH="${WT_BRANCH:-}" \
    WT_DIR_NAME="${WT_DIR_NAME:-}" \
    WT_HOOK="$event" \
    WT_ROOT_PATH="$root" \
    WT_WORKTREE_PATH="${WT_WORKTREE_PATH:-}" \
    "$hook"

  local rc=$?
  if [[ $rc -ne 0 ]]; then
    if [[ "$event" == pre-* ]]; then
      echo "Error: hook $event failed (exit $rc). Aborting."
      return $rc
    else
      echo "WARNING: hook $event exited with $rc"
    fi
  fi
}
