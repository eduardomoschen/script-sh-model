#!/usr/bin/env bash
# setup_dev.sh - configure a Development Host for a project.
#
# Non-interactive. Uses ONLY:
#   .env.development + compose.yaml + compose.dev.yaml
#
# Never creates a generic `.env`. Never overwrites an existing .env.development.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/git.sh"
source "$SCRIPT_DIR/../lib/compose.sh"

PROJECT_DIR="$(pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    -h|--help) printf 'usage: %s [--project-dir PATH]\n' "$(basename "$0")"; exit 0 ;;
    *) pb_die "unknown argument: $1" ;;
  esac
done

pb_resolve_project "$PROJECT_DIR"
cd "$PB_PROJECT_DIR"

# 5. create .env.development if missing (prefer .env.example), never overwrite.
if [ ! -f ".env.development" ]; then
  if [ -f ".env.example" ]; then
    cp ".env.example" ".env.development"
  else
    : > ".env.development"
  fi
fi
chmod 600 ".env.development"

# 8. guarantee env files are git-ignored (idempotent, exact-line check).
for _line in ".env" ".env.*" "!.env.example"; do
  if [ ! -f ".gitignore" ] || ! grep -qxF "$_line" ".gitignore"; then
    printf '%s\n' "$_line" >> ".gitignore"
  fi
done

# 10. validate Docker + Compose availability.
pb_compose_available || pb_die "docker and docker compose are required"

# 11. validate config; only proceed to `up` when it succeeds.
pb_compose_config ".env.development" "$COMPOSE_BASE" "$COMPOSE_DEV" \
  || pb_die "docker compose config validation failed"

# 12. bring the stack up.
pb_compose_up_dev ".env.development" "$COMPOSE_BASE" "$COMPOSE_DEV"
