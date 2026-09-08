#!/usr/bin/env bash
# DEV test cases.

test_dev_001() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  mkdir -p "$repo/src/deep"
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo/src/deep" >/dev/null 2>&1
  assert_file_exists "$repo/.env.development"
  assert_file_absent "$repo/src/deep/.env.development"
}
register "DEV-001" "resolve project root" test_dev_001

test_dev_002() {
  local root="$1"
  local repo="$root/ryzen/projects/demo-app"
  make_git_project "$root/ryzen/projects" demo-app
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "PROJECT_NAME=demo-app" "$repo/.project-bootstrap.conf"
}
register "DEV-002" "infer project name" test_dev_002

test_dev_004() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  printf 'SECRET_VALUE=from-example\n' > "$repo/.env.example"
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_file_exists "$repo/.env.development"
  assert_contains "SECRET_VALUE=from-example" "$repo/.env.development"
}
register "DEV-004" "creates .env.development" test_dev_004

test_dev_005() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  printf 'KEEP_THIS=1\n' > "$repo/.env.development"
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "KEEP_THIS=1" "$repo/.env.development"
}
register "DEV-005" "does not overwrite .env.development" test_dev_005

test_dev_006() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_mode "600" "$repo/.env.development"
}
register "DEV-006" "chmod 600 .env.development" test_dev_006

test_dev_007() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_file_absent "$repo/.env"
}
register "DEV-007" "never creates .env" test_dev_007

test_dev_008() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "-f compose.yaml" "$root/docker.log"
  assert_contains "-f compose.dev.yaml" "$root/docker.log"
}
register "DEV-008" "uses compose.yaml + compose.dev.yaml" test_dev_008

test_dev_009() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "--env-file .env.development" "$root/docker.log"
}
register "DEV-009" "uses --env-file .env.development" test_dev_009

test_dev_010() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  export PB_FAKE_DOCKER_CONFIG_FAIL=1
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1 \
    && { pb_fail "expected setup_dev to fail"; return 1; }
  assert_not_contains " up " "$root/docker.log"
}
register "DEV-010" "config failure prevents up" test_dev_010

test_dev_011() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_eq "1" "$(grep -c '^\.env$' "$repo/.gitignore")" ".env line count"
  assert_eq "1" "$(grep -c '^\.env\.\*$' "$repo/.gitignore")" ".env.* line count"
}
register "DEV-011" "second run is idempotent" test_dev_011
