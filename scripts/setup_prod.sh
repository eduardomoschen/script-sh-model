#!/usr/bin/env bash
# setup_prod.sh - configure the Production runtime for a project.
#
# Non-interactive. Uses ONLY:
#   .env.production + compose.yaml + compose.prod.yaml
#
# Does not configure GitHub, install hooks or create bare repositories.

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

# 3. create .env.production if missing (prefer .env.example), never overwrite.
if [ ! -f ".env.production" ]; then
  if [ -f ".env.example" ]; then
    cp ".env.example" ".env.production"
  else
    : > ".env.production"
  fi
fi
chmod 600 ".env.production"

# 6. validate mandatory files before touching docker.
for f in "$COMPOSE_BASE" "$COMPOSE_PROD"; do
  [ -f "$f" ] || pb_die "required compose file missing: $f"
done

pb_compose_available || pb_die "docker and docker compose are required"

# 7. validate config; NEVER run `up` when config fails.
pb_compose_config ".env.production" "$COMPOSE_BASE" "$COMPOSE_PROD" \
  || pb_die "docker compose config validation failed"

# 9. bring the stack up.
pb_compose_up_prod ".env.production" "$COMPOSE_BASE" "$COMPOSE_PROD"
