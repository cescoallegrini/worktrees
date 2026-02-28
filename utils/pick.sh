# Interactive picker: reads items from stdin, prints selection to stdout.
# Auto-selects when only one item. Uses fzf if available, numbered menu fallback.
# Usage: printf '%s\n' "${items[@]}" | wt_pick "Select branch"
wt_pick() {
  local prompt="${1:-Select}"

  local items=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && items+=("$line")
  done

  if [[ ${#items[@]} -eq 0 ]]; then
    echo "Error: nothing to select." >&2
    return 1
  fi

  if [[ ${#items[@]} -eq 1 ]]; then
    echo "${items[0]}"
    return 0
  fi

  # fzf if available
  if command -v fzf &>/dev/null; then
    printf '%s\n' "${items[@]}" | fzf --prompt="$prompt: " </dev/tty >/dev/tty
    return $?
  fi

  # Numbered menu fallback
  echo "$prompt:" >&2
  local i=1
  for item in "${items[@]}"; do
    echo "  $i) $item" >&2
    ((i++))
  done
  printf "Choice [1-%d]: " "${#items[@]}" >&2
  local choice
  read -r choice </dev/tty
  if [[ "$choice" -ge 1 && "$choice" -le "${#items[@]}" ]] 2>/dev/null; then
    echo "${items[$((choice - 1))]}"
    return 0
  fi
  echo "Error: invalid selection." >&2
  return 1
}
