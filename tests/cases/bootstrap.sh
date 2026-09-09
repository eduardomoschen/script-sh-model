#!/usr/bin/env bash
# BOOTSTRAP (remote entrypoint) test cases.
#
# These tests never touch GitHub. They use a fake curl that serves a fixture
# archive built from a local source directory, plus a fake `id` to simulate root.

make_fixture_source() {
  local dir="$1" version="$2"
  mkdir -p "$dir/scripts" "$dir/lib" "$dir/templates" "$dir/bin" "$dir/install"
  printf '%s\n' "$version" > "$dir/VERSION"
  cat > "$dir/install/install-dev.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
src=""
prev=""
for a in "$@"; do
  if [ "$prev" = "--source" ]; then src="$a"; fi
  prev="$a"
done
printf '%s\n' "$src" > "${PB_INSTALLED_MARKER:?}"
EOF
  chmod +x "$dir/install/install-dev.sh"
  cat > "$dir/install/install-prod.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
src=""
prev=""
for a in "$@"; do
  if [ "$prev" = "--source" ]; then src="$a"; fi
  prev="$a"
done
printf '%s\n' "$src" > "${PB_INSTALLED_MARKER:?}"
EOF
  chmod +x "$dir/install/install-prod.sh"
  : > "$dir/scripts/setup_dev.sh"
  : > "$dir/lib/common.sh"
  : > "$dir/templates/project-bootstrap.conf"
  : > "$dir/bin/project-bootstrap"
}

# A curl that builds and serves a versioned .tar.gz from PB_FAKE_SOURCE_DIR.
# The archive's VERSION is PB_FAKE_SOURCE_VERSION (defaulting to the requested
# version), so a test can force a version mismatch.
write_serving_curl() {
  local root="$1"
  cat > "$root/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${PB_FAKE_CURL_LOG:-/dev/null}"
if [ "${PB_FAKE_CURL_EXIT:-0}" != "0" ]; then
  exit "${PB_FAKE_CURL_EXIT}"
fi
out=""
prev=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then out="$a"; fi
  prev="$a"
done
if [ -z "$out" ]; then
  exit 1
fi
version=""
for a in "$@"; do
  case "$a" in
    *'/archive/refs/tags/'*) version="$a" ;;
  esac
done
version="${version##*/}"
version="${version%.tar.gz}"
top="project-bootstrap-$version"
tmpd="$(mktemp -d)"
mkdir -p "$tmpd/$top"
cp -r "$PB_FAKE_SOURCE_DIR/." "$tmpd/$top/"
printf '%s\n' "${PB_FAKE_SOURCE_VERSION:-$version}" > "$tmpd/$top/VERSION"
tar -C "$tmpd" -czf "$out" "$top"
rm -rf "$tmpd"
exit 0
EOF
  chmod +x "$root/bin/curl"
}

write_fake_id_root() {
  local root="$1"
  cat > "$root/bin/id" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-u" ]; then printf '0\n'; fi
EOF
  chmod +x "$root/bin/id"
}

bootstrap_dev_setup() {
  local root="$1"
  make_fixture_source "$root/fixture-source" v0.1.0
  write_serving_curl "$root"
  export PB_FAKE_SOURCE_DIR="$root/fixture-source"
  export PB_FAKE_SOURCE_VERSION="v0.1.0"
  export PROJECT_BOOTSTRAP_VERSION="v0.1.0"
  export PB_INSTALLED_MARKER="$root/installed"
}

test_bootstrap_dev_001() {
  local root="$1"
  bootstrap_dev_setup "$root"
  local rundir="$root/pipedir"
  mkdir -p "$rundir"
  ( cd "$rundir" && cat "$PB_PROJECT_ROOT/install/bootstrap-dev.sh" | bash )
  assert_file_exists "$root/installed"
}
register "BOOTSTRAP-DEV-001" "standalone, needs no sibling lib" test_bootstrap_dev_001

test_bootstrap_dev_002() {
  local root="$1"
  bootstrap_dev_setup "$root"
  export PROJECT_BOOTSTRAP_VERSION="v0.1.0"
  "$PB_PROJECT_ROOT/install/bootstrap-dev.sh" >/dev/null 2>&1
  assert_contains "https://github.com/eduardomoschen/script-sh-model/archive/refs/tags/v0.1.0.tar.gz" "$root/curl.log"
}
register "BOOTSTRAP-DEV-002" "selects configured repository/version" test_bootstrap_dev_002

test_bootstrap_dev_003() {
  local root="$1"
  bootstrap_dev_setup "$root"
  export PROJECT_BOOTSTRAP_VERSION="v0.1.0"
  "$PB_PROJECT_ROOT/install/bootstrap-dev.sh" >/dev/null 2>&1
  assert_file_exists "$root/installed"
  assert_contains "project-bootstrap-v0.1.0" "$root/installed"
}
register "BOOTSTRAP-DEV-003" "downloads source of selected version" test_bootstrap_dev_003

