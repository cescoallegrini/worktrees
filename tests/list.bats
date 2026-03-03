#!/usr/bin/env bats

load helpers/setup

setup() {
  create_test_env
  PROJECT="$(create_wt_project)"
  _WT_CURRENT=true
}
teardown() { destroy_test_env; }

@test "lists base branch first" {
  cd "$PROJECT/main"
  run _wt_list
  [ "$status" -eq 0 ]
  # First non-empty content line after the header should be main
  local first_branch
  first_branch="$(echo "$output" | grep -v '^\s*$' | sed -n '2p' | awk '{print $1}')"
  [ "$first_branch" = "main" ]
}

@test "lists other worktrees" {
  cd "$PROJECT/main"
  _wt_create feat-a >/dev/null
  _wt_create feat-b >/dev/null
  run _wt_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat-a"* ]]
  [[ "$output" == *"feat-b"* ]]
}

@test "skips dot-prefixed directories" {
  cd "$PROJECT/main"
  mkdir "$PROJECT/.hidden"
  run _wt_list
  [ "$status" -eq 0 ]
  [[ "$output" != *".hidden"* ]]
}

@test "shows project name and path in header" {
  cd "$PROJECT/main"
  run _wt_list
  [ "$status" -eq 0 ]
  local project_name
  project_name="$(basename "$PROJECT")"
  [[ "$output" == *"$project_name"* ]]
  [[ "$output" == *"$PROJECT"* ]]
}
