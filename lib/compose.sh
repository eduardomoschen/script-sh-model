#!/usr/bin/env bash
# compose.sh - explicit docker compose invocations.
#
# The orchestrator always passes the env file and the compose files explicitly.
# No implicit `.env` resolution is ever relied upon; applications never need to
# know whether they run in development or production.

set -euo pipefail

pb_compose_config() {
  local env_file="$1" base="$2" override="$3"
  docker compose --env-file "$env_file" -f "$base" -f "$override" config --quiet
}

pb_compose_up_dev() {
  local env_file="$1" base="$2" override="$3"
  docker compose --env-file "$env_file" -f "$base" -f "$override" up -d --build
}

pb_compose_up_prod() {
  local env_file="$1" base="$2" override="$3"
  docker compose \
    --env-file "$env_file" \
    -f "$base" \
    -f "$override" \
    up -d --build --remove-orphans --wait --wait-timeout 120
}

pb_compose_available() {
  command -v docker >/dev/null 2>&1 || return 1
  docker compose version >/dev/null 2>&1 || return 1
}