test_bootstrap_dev_004() {
  local root="$1"
  bootstrap_dev_setup "$root"
  export PROJECT_BOOTSTRAP_VERSION="v9.9.9"
  if "$PB_PROJECT_ROOT/install/bootstrap-dev.sh" >/dev/null 2>&1; then
    pb_fail "expected version mismatch to fail"; return 1
  fi
  assert_file_absent "$root/installed"
}
register "BOOTSTRAP-DEV-004" "wrong source version fails" test_bootstrap_dev_004

test_bootstrap_dev_005() {
  local root="$1"
  bootstrap_dev_setup "$root"
  export PB_FAKE_CURL_EXIT="22"
  if "$PB_PROJECT_ROOT/install/bootstrap-dev.sh" >/dev/null 2>&1; then
    pb_fail "expected download failure to abort"; return 1
  fi
  assert_file_absent "$root/installed"
}
register "BOOTSTRAP-DEV-005" "failed download does not install" test_bootstrap_dev_005

test_bootstrap_dev_006() {
  local root="$1"
  bootstrap_dev_setup "$root"
  "$PB_PROJECT_ROOT/install/bootstrap-dev.sh" >/dev/null 2>&1
  assert_file_exists "$root/installed"
  assert_contains "/extract/" "$root/installed"
}
register "BOOTSTRAP-DEV-006" "runs installer dev from downloaded source" test_bootstrap_dev_006

test_bootstrap_dev_007() {
  local root="$1"
  bootstrap_dev_setup "$root"
  write_fake_id_root "$root"
  if "$PB_PROJECT_ROOT/install/bootstrap-dev.sh" >/dev/null 2>&1; then
    pb_fail "expected bootstrap-dev to refuse root"; return 1
  fi
  assert_file_absent "$root/installed"
}
register "BOOTSTRAP-DEV-007" "requires a non-root user" test_bootstrap_dev_007

bootstrap_prod_setup() {
  local root="$1"
  make_fixture_source "$root/fixture-source" v0.1.0
  write_serving_curl "$root"
  export PB_FAKE_SOURCE_DIR="$root/fixture-source"
  export PB_FAKE_SOURCE_VERSION="v0.1.0"
  export PROJECT_BOOTSTRAP_VERSION="v0.1.0"
  export PB_INSTALLED_MARKER="$root/installed"
}

test_bootstrap_prod_001() {
  local root="$1"
  bootstrap_prod_setup "$root"
  local rundir="$root/pipedir"
  mkdir -p "$rundir"
  ( cd "$rundir" && cat "$PB_PROJECT_ROOT/install/bootstrap-prod.sh" | bash )
  assert_file_exists "$root/installed"
}
register "BOOTSTRAP-PROD-001" "standalone, needs no sibling lib" test_bootstrap_prod_001

test_bootstrap_prod_002() {
  local root="$1"
  bootstrap_prod_setup "$root"
  export PROJECT_BOOTSTRAP_VERSION="v0.1.0"
  "$PB_PROJECT_ROOT/install/bootstrap-prod.sh" >/dev/null 2>&1
  assert_contains "https://github.com/eduardomoschen/script-sh-model/archive/refs/tags/v0.1.0.tar.gz" "$root/curl.log"
}
register "BOOTSTRAP-PROD-002" "selects configured repository/version" test_bootstrap_prod_002

test_bootstrap_prod_003() {
  local root="$1"
  bootstrap_prod_setup "$root"
  export PROJECT_BOOTSTRAP_VERSION="v9.9.9"
  if "$PB_PROJECT_ROOT/install/bootstrap-prod.sh" >/dev/null 2>&1; then
    pb_fail "expected version mismatch to fail"; return 1
  fi
  assert_file_absent "$root/installed"
}
register "BOOTSTRAP-PROD-003" "wrong source version fails" test_bootstrap_prod_003

test_bootstrap_prod_004() {
  local root="$1"
  bootstrap_prod_setup "$root"
  export PB_FAKE_CURL_EXIT="22"
  if "$PB_PROJECT_ROOT/install/bootstrap-prod.sh" >/dev/null 2>&1; then
    pb_fail "expected download failure to abort"; return 1
  fi
  assert_file_absent "$root/installed"
}
register "BOOTSTRAP-PROD-004" "failed download does not install" test_bootstrap_prod_004

test_bootstrap_prod_005() {
  local root="$1"
  bootstrap_prod_setup "$root"
  "$PB_PROJECT_ROOT/install/bootstrap-prod.sh" >/dev/null 2>&1
  assert_file_exists "$root/installed"
  assert_contains "/extract/" "$root/installed"
}
register "BOOTSTRAP-PROD-005" "runs installer prod from downloaded source" test_bootstrap_prod_005
