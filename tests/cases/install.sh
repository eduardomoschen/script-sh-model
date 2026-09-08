#!/usr/bin/env bash
# INSTALLER test cases.

test_installdev_001() {
  local root="$1"
  "$PB_PROJECT_ROOT/install/install-dev.sh" >/dev/null 2>&1
  assert_file_exists "$HOME/.local/lib/project-bootstrap/bin/project-bootstrap"
}
register "INSTALL-DEV-001" "does not require root" test_installdev_001

test_installdev_002() {
  local root="$1"
  "$PB_PROJECT_ROOT/install/install-dev.sh" >/dev/null 2>&1
  assert_file_exists "$HOME/.local/lib/project-bootstrap/scripts/setup_dev.sh"
  assert_file_exists "$HOME/.local/bin/project-bootstrap"
}
register "INSTALL-DEV-002" "installs in user-space" test_installdev_002

test_installdev_003() {
  local root="$1"
  "$PB_PROJECT_ROOT/install/install-dev.sh" >/dev/null 2>&1
  assert_file_absent "$root/homelab/repos"
  assert_file_absent "$root/etc"
  assert_file_absent "$root/homelab/apps"
}
register "INSTALL-DEV-003" "does not touch production structure" test_installdev_003

test_installdev_004() {
  local root="$1"
  "$PB_PROJECT_ROOT/install/install-dev.sh" >/dev/null 2>&1
  "$PB_PROJECT_ROOT/install/install-dev.sh" >/dev/null 2>&1
  assert_file_exists "$HOME/.local/bin/project-bootstrap"
}
register "INSTALL-DEV-004" "second install is idempotent" test_installdev_004

test_installprod_001() {
  local root="$1"
  mkdir -p "$root/readonly"
  chmod 555 "$root/readonly"
  if "$PB_PROJECT_ROOT/install/install-prod.sh" --prefix "$root/readonly/pb" >/dev/null 2>&1; then
    pb_fail "expected privilege failure"; return 1
  fi
}
register "INSTALL-PROD-001" "detects insufficient privilege" test_installprod_001

test_installprod_002() {
  local root="$1"
  "$PB_PROJECT_ROOT/install/install-prod.sh" --prefix "$root/pp" --bin-dir "$root/pbin" >/dev/null 2>&1
  assert_file_exists "$root/pp/bin/project-bootstrap"
  assert_file_exists "$root/pbin/project-bootstrap"
}
register "INSTALL-PROD-002" "installs to configurable prefix" test_installprod_002

test_installprod_003() {
  local root="$1"
  "$PB_PROJECT_ROOT/install/install-prod.sh" --prefix "$root/pp" --bin-dir "$root/pbin" >/dev/null 2>&1
  assert_file_absent "$root/pp/.env.development"
  assert_file_absent "$root/pp/.env.production"
}
register "INSTALL-PROD-003" "never creates .env.development" test_installprod_003

test_installprod_004() {
  local root="$1"
  "$PB_PROJECT_ROOT/install/install-prod.sh" --prefix "$root/pp" --bin-dir "$root/pbin" >/dev/null 2>&1
  "$PB_PROJECT_ROOT/install/install-prod.sh" --prefix "$root/pp" --bin-dir "$root/pbin" >/dev/null 2>&1
  assert_file_exists "$root/pp/bin/project-bootstrap"
}
register "INSTALL-PROD-004" "second install is idempotent" test_installprod_004

test_install_005() {
  local root="$1"
  "$PB_PROJECT_ROOT/install/install-dev.sh" --prefix "$root/pb" --bin-dir "$root/bin" >/dev/null 2>&1
  command -v project-bootstrap >/dev/null 2>&1 || { pb_fail "CLI not on PATH"; return 1; }
}
register "INSTALL-005" "CLI is installed" test_install_005

test_install_006() {
  local root="$1"
  local want
  want="$(tr -d '[:space:]' < "$PB_PROJECT_ROOT/VERSION")"
  "$PB_PROJECT_ROOT/install/install-dev.sh" --prefix "$root/pb" --bin-dir "$root/bin" >/dev/null 2>&1
  assert_eq "$want" "$(project-bootstrap version)"
}
register "INSTALL-006" "project-bootstrap version works" test_install_006

test_install_007() {
  local root="$1"
  local want
  want="$(tr -d '[:space:]' < "$PB_PROJECT_ROOT/VERSION")"
  "$PB_PROJECT_ROOT/install/install-dev.sh" --prefix "$root/pb" --bin-dir "$root/bin" >/dev/null 2>&1
  "$PB_PROJECT_ROOT/install/install-dev.sh" \
    --source "$PB_PROJECT_ROOT/tests/fixtures/broken-source" \
    --prefix "$root/pb" --bin-dir "$root/bin" >/dev/null 2>&1 \
    && { pb_fail "expected install from broken source to fail"; return 1; }
  assert_eq "$want" "$(project-bootstrap version)"
}
register "INSTALL-007" "invalid source does not replace healthy install" test_install_007

test_install_008() {
  if grep -RInE '(PASSWORD|TOKEN|SECRET|PRIVATE KEY|DATABASE_URL|API_KEY)=' "$PB_PROJECT_ROOT"/install "$PB_PROJECT_ROOT"/lib/install.sh; then
    pb_fail "secret found in installer"; return 1
  fi
  local out
  out="$("$PB_PROJECT_ROOT/install/install-dev.sh" --prefix "$1/pb" --bin-dir "$1/bin" 2>&1)"
  if printf '%s' "$out" | grep -qiE 'password|token|secret'; then
    pb_fail "installer printed secret"; return 1
  fi
}
register "INSTALL-008" "no installer contains or prints secrets" test_install_008
