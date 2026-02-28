# Load all shared utilities from utils/
# Usage (in custom commands): . "$HOME/.wt/lib/core/utils.sh"
# Usage (in core):            source "$_WT_DIR/core/utils.sh"

_wt_utils_dir="${_WT_DIR:-$HOME/.wt/lib}"
for _f in "$_wt_utils_dir"/utils/*.sh; do
  [[ -f "$_f" ]] && source "$_f"
done
unset _f _wt_utils_dir
