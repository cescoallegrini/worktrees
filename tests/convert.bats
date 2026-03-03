#!/usr/bin/env bats

load helpers/setup

setup() { create_test_env; }
teardown() { destroy_test_env; }

# Helper: create a normal git repo with an origin
create_normal_repo() {
  local repo="$TEMP_DIR/normal-repo"
  git clone "$TEMP_ORIGIN" "$repo" --quiet 2>/dev/null
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "Test"
  echo "$repo"
}

@test "converts .git repo to .bare layout" {
  local repo="$(create_normal_repo)"
  cd "$repo"
  run _wt_convert
  [ "$status" -eq 0 ]
  [ -d "$repo/.bare" ]
  [ ! -d "$repo/.git" ]
  [ -d "$repo/.wt/hooks" ]
  [ -d "$repo/.wt/commands" ]
  [ -d "$repo/main" ]
}

@test "preserves untracked files on default branch" {
  local repo="$(create_normal_repo)"
  echo "untracked" > "$repo/untracked.txt"
  cd "$repo"
  _wt_convert >/dev/null
  [ -f "$repo/main/untracked.txt" ]
  [ "$(cat "$repo/main/untracked.txt")" = "untracked" ]
}

@test "preserves staged changes on default branch" {
  local repo="$(create_normal_repo)"
  echo "staged" > "$repo/staged.txt"
  git -C "$repo" add staged.txt
  cd "$repo"
  _wt_convert >/dev/null
  # File should exist in the worktree
  [ -f "$repo/main/staged.txt" ]
  # Should show as staged in git status
  run git -C "$repo/main" diff --cached --name-only
  [[ "$output" == *"staged.txt"* ]]
}

@test "on feature branch creates both worktrees" {
  local repo="$(create_normal_repo)"
  git -C "$repo" checkout -b feature-x --quiet
  echo "feature work" > "$repo/feature.txt"
  git -C "$repo" add -A
  git -C "$repo" commit -m "Feature commit" --quiet
  cd "$repo"
  run _wt_convert
  [ "$status" -eq 0 ]
  [ -d "$repo/main" ]
  [ -d "$repo/feature-x" ]
  [ -f "$repo/feature-x/feature.txt" ]
}

@test "converts to a different target directory" {
  local repo="$(create_normal_repo)"
  local target="$TEMP_DIR/new-location"
  cd "$repo"
  run _wt_convert "$target"
  [ "$status" -eq 0 ]
  [ -d "$target/.bare" ]
  [ -d "$target/main" ]
  [ ! -d "$repo/.git" ]
}

@test "fails if not a git repo" {
  local empty="$TEMP_DIR/empty"
  mkdir -p "$empty"
  cd "$empty"
  run _wt_convert
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a git repository"* ]]
}

@test "fails if already wt layout" {
  local repo="$(create_normal_repo)"
  cd "$repo"
  _wt_convert >/dev/null
  cd "$repo/main"
  run _wt_convert
  [ "$status" -eq 1 ]
}
