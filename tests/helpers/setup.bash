# Shared test setup — creates isolated git repo + fake HOME

WT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REAL_HOME="$HOME"

create_test_env() {
  TEMP_DIR="$(mktemp -d)"
  TEMP_HOME="$TEMP_DIR/home"
  TEMP_ORIGIN="$TEMP_DIR/origin.git"

  mkdir -p "$TEMP_HOME"

  # Create bare origin repo with HEAD pointing to main
  git init --bare "$TEMP_ORIGIN" --quiet
  git -C "$TEMP_ORIGIN" symbolic-ref HEAD refs/heads/main

  # Clone, make initial commit, push to main
  local clone="$TEMP_DIR/clone"
  git clone "$TEMP_ORIGIN" "$clone" --quiet 2>/dev/null
  git -C "$clone" checkout -b main --quiet 2>/dev/null
  git -C "$clone" config user.email "test@test.com"
  git -C "$clone" config user.name "Test"
  echo "init" > "$clone/README.md"
  git -C "$clone" add -A
  git -C "$clone" commit -m "Initial commit" --quiet
  git -C "$clone" push origin main --quiet 2>/dev/null
  rm -rf "$clone"

  # Sanity check
  if [[ ! -d "$TEMP_ORIGIN" ]]; then
    echo "[test setup] TEMP_ORIGIN not initialized, aborting" >&2
    return 1
  fi

  # Isolate HOME
  export HOME="$TEMP_HOME"

  # Source wt functions
  _WT_DIR="$WT_DIR"
  source "$WT_DIR/core/config.sh"
  source "$WT_DIR/core/utils.sh"
  source "$WT_DIR/core/root.sh"
  source "$WT_DIR/core/hooks.sh"
  source "$WT_DIR/core/commands.sh"
  for _f in "$WT_DIR"/commands/*.sh; do source "$_f"; done
  unset _f

  # Reset global flags
  _WT_CURRENT=false
  _WT_PROJECT=""
}

destroy_test_env() {
  export HOME="$REAL_HOME"
  rm -rf "$TEMP_DIR"
}

# Create a wt project from TEMP_ORIGIN into a temp target.
# Prints the project root path.
create_wt_project() {
  local origin="${1:-$TEMP_ORIGIN}"
  local target="$TEMP_DIR/project-$(date +%s%N)"
  _wt_init "$origin" "$target" >/dev/null 2>&1
  echo "$target"
}
