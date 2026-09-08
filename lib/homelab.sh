#!/usr/bin/env bash
# homelab.sh - bare repository + centralized hooks helpers.

set -euo pipefail

pb_bare_init() {
  local git_dir="$1"
  if [ ! -d "$git_dir" ]; then
    git init --bare "$git_dir"
  else
    git --git-dir="$git_dir" rev-parse --is-bare-repository >/dev/null 2>&1 \
      || return 1
  fi
}

pb_bare_set_head() {
  local git_dir="$1" branch="${2:-main}"
  git --git-dir="$git_dir" symbolic-ref HEAD "refs/heads/$branch"
}

pb_install_hook() {
  local src="$1" dst="$2"
  cp "$src" "$dst"
  chmod +x "$dst"
}

pb_set_hooks_path() {
  local git_dir="$1" hooks_dir="$2"
  git --git-dir="$git_dir" config core.hooksPath "$hooks_dir"
}

# Effective hooks directory as resolved by git (honors core.hooksPath).
pb_effective_hooks_path() {
  local git_dir="$1"
  git --git-dir="$git_dir" rev-parse --git-path hooks
}
