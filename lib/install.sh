#!/usr/bin/env bash
# install.sh - shared staging/validation/overlay for the installers.

set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Stage project-bootstrap files from SOURCE into a fresh temp dir and validate.
# Prints the staging dir path on success. Fails (and cleans up) on any problem,
# so an invalid/incomplete download can never replace a healthy installation.
pb_stage_and_validate() {
  local source="$1"
  local stage
  stage="$(mktemp -d /tmp/project-bootstrap-install.XXXXXX)"

  for item in scripts lib templates bin VERSION; do
    [ -e "$source/$item" ] || { rm -rf "$stage"; return 1; }
  done

  cp -r "$source/scripts" "$source/lib" "$source/templates" "$source/bin" "$stage/"
  cp "$source/VERSION" "$stage/VERSION"

  local f
  for f in "$stage"/scripts/*.sh "$stage"/lib/*.sh "$stage"/templates/hooks/* "$stage"/bin/*; do
    [ -f "$f" ] || continue
    bash -n "$f" || { rm -rf "$stage"; return 1; }
  done

  printf '%s\n' "$stage"
}

pb_install_overlay() {
  local stage="$1" prefix="$2" bindir="$3"
  mkdir -p "$prefix" "$bindir"
  cp -r "$stage"/. "$prefix"/
  chmod +x "$prefix/bin/project-bootstrap"
  ln -sf "$prefix/bin/project-bootstrap" "$bindir/project-bootstrap"
}

# Fail early if we cannot write to a target location (walks up to first existing dir).
pb_preflight_writable() {
  local d="$1"
  while [ ! -e "$d" ]; do d="$(dirname "$d")"; done
  [ -w "$d" ]
}
