#!/usr/bin/env bash
# doctor.sh - report environment status for project-bootstrap.
# Non-interactive, non-fatal (exit 0 even when pieces are missing).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/git.sh"
source "$SCRIPT_DIR/../lib/compose.sh"

say()  { printf '%-18s %s\n' "$1" "$2"; }
ok()   { printf 'ok\n'; }
miss() { printf 'missing\n'; }

printf 'project-bootstrap %s\n' "$PB_VERSION"
say "git" "$(command -v git 2>/dev/null || miss)"
say "docker" "$(command -v docker 2>/dev/null || miss)"
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  say "docker compose" "$(ok)"
else
  say "docker compose" "$(miss)"
fi
say "ssh" "$(command -v ssh 2>/dev/null || miss)"

if pb_in_git_repo "${1:-$(pwd)}"; then
  say "git repo" "$(ok)"
else
  say "git repo" "not detected"
fi

exit 0
