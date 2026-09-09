#!/usr/bin/env bash
# common.sh - shared helpers for project-bootstrap scripts.
# This file is sourced by the public scripts; it is not meant to be run directly.
#
# Security rules honored here:
#   - The project's .project-bootstrap.conf is PARSED with an allowlist, never sourced.
#   - Only topology/behavior keys are accepted. Credentials are never allowed.

set -euo pipefail

# Installation root: directory that contains scripts/, lib/, templates/, bin/.
PB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PB_SCRIPT_DIR="$PB_ROOT/scripts"
PB_TEMPLATES_DIR="$PB_ROOT/templates"
PB_HOOKS_TEMPLATE_DIR="$PB_TEMPLATES_DIR/hooks"

# Single source of truth for the version.
if [ -f "$PB_ROOT/VERSION" ]; then
  PB_VERSION="$(tr -d '[:space:]' < "$PB_ROOT/VERSION")"
else
  PB_VERSION="${PROJECT_BOOTSTRAP_VERSION:-v0.2.0}"
fi

# Allowlist for .project-bootstrap.conf keys. Anything else is ignored with a warning.
PB_CONF_ALLOWED_KEYS="PROJECT_NAME DEPLOY_NAME DEPLOY_BRANCH COMPOSE_BASE COMPOSE_DEV COMPOSE_PROD HOMELAB_ROOT REPOS_ROOT APPS_ROOT HOOKS_ROOT GLOBAL_PRE_RECEIVE DEPLOY_USER"

pb_die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
pb_warn() { printf 'warn: %s\n'  "$*" >&2; }

pb_trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

# Parse an allowlisted KEY=VALUE file. Unknown keys are ignored with a warning.
# An explicitly-set environment variable always wins over the file (the file only
# fills variables that are still empty/unset).
pb_load_config() {
  local file="$1"
  [ -f "$file" ] || return 0
  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    # Full-line comments: optional leading whitespace followed by '#'.
    case "$line" in
      [[:space:]]*'#'*) continue ;;
      '#'*) continue ;;
    esac
    [ -n "$line" ] || continue
    key="${line%%=*}"
    [ "$key" = "$line" ] && { pb_warn "ignoring malformed config line (no '='): $line"; continue; }
    key="$(pb_trim "$key")"
    # Key must be a plain identifier; otherwise it can never match an allowlisted
    # key and would risk accidental glob matching or indirect-expansion tricks.
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      pb_warn "ignoring invalid config key: $key"
      continue
    fi
    val="${line#*=}"
    case " $PB_CONF_ALLOWED_KEYS " in
      *" $key "*)
        if [ -z "${!key:-}" ]; then
          printf -v "$key" '%s' "$(pb_trim "$val")"
        fi
        ;;
      *)
        pb_warn "ignoring unknown config key: $key"
        ;;
    esac
  done < "$file"
}

# Write the config template into $dest, injecting the inferred PROJECT_NAME.
pb_generate_config() {
  local dest="$1" inferred="$2"
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      PROJECT_NAME=) printf 'PROJECT_NAME=%s\n' "$inferred" ;;
      *)             printf '%s\n' "$line" ;;
    esac
  done < "$PB_TEMPLATES_DIR/project-bootstrap.conf" > "$dest"
}

# Resolve the target project directory and the standard topology variables.
# Order: environment > .project-bootstrap.conf > inferred/defaults.
pb_resolve_project() {
  local dir="${1:-$(pwd)}"
  dir="$(cd "$dir" && pwd)"

  if pb_in_git_repo "$dir"; then
    local tl
    tl="$(pb_git_toplevel "$dir")"
    [ -n "$tl" ] && dir="$tl"
  fi
  PB_PROJECT_DIR="$dir"
  local inferred
  inferred="$(basename "$dir")"

  local conf="$dir/.project-bootstrap.conf"
  if [ ! -f "$conf" ]; then
    pb_generate_config "$conf" "$inferred"
  fi
  pb_load_config "$conf"

  PROJECT_NAME="${PROJECT_NAME:-$inferred}"
  DEPLOY_NAME="${DEPLOY_NAME:-$PROJECT_NAME}"
  DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"
  COMPOSE_BASE="${COMPOSE_BASE:-compose.yaml}"
  COMPOSE_DEV="${COMPOSE_DEV:-compose.dev.yaml}"
  COMPOSE_PROD="${COMPOSE_PROD:-compose.prod.yaml}"
}
