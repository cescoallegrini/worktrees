#!/usr/bin/env bats

load helpers/setup

setup() {
  create_test_env
  PROJECT="$(create_wt_project)"
  _WT_CURRENT=true
  cd "$PROJECT/main"
  _wt_create test-branch >/dev/null
}
teardown() { destroy_test_env; }

@test "removes worktree directory" {
  run _wt_remove test-branch
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT/test-branch" ]
}

@test "keeps local branch by default" {
  _wt_remove test-branch >/dev/null
  run git -C "$PROJECT/.bare" branch --list test-branch
  [[ "$output" == *"test-branch"* ]]
}

@test "deletes local branch with -d flag" {
  _wt_remove -d test-branch >/dev/null
  run git -C "$PROJECT/.bare" branch --list test-branch
  [ -z "$output" ]
}

@test "refuses to remove base branch" {
  run _wt_remove main
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot remove the base branch"* ]]
}

@test "prunes worktree metadata" {
  _wt_remove test-branch >/dev/null
  local stale
  stale="$(git -C "$PROJECT/.bare" worktree list --porcelain | grep -c prunable || true)"
  [ "$stale" -eq 0 ]
}

@test "fails for nonexistent worktree" {
  run _wt_remove nonexistent
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}
