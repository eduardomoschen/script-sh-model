#!/usr/bin/env bash
# harness.sh - executable contract for project-bootstrap.
#
# Usage:
#   ./tests/harness.sh fast              # run all fast tests
#   ./tests/harness.sh fast --only ID    # run a single test
#   HARNESS_VERBOSE=1 ./tests/harness.sh fast --only ID
#
# Fast tests use a temporary root (/tmp/project-bootstrap-harness.XXXXXX),
# REAL git, and FAKE docker/ssh/ssh-keygen/curl binaries. They never touch real
# infrastructure, the network, real sudo, or real Docker.

set -u

HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PB_PROJECT_ROOT="$HARNESS_ROOT"
export PB_FIXTURES="$HARNESS_ROOT/tests/fixtures"

MODE="${1:-}"
[ $# -gt 0 ] && shift
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    --verbose) HARNESS_VERBOSE=1; shift ;;
    *) shift ;;
  esac
done

if [ "$MODE" != "fast" ]; then
  printf 'usage: %s fast [--only ID]\n' "$0" >&2
  exit 1
fi

declare -a TESTS_ID=()
declare -a TESTS_DESC=()
declare -a TESTS_FUNC=()
register() { TESTS_ID+=("$1"); TESTS_DESC+=("$2"); TESTS_FUNC+=("$3"); }

# ---- assertion helpers (available to test functions via subshell) ----
pb_fail() { printf '%s\n' "$*" > "$FAIL_FILE"; return 1; }

assert_eq() {
  if [ "${2:-}" != "${1:-}" ]; then
    pb_fail "expected: ${1:-}
actual:   ${2:-}"
    return 1
  fi
}

assert_contains() {
  if ! grep -qF -- "$1" "$2" 2>/dev/null; then
    pb_fail "expected to find '$1' in $2"
    return 1
  fi
}

assert_not_contains() {
  if [ ! -e "$2" ]; then
    pb_fail "expected file to exist (so its absence cannot pass vacuously): $2"
    return 1
  fi
  if grep -qF -- "$1" "$2" 2>/dev/null; then
    pb_fail "expected NOT to find '$1' in $2"
    return 1
  fi
}

assert_file_not_contains() {
  assert_not_contains "$1" "$2"
}

assert_file_exists() {
  [ -e "$1" ] || { pb_fail "expected file to exist: $1"; return 1; }
}

assert_file_absent() {
  [ ! -e "$1" ] || { pb_fail "expected file to be absent: $1"; return 1; }
}

assert_mode() {
  local want="$1" path="$2"
  local got
  got="$(stat -c '%a' "$path" 2>/dev/null || stat -f '%Lp' "$path" 2>/dev/null)"
  if [ "$got" != "$want" ]; then
    pb_fail "expected mode $want for $path
actual:   $got"
    return 1
  fi
}

# ---- shared test helpers ----
make_git_project() {
  local dir="$1" name="$2"
  mkdir -p "$dir/$name"
  git -C "$dir/$name" init -q
  git -C "$dir/$name" config user.email "test@example.com"
  git -C "$dir/$name" config user.name "Test User"
  git -C "$dir/$name" checkout -q -b main 2>/dev/null || true
}

write_fakes() {
  local root="$1"
  cat > "$root/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${PB_FAKE_DOCKER_LOG:-/dev/null}"
has_config=0
for a in "$@"; do [ "$a" = "config" ] && has_config=1; done
if [ "${PB_FAKE_DOCKER_CONFIG_FAIL:-0}" = "1" ] && [ "$has_config" = "1" ]; then
  exit "${PB_FAKE_DOCKER_CONFIG_EXIT:-1}"
fi
exit 0
EOF
  cat > "$root/bin/ssh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${PB_FAKE_SSH_LOG:-/dev/null}"
if [ "${1:-}" = "-T" ]; then exit "${PB_FAKE_SSH_T_EXIT:-0}"; fi
exit 0
EOF
  cat > "$root/bin/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${PB_FAKE_SSHKEYGEN_LOG:-/dev/null}"
prev=""
for a in "$@"; do
  if [ "$prev" = "-f" ]; then : > "$a"; : > "$a.pub"; fi
  prev="$a"
done
exit 0
EOF
  cat > "$root/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${PB_FAKE_CURL_LOG:-/dev/null}"
exit "${PB_FAKE_CURL_EXIT:-0}"
EOF
  chmod +x "$root/bin/docker" "$root/bin/ssh" "$root/bin/ssh-keygen" "$root/bin/curl"
}

# ---- case discovery ----
for c in "$HARNESS_ROOT"/tests/cases/*.sh; do
  # shellcheck source=/dev/null
  source "$c"
done

# ---- runner ----
PASS=0
FAIL=0
FAILED_IDS=()

run_test() {
  local id="$1" desc="$2" func="$3"

  local root
  root="$(mktemp -d /tmp/project-bootstrap-harness.XXXXXX)"
  mkdir -p "$root/bin" "$root/fake-home" "$root/ryzen" "$root/homelab"
  write_fakes "$root"

  local out="$root/stdout" err="$root/stderr" failfile="$root/fail"

  (
    export PATH="$root/bin:$PATH"
    export HOME="$root/fake-home"
    export PB_TEST_ROOT="$root"
    export FAIL_FILE="$failfile"
    export PB_FAKE_DOCKER_LOG="$root/docker.log"
    export PB_FAKE_SSH_LOG="$root/ssh.log"
    export PB_FAKE_SSHKEYGEN_LOG="$root/ssh-keygen.log"
    export PB_FAKE_CURL_LOG="$root/curl.log"
    set -euo pipefail
    "$func" "$root"
  ) >"$out" 2>"$err"
  local rc=$?

  if [ "$rc" -eq 0 ] && [ ! -s "$failfile" ]; then
    PASS=$((PASS + 1))
    printf '[PASS] %s %s\n' "$id" "$desc"
  else
    FAIL=$((FAIL + 1))
    FAILED_IDS+=("$id")
    printf '[FAIL] %s %s\n' "$id" "$desc"
    if [ -s "$failfile" ]; then
      sed 's/^/  /' "$failfile"
    else
      tail -n 8 "$err" | sed 's/^/  stderr: /'
    fi
  fi

  if [ "${HARNESS_VERBOSE:-0}" = "1" ]; then
    [ -s "$out" ] && { printf '  --- stdout ---\n'; sed 's/^/  /' "$out"; }
    [ -s "$err" ] && { printf '  --- stderr ---\n'; sed 's/^/  /' "$err"; }
  fi

  rm -rf "$root"
}

for i in "${!TESTS_ID[@]}"; do
  if [ -n "$ONLY" ] && [ "${TESTS_ID[$i]}" != "$ONLY" ]; then
    continue
  fi
  run_test "${TESTS_ID[$i]}" "${TESTS_DESC[$i]}" "${TESTS_FUNC[$i]}"
done

printf '%d passed\n' "$PASS"
printf '%d failed\n' "$FAIL"
[ "$FAIL" -eq 0 ]
