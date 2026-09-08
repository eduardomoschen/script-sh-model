#!/usr/bin/env bash
# install-prod.sh - install project-bootstrap on a Production Host (system).
#
# Requirements: supports a system install, fails early if the required
# privileges are unavailable, never contains secrets, never creates
# .env.development, and is idempotent.
#
# Privileges are validated against the actual target prefix (so a configurable
# prefix under /tmp remains testable without root), and never via repeated sudo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/../lib/install.sh"

PREFIX="${PROJECT_BOOTSTRAP_PREFIX:-/usr/local/lib/project-bootstrap}"
BIN_DIR="${PROJECT_BOOTSTRAP_BIN_DIR:-/usr/local/bin}"
PIN_VERSION=""

while [ $# -gt 0 ]; do
  case "$1" in
    --source)  SOURCE_DIR="$2"; shift 2 ;;
    --prefix)  PREFIX="$2"; shift 2 ;;
    --bin-dir) BIN_DIR="$2"; shift 2 ;;
    --version) PIN_VERSION="$2"; shift 2 ;;
    -h|--help)
      printf 'usage: %s [--source DIR] [--prefix DIR] [--bin-dir DIR] [--version V]\n' "$(basename "$0")"
      exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

for _target in "$PREFIX" "$BIN_DIR"; do
  pb_preflight_writable "$_target" \
    || die "insufficient privileges to install to $_target (run with sudo)"
done

STAGE="$(pb_stage_and_validate "$SOURCE_DIR")" \
  || die "invalid source ($SOURCE_DIR); nothing installed"
trap 'rm -rf "$STAGE"' EXIT

if [ -n "$PIN_VERSION" ]; then
  printf '%s\n' "$PIN_VERSION" > "$STAGE/VERSION"
fi

pb_install_overlay "$STAGE" "$PREFIX" "$BIN_DIR"

printf 'installed project-bootstrap -> %s\n' "$PREFIX"
printf 'command: %s\n' "$BIN_DIR/project-bootstrap"
