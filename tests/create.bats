#!/usr/bin/env bats

load helpers/setup

setup() {
  create_test_env
  PROJECT="$(create_wt_project)"
  _WT_CURRENT=true
}
teardown() { destroy_test_env; }

@test "creates worktree at project root" {
  cd "$PROJECT/main"
  run _wt_create fix-bug
  [ "$status" -eq 0 ]
  [ -d "$PROJECT/fix-bug" ]
}

@test "normalizes slash in branch name to dash" {
  cd "$PROJECT/main"
  run _wt_create "feature/login"
  [ "$status" -eq 0 ]
  [ -d "$PROJECT/feature-login" ]
  local branch
  branch="$(git -C "$PROJECT/feature-login" rev-parse --abbrev-ref HEAD)"
  [ "$branch" = "feature/login" ]
}

@test "checks out existing remote branch" {
  # Create a branch on the remote
  local clone="$TEMP_DIR/tmp-clone"
  git clone "$TEMP_ORIGIN" "$clone" --quiet 2>/dev/null
  git -C "$clone" config user.email "test@test.com"
  git -C "$clone" config user.name "Test"
  git -C "$clone" checkout -b existing-branch --quiet
  echo "remote work" > "$clone/remote.txt"
  git -C "$clone" add -A
  git -C "$clone" commit -m "Remote branch commit" --quiet
  git -C "$clone" push origin existing-branch --quiet 2>/dev/null
  rm -rf "$clone"

  cd "$PROJECT/main"
  run _wt_create existing-branch
  [ "$status" -eq 0 ]
  [ -d "$PROJECT/existing-branch" ]
  [ -f "$PROJECT/existing-branch/remote.txt" ]
}

@test "creates new branch from default when no --from" {
  cd "$PROJECT/main"
  _wt_create new-feature >/dev/null
  local branch_ref main_ref
  branch_ref="$(git -C "$PROJECT/new-feature" rev-parse HEAD)"
  main_ref="$(git -C "$PROJECT/main" rev-parse HEAD)"
  [ "$branch_ref" = "$main_ref" ]
}

@test "--from resolves short name to origin ref" {
  # Create a develop branch on remote
  local clone="$TEMP_DIR/tmp-clone"
  git clone "$TEMP_ORIGIN" "$clone" --quiet 2>/dev/null
  git -C "$clone" config user.email "test@test.com"
  git -C "$clone" config user.name "Test"
  git -C "$clone" checkout -b develop --quiet
  echo "develop" > "$clone/develop.txt"
  git -C "$clone" add -A
  git -C "$clone" commit -m "Develop commit" --quiet
  git -C "$clone" push origin develop --quiet 2>/dev/null
  rm -rf "$clone"

  cd "$PROJECT/main"
  run _wt_create from-develop --from develop
  [ "$status" -eq 0 ]
  [ -f "$PROJECT/from-develop/develop.txt" ]
}

@test "fails if worktree already exists" {
  cd "$PROJECT/main"
  _wt_create fix-dup >/dev/null
  run _wt_create fix-dup
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "checks out existing local-only branch" {
  # Create a local branch in the bare repo (no remote tracking)
  git -C "$PROJECT/.bare" branch local-only main
  cd "$PROJECT/main"
  run _wt_create local-only
  [ "$status" -eq 0 ]
  [ -d "$PROJECT/local-only" ]
  local branch
  branch="$(git -C "$PROJECT/local-only" rev-parse --abbrev-ref HEAD)"
  [ "$branch" = "local-only" ]
}

@test "fails without branch name" {
  cd "$PROJECT/main"
  run _wt_create
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}
