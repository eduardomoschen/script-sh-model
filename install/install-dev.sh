#!/usr/bin/env bash
# install-dev.sh - install project-bootstrap on a Development Host (user-space).
#
# Requirements: runs as a normal user, does not require root, respects XDG-ish
# defaults, never creates production structure, never touches /etc, never creates
# bare repositories, and is idempotent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/../lib/install.sh"

PREFIX="${PROJECT_BOOTSTRAP_PREFIX:-$HOME/.local/lib/project-bootstrap}"
BIN_DIR="${PROJECT_BOOTSTRAP_BIN_DIR:-$HOME/.local/bin}"
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

if [ "$(id -u)" -eq 0 ]; then
  die "install-dev.sh must run as a normal user (no root)"
fi

STAGE="$(pb_stage_and_validate "$SOURCE_DIR")" \
  || die "invalid source ($SOURCE_DIR); nothing installed"
trap 'rm -rf "$STAGE"' EXIT

if [ -n "$PIN_VERSION" ]; then
  printf '%s\n' "$PIN_VERSION" > "$STAGE/VERSION"
fi

pb_install_overlay "$STAGE" "$PREFIX" "$BIN_DIR"

printf 'installed project-bootstrap -> %s\n' "$PREFIX"
printf 'command: %s\n' "$BIN_DIR/project-bootstrap"
