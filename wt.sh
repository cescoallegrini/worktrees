#!/usr/bin/env bash
# wt — Worktree management CLI

_WT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")" && pwd)"

source "$_WT_DIR/core/config.sh"
source "$_WT_DIR/core/utils.sh"
source "$_WT_DIR/core/root.sh"
source "$_WT_DIR/core/hooks.sh"
source "$_WT_DIR/core/commands.sh"
for _f in "$_WT_DIR"/commands/*.sh; do source "$_f"; done
unset _f

_WT_PROJECT=""
_WT_CURRENT=false

# Parse global flags before the subcommand
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--current) _WT_CURRENT=true; shift ;;
    -p|--project) _WT_PROJECT="$2"; shift 2 ;;
    *) break ;;
  esac
done

cmd="$1"
if [[ -z "$cmd" ]]; then
  echo "Usage: wt [-p <project>] <command> [options]"
  echo ""
  echo "Global options:"
  echo "  -c, --current              Use the current project directly"
  echo "  -p, --project <name|path>  Operate on a specific project"
  echo ""
  echo "Commands:"
  echo "  init     Scaffold a bare-repo + worktrees container from a remote"
  echo "  convert  Convert a normal git repo to wt layout"
  echo "  create   Create a new worktree"
  echo "  sync     Fetch origin and update base branch"
  echo "  remove   Remove a worktree and its branch"
  echo "  pr       Check out a pull request into a worktree"
  echo "  list     List all worktrees"
  exit 1
fi

shift
case "$cmd" in
  init|convert|create|remove|sync|list|pr) "_wt_$cmd" "$@" ;;
  *) _wt_custom_cmd "$cmd" "$@" ;;
esac
