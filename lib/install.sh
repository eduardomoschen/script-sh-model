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
  local parent
  parent="$(dirname "$prefix")"
  mkdir -p "$parent" "$bindir" || return 1

  # Stage into a sibling dir of the live prefix (same filesystem) so the final
  # swap is an atomic rename. A failure at any point leaves the previous
  # installation untouched.
  local tmp backup=""
  tmp="$(mktemp -d "$parent/.project-bootstrap.install.XXXXXX")" || return 1

  cp -r "$stage"/. "$tmp"/ || { rm -rf "$tmp"; return 1; }
  chmod +x "$tmp/bin/project-bootstrap" || { rm -rf "$tmp"; return 1; }

  # Point the active symlink at the stable path before swapping content into it.
  ln -sf "$prefix/bin/project-bootstrap" "$bindir/project-bootstrap" || { rm -rf "$tmp"; return 1; }

  if [ -e "$prefix" ]; then
    backup="$(mktemp -d "$parent/.project-bootstrap.old.XXXXXX")" || { rm -rf "$tmp"; return 1; }
    rm -rf "$backup"
    mv "$prefix" "$backup" || { rm -rf "$tmp"; return 1; }
  fi

  if ! mv "$tmp" "$prefix"; then
    if [ -n "$backup" ]; then
      mv "$backup" "$prefix" 2>/dev/null || true
    fi
    rm -rf "$tmp"
    return 1
  fi

  [ -n "$backup" ] && rm -rf "$backup"
  return 0
}

# Fail early if we cannot write to a target location (walks up to first existing dir).
pb_preflight_writable() {
  local d="$1"
  while [ ! -e "$d" ]; do d="$(dirname "$d")"; done
  [ -w "$d" ]
}
