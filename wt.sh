# wt — Worktree management CLI
# Source this from .zshrc: source ~/.local/bin/wt/wt.sh

_WT_DIR="${0:a:h}"

source "$_WT_DIR/lib/config.sh"
source "$_WT_DIR/lib/root.sh"
source "$_WT_DIR/lib/hooks.sh"
source "$_WT_DIR/lib/commands.sh"
for _f in "$_WT_DIR"/commands/*.sh; do source "$_f"; done
unset _f

wt() {
  local _WT_PROJECT=""

  # Parse global flags before the subcommand
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--project) _WT_PROJECT="$2"; shift 2 ;;
      *) break ;;
    esac
  done

  local cmd="$1"
  if [[ -z "$cmd" ]]; then
    echo "Usage: wt [-p <project>] <command> [options]"
    echo ""
    echo "Global options:"
    echo "  -p, --project <path>  Operate on a specific project"
    echo ""
    echo "Commands:"
    echo "  init     Scaffold a bare-repo + worktrees container"
    echo "  create   Create a new worktree"
    echo "  sync     Fetch origin and update base branch"
    echo "  remove   Remove a worktree and its branch"
    echo "  list     List all worktrees"
    return 1
  fi

  shift
  case "$cmd" in
    init|create|remove|sync|list) "_wt_$cmd" "$@" ;;
    *) _wt_custom_cmd "$cmd" "$@" ;;
  esac
}
