#!/usr/bin/env bash
# VERSION contract test cases.

test_version_001() {
  local root="$1"
  if "$PB_PROJECT_ROOT/install/install-dev.sh" \
    --prefix "$root/pb" --bin-dir "$root/bin" --version v9.9.9 >/dev/null 2>&1; then
    pb_fail "expected --version v9.9.9 to be rejected"; return 1
  fi
  assert_file_absent "$root/pb/bin/project-bootstrap"

  local want
  want="$(tr -d '[:space:]' < "$PB_PROJECT_ROOT/VERSION")"
  "$PB_PROJECT_ROOT/install/install-dev.sh" \
    --prefix "$root/pb" --bin-dir "$root/bin" --version "$want" >/dev/null 2>&1
  assert_eq "$want" "$(project-bootstrap version)"
}
register "VERSION-001" "installer cannot fabricate version" test_version_001

test_version_002() {
  local root="$1"
  local src="$root/alt-source"
  mkdir -p "$src"
  cp -r "$PB_PROJECT_ROOT/scripts" "$PB_PROJECT_ROOT/lib" "$PB_PROJECT_ROOT/templates" "$PB_PROJECT_ROOT/bin" "$src/"
  printf 'v1.2.3\n' > "$src/VERSION"
  "$PB_PROJECT_ROOT/install/install-dev.sh" \
    --source "$src" --prefix "$root/pb" --bin-dir "$root/bin" >/dev/null 2>&1
  assert_eq "v1.2.3" "$(project-bootstrap version)"
}
register "VERSION-002" "installed VERSION == real source VERSION" test_version_002
