#!/usr/bin/env bash
# SECURITY test cases.

test_sec_001() {
  local f
  for f in "$PB_PROJECT_ROOT"/scripts/*.sh "$PB_PROJECT_ROOT"/lib/*.sh "$PB_PROJECT_ROOT"/bin/* "$PB_PROJECT_ROOT"/install/*.sh; do
    [ -f "$f" ] || continue
    bash -n "$f" || { pb_fail "bash -n failed: $f"; return 1; }
  done
}
register "SEC-001" "scripts/libs/bin/install pass bash -n" test_sec_001

test_sec_002() {
  local f
  for f in "$PB_PROJECT_ROOT"/templates/hooks/*; do
    bash -n "$f" || { pb_fail "bash -n failed: $f"; return 1; }
  done
}
register "SEC-002" "hooks pass bash -n" test_sec_002

test_sec_003() {
  if grep -RIn '\beval\b' "$PB_PROJECT_ROOT"/scripts "$PB_PROJECT_ROOT"/lib "$PB_PROJECT_ROOT"/templates "$PB_PROJECT_ROOT"/bin "$PB_PROJECT_ROOT"/install; then
    pb_fail "eval usage detected"; return 1
  fi
}
register "SEC-003" "no eval" test_sec_003

test_sec_004() {
  if grep -RInE '\bsource\b' "$PB_PROJECT_ROOT"/scripts "$PB_PROJECT_ROOT"/lib | grep -E '\.env|project-bootstrap\.conf'; then
    pb_fail "source of project-controlled file detected"; return 1
  fi
}
register "SEC-004" "no source of project-controlled config" test_sec_004

test_sec_005() {
  if grep -RIn '\bsed\b' "$PB_PROJECT_ROOT"/scripts "$PB_PROJECT_ROOT"/lib "$PB_PROJECT_ROOT"/templates "$PB_PROJECT_ROOT"/bin "$PB_PROJECT_ROOT"/install; then
    pb_fail "sed usage detected"; return 1
  fi
}
register "SEC-005" "no sed" test_sec_005

test_sec_006() {
  if grep -RInE 'rm -rf[[:space:]]+(/etc|/home|/usr|/ |\$HOME|\$PWD|~)' "$PB_PROJECT_ROOT"/scripts "$PB_PROJECT_ROOT"/lib "$PB_PROJECT_ROOT"/templates "$PB_PROJECT_ROOT"/bin "$PB_PROJECT_ROOT"/install; then
    pb_fail "dangerous rm -rf detected"; return 1
  fi
}
register "SEC-006" "no dangerous rm -rf" test_sec_006

test_sec_007() {
  if grep -RInE 'curl[^|]*\|[[:space:]]*(sudo[[:space:]]+)?bash' "$PB_PROJECT_ROOT"/scripts "$PB_PROJECT_ROOT"/lib "$PB_PROJECT_ROOT"/templates "$PB_PROJECT_ROOT"/bin "$PB_PROJECT_ROOT"/install; then
    pb_fail "curl | bash detected"; return 1
  fi
}
register "SEC-007" "no curl | bash" test_sec_007

test_sec_008() {
  if grep -RInE '(DATABASE_URL|PASSWORD|TOKEN|SECRET|API_KEY|PRIVATE_KEY)=' "$PB_PROJECT_ROOT"/templates/project-bootstrap.conf; then
    pb_fail "secret key in config template"; return 1
  fi
}
register "SEC-008" "config template has no secrets" test_sec_008

test_sec_009() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  printf 'TOP_SECRET=abc123xyz\n' > "$repo/.env.example"
  local out
  out="$("$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" 2>&1)"
  if printf '%s' "$out" | grep -qF 'abc123xyz'; then
    pb_fail "env secret leaked to stdout"; return 1
  fi
}
register "SEC-009" "env secrets never leaked to stdout" test_sec_009

test_sec_010() {
  local root="$1"
  local base="$root/ryzen/projects/my app"
  mkdir -p "$base"
  git -C "$base" init -q
  git -C "$base" config user.email t@t
  git -C "$base" config user.name t
  git -C "$base" checkout -q -b main 2>/dev/null || true
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$base" >/dev/null 2>&1
  assert_file_exists "$base/.env.development"
}
register "SEC-010" "paths with spaces do not break" test_sec_010
