#!/usr/bin/env bash
# setup_git_deploy.sh - prepare the homelab Git bare + centralized hooks deploy.
#
# Non-interactive. Creates/validates:
#   REPOS_ROOT/<DEPLOY_NAME>.git          (bare repository)
#   HOOKS_ROOT/<DEPLOY_NAME>.git/         (centralized pre-receive/post-receive)
#   APPS_ROOT/<DEPLOY_NAME>/              (application checkout target)
#
# Configures core.hooksPath explicitly and validates the EFFECTIVE hooks path
# (this is how a stale hook still active in <bare>/hooks was discovered in FAIR).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/git.sh"
source "$SCRIPT_DIR/../lib/homelab.sh"

PROJECT_DIR="$(pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    -h|--help) printf 'usage: %s [--project-dir PATH]\n' "$(basename "$0")"; exit 0 ;;
    *) pb_die "unknown argument: $1" ;;
  esac
done

pb_resolve_project "$PROJECT_DIR"

# Deploy user: env > config > SUDO_USER > current user.
if [ -z "${DEPLOY_USER:-}" ]; then
  DEPLOY_USER="${SUDO_USER:-$(id -un)}"
fi

DEPLOY_NAME="${DEPLOY_NAME:-$PROJECT_NAME}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"

HOMELAB_ROOT="${HOMELAB_ROOT:-/home/$DEPLOY_USER/homelab}"
REPOS_ROOT="${REPOS_ROOT:-$HOMELAB_ROOT/repos}"
APPS_ROOT="${APPS_ROOT:-$HOMELAB_ROOT/apps}"
HOOKS_ROOT="${HOOKS_ROOT:-/etc/homelab-git/hooks}"
GLOBAL_PRE_RECEIVE="${GLOBAL_PRE_RECEIVE:-}"
COMPOSE_BASE="${COMPOSE_BASE:-compose.yaml}"
COMPOSE_PROD="${COMPOSE_PROD:-compose.prod.yaml}"

GIT_DIR="$REPOS_ROOT/$DEPLOY_NAME.git"
HOOK_DIR="$HOOKS_ROOT/$DEPLOY_NAME.git"
APP_DIR="$APPS_ROOT/$DEPLOY_NAME"

# Fail early if we cannot write to the required locations.
pb_preflight_writable() {
  local d="$1"
  while [ ! -e "$d" ]; do d="$(dirname "$d")"; done
  [ -w "$d" ] || return 1
}
for _target in "$REPOS_ROOT" "$APPS_ROOT" "$HOOKS_ROOT"; do
  pb_preflight_writable "$_target" \
    || pb_die "insufficient privileges to write $_target (run with sudo if it is under /etc or another user's home)"
done

mkdir -p "$REPOS_ROOT" "$APPS_ROOT" "$HOOKS_ROOT" "$HOOK_DIR"

# 1. create/validate bare repository (never destroy an existing one).
if ! pb_bare_init "$GIT_DIR"; then
  pb_die "$GIT_DIR exists but is not a bare repository"
fi

# 2. HEAD -> main.
pb_bare_set_head "$GIT_DIR" "$DEPLOY_BRANCH"

# 3. create the application target directory.
mkdir -p "$APP_DIR"

# 4-6. install centralized hooks.
pb_install_hook "$PB_HOOKS_TEMPLATE_DIR/pre-receive"  "$HOOK_DIR/pre-receive"
pb_install_hook "$PB_HOOKS_TEMPLATE_DIR/post-receive" "$HOOK_DIR/post-receive"

# Write the hook runtime config (topology only, no secrets).
{
  printf 'DEPLOY_NAME=%s\n' "$DEPLOY_NAME"
  printf 'DEPLOY_USER=%s\n' "$DEPLOY_USER"
  printf 'DEPLOY_BRANCH=%s\n' "$DEPLOY_BRANCH"
  printf 'APPS_ROOT=%s\n' "$APPS_ROOT"
  printf 'REPOS_ROOT=%s\n' "$REPOS_ROOT"
  printf 'HOOKS_ROOT=%s\n' "$HOOKS_ROOT"
  printf 'COMPOSE_BASE=%s\n' "$COMPOSE_BASE"
  printf 'COMPOSE_PROD=%s\n' "$COMPOSE_PROD"
  printf 'GLOBAL_PRE_RECEIVE=%s\n' "$GLOBAL_PRE_RECEIVE"
} > "$HOOK_DIR/config"

# 7. point core.hooksPath to the centralized directory.
pb_set_hooks_path "$GIT_DIR" "$HOOK_DIR"

# 8. validate the EFFECTIVE hooks path and hook syntax.
EFFECTIVE="$(pb_effective_hooks_path "$GIT_DIR")"
EFFECTIVE_ABS="$(readlink -f "$EFFECTIVE" 2>/dev/null || printf '%s' "$EFFECTIVE")"
HOOK_DIR_ABS="$(readlink -f "$HOOK_DIR" 2>/dev/null || printf '%s' "$HOOK_DIR")"
if [ "$EFFECTIVE_ABS" != "$HOOK_DIR_ABS" ]; then
  pb_die "core.hooksPath is not effective: $EFFECTIVE_ABS != $HOOK_DIR_ABS"
fi

bash -n "$HOOK_DIR/pre-receive"  || pb_die "pre-receive failed syntax check"
bash -n "$HOOK_DIR/post-receive" || pb_die "post-receive failed syntax check"

# 9. ownership: when running as root, give the app/repo/hooks to DEPLOY_USER.
if [ "$(id -u)" -eq 0 ] && [ -n "$DEPLOY_USER" ]; then
  chown -R "$DEPLOY_USER" "$GIT_DIR" "$APP_DIR" "$HOOK_DIR" 2>/dev/null || true
fi

printf 'bare:   %s\n' "$GIT_DIR"
printf 'hooks:  %s\n' "$HOOK_DIR"
printf 'app:    %s\n' "$APP_DIR"
