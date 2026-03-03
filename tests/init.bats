#!/usr/bin/env bats

load helpers/setup

setup() { create_test_env; }
teardown() { destroy_test_env; }

@test "creates flat layout with .bare, .wt, and branch dir" {
  local target="$TEMP_DIR/myproject"
  run _wt_init "$TEMP_ORIGIN" "$target"
  [ "$status" -eq 0 ]
  [ -d "$target/.bare" ]
  [ -d "$target/.wt/hooks" ]
  [ -d "$target/.wt/commands" ]
  [ -d "$target/main" ]
  [ ! -d "$target/worktrees" ]
}

@test "detects default branch from remote" {
  local target="$TEMP_DIR/myproject"
  _wt_init "$TEMP_ORIGIN" "$target" >/dev/null
  local branch
  branch="$(git -C "$target/.bare" symbolic-ref HEAD)"
  [ "$branch" = "refs/heads/main" ]
}

@test "base worktree is a valid git checkout" {
  local target="$TEMP_DIR/myproject"
  _wt_init "$TEMP_ORIGIN" "$target" >/dev/null
  [ -f "$target/main/README.md" ]
  run git -C "$target/main" status
  [ "$status" -eq 0 ]
}

@test "fails without remote URL" {
  run _wt_init
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

@test "fails if target already exists" {
  local target="$TEMP_DIR/existing"
  mkdir -p "$target"
  run _wt_init "$TEMP_ORIGIN" "$target"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}
