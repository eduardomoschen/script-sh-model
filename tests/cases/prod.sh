#!/usr/bin/env bash
# PROD test cases.

test_prod_001() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'S=1\n' > "$repo/.env.example"
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_file_exists "$repo/.env.production"
}
register "PROD-001" "creates .env.production" test_prod_001

test_prod_002() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'KEEP=1\n' > "$repo/.env.production"
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "KEEP=1" "$repo/.env.production"
}
register "PROD-002" "does not overwrite .env.production" test_prod_002

test_prod_003() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_mode "600" "$repo/.env.production"
}
register "PROD-003" "chmod 600 .env.production" test_prod_003

test_prod_004() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_file_not_contains "--env-file .env " "$root/docker.log"
  assert_file_absent "$repo/.env"
}
register "PROD-004" "never uses .env" test_prod_004

test_prod_005() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_file_not_contains "--env-file .env.prod " "$root/docker.log"
  assert_file_absent "$repo/.env.prod"
}
register "PROD-005" "never uses .env.prod" test_prod_005

test_prod_006() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "-f compose.yaml" "$root/docker.log"
  assert_contains "-f compose.prod.yaml" "$root/docker.log"
}
register "PROD-006" "uses compose.yaml + compose.prod.yaml" test_prod_006

test_prod_007() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  local ci ui
  ci="$(grep -n ' config ' "$root/docker.log" | head -1 | cut -d: -f1)"
  ui="$(grep -n ' up ' "$root/docker.log" | head -1 | cut -d: -f1)"
  [ -n "$ci" ] && [ -n "$ui" ] || { pb_fail "config or up missing from docker log"; return 1; }
  [ "$ci" -lt "$ui" ] || { pb_fail "expected config before up"; return 1; }
}
register "PROD-007" "config occurs before up" test_prod_007

test_prod_008() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  export PB_FAKE_DOCKER_CONFIG_FAIL=1
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1 \
    && { pb_fail "expected setup_prod to fail"; return 1; }
  assert_contains " config " "$root/docker.log"
  assert_file_not_contains " up " "$root/docker.log"
}
register "PROD-008" "config failure prevents up" test_prod_008

test_prod_009() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "up -d --build --remove-orphans --wait --wait-timeout 120" "$root/docker.log"
}
register "PROD-009" "up uses --remove-orphans" test_prod_009

test_prod_010() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "--wait" "$root/docker.log"
}
register "PROD-010" "up uses --wait" test_prod_010

test_prod_011() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "--wait-timeout 120" "$root/docker.log"
}
register "PROD-011" "wait-timeout is 120" test_prod_011

test_prod_012() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_file_exists "$repo/.env.production"
}
register "PROD-012" "second run is idempotent" test_prod_012
