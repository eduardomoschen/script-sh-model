#!/usr/bin/env bash
# git.sh - git helpers used across the setup scripts.

set -euo pipefail

pb_git_toplevel() {
  git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null || true
}

pb_git_dir() {
  git -C "${1:-.}" rev-parse --git-dir 2>/dev/null || true
}

pb_in_git_repo() {
  git -C "${1:-.}" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

pb_origin_url() {
  git remote get-url origin 2>/dev/null || true
}

pb_git_available() {
  command -v git >/dev/null 2>&1
}
