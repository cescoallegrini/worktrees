#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/cescoallegrini/worktrees.git"
WT_DIR="$HOME/.wt"
SOURCE_LINE='source "$HOME/.wt/lib/wt.sh"'

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "==> Cloning wt ..."
git clone --depth 1 --quiet "$REPO_URL" "$tmp_dir/repo"
rm -rf "$tmp_dir/repo/.git"

echo "==> Installing to $WT_DIR ..."
mkdir -p "$WT_DIR"
rm -rf "$WT_DIR/lib"
mv "$tmp_dir/repo" "$WT_DIR/lib"

# Create user config from template if it doesn't exist
if [[ ! -f "$WT_DIR/config" ]]; then
  cp "$WT_DIR/lib/config.default" "$WT_DIR/config"
  echo "==> Created $WT_DIR/config"
fi

# Ensure global commands directory exists
mkdir -p "$WT_DIR/commands"

# Add source line to shell rc files
shell_configured=false

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || continue
  shell_configured=true
  if ! grep -qF '.wt/lib/wt.sh' "$rc"; then
    echo "" >> "$rc"
    echo "$SOURCE_LINE" >> "$rc"
    echo "==> Added source line to $rc"
  fi
done

echo ""
echo "============================================"
echo "  wt installed successfully!"
echo "============================================"

if [[ "$shell_configured" == false ]]; then
  echo ""
  echo "  Add this to your shell config:"
  echo "    $SOURCE_LINE"
fi

echo ""
echo "  Restart your shell or run:"
echo "    $SOURCE_LINE"
echo "============================================"
