#!/usr/bin/env bats

load helpers/setup

setup() {
  create_test_env
  PROJECT="$(create_wt_project)"
  _WT_CURRENT=true
}
teardown() { destroy_test_env; }

@test "fast-forwards base branch after remote advances" {
  # Push a new commit to origin
  local clone="$TEMP_DIR/tmp-clone"
  git clone "$TEMP_ORIGIN" "$clone" --quiet 2>/dev/null
  git -C "$clone" config user.email "test@test.com"
  git -C "$clone" config user.name "Test"
  echo "new" > "$clone/new.txt"
  git -C "$clone" add -A
  git -C "$clone" commit -m "Advance main" --quiet
  git -C "$clone" push origin main --quiet 2>/dev/null
  rm -rf "$clone"

  local before
  before="$(git -C "$PROJECT/main" rev-parse HEAD)"

  cd "$PROJECT/main"
  run _wt_sync
  [ "$status" -eq 0 ]

  local after
  after="$(git -C "$PROJECT/main" rev-parse HEAD)"
  [ "$before" != "$after" ]
  [ -f "$PROJECT/main/new.txt" ]
}
