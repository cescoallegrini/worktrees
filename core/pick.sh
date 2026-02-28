#!/usr/bin/env bash
# Generic interactive picker: reads items from stdin, prints selection to stdout.
# Usage: echo -e "a\nb\nc" | wt-pick "Select item"
set -euo pipefail

prompt="${1:-Select}"

items=()
while IFS= read -r line; do
  [[ -n "$line" ]] && items+=("$line")
done

if [[ ${#items[@]} -eq 0 ]]; then
  echo "Error: nothing to select." >&2
  exit 1
fi

if [[ ${#items[@]} -eq 1 ]]; then
  echo "${items[0]}"
  exit 0
fi

# fzf if available
if command -v fzf &>/dev/null; then
  printf '%s\n' "${items[@]}" | fzf --prompt="$prompt: " </dev/tty >/dev/tty
  exit $?
fi

# Numbered menu fallback
echo "$prompt:" >&2
local_i=1
for item in "${items[@]}"; do
  echo "  $local_i) $item" >&2
  ((local_i++))
done
printf "Choice [1-%d]: " "${#items[@]}" >&2
read -r choice </dev/tty
if [[ "$choice" -ge 1 && "$choice" -le "${#items[@]}" ]] 2>/dev/null; then
  echo "${items[$((choice - 1))]}"
  exit 0
fi
echo "Error: invalid selection." >&2
exit 1
