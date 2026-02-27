#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/cescoallegrini/worktrees.git"
WT_DIR="$HOME/.wt"
BIN_DIR="$HOME/.local/bin"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "==> Cloning wt ..."
git clone --depth 1 --quiet "$REPO_URL" "$tmp_dir/repo"
rm -rf "$tmp_dir/repo/.git"

echo "==> Installing to $WT_DIR ..."
mkdir -p "$WT_DIR"
rm -rf "$WT_DIR/lib"
mv "$tmp_dir/repo" "$WT_DIR/lib"
chmod +x "$WT_DIR/lib/wt.sh"

# Create user config from template if it doesn't exist
if [[ ! -f "$WT_DIR/config" ]]; then
  cp "$WT_DIR/lib/config.default" "$WT_DIR/config"
  echo "==> Created $WT_DIR/config"
fi

# Ensure global commands directory exists
mkdir -p "$WT_DIR/commands"

# Symlink wt to PATH
mkdir -p "$BIN_DIR"
ln -sf "$WT_DIR/lib/wt.sh" "$BIN_DIR/wt"
echo "==> Symlinked wt to $BIN_DIR/wt"

# Remove old source line from shell rc files
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || continue
  if grep -qF '.wt/lib/wt.sh' "$rc"; then
    sed -i '' '/.wt\/lib\/wt.sh/d' "$rc"
    echo "==> Removed old source line from $rc"
  fi
done

# Ensure ~/.local/bin is on PATH
path_configured=false
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || continue
  if grep -qF '.local/bin' "$rc"; then
    path_configured=true
  fi
done

echo ""
echo "============================================"
echo "  wt installed successfully!"
echo "============================================"

if [[ "$path_configured" == false ]]; then
  echo ""
  echo "  Ensure ~/.local/bin is on your PATH:"
  echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
echo "  Restart your shell or run: hash -r"
echo "============================================"
