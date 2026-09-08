#!/usr/bin/env bash
# setup_git_remote.sh - configure local git + GitHub SSH + remote `origin`.
#
# This is the ONLY interactive setup script. It is independent of
# development/production. It configures `origin` (GitHub) on a Development Host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/git.sh"

PROJECT_DIR="$(pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    -h|--help) printf 'usage: %s [--project-dir PATH]\n' "$(basename "$0")"; exit 0 ;;
    *) pb_die "unknown argument: $1" ;;
  esac
done

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

pb_git_available || pb_die "git is required"

if ! pb_in_git_repo "$PROJECT_DIR"; then
  pb_die "not a git repository: $PROJECT_DIR"
fi

TOPLEVEL="$(pb_git_toplevel "$PROJECT_DIR")"
[ -n "$TOPLEVEL" ] && cd "$TOPLEVEL"

ORIGIN_URL="$(pb_origin_url)"

# Existing, usable origin -> do not duplicate, do not touch it.
if [ -n "$ORIGIN_URL" ]; then
  if git ls-remote origin >/dev/null 2>&1; then
    printf 'origin already configured and reachable: %s\n' "$ORIGIN_URL"
    exit 0
  fi
  pb_die "origin exists ($ORIGIN_URL) but is unreachable; refusing to overwrite it silently"
fi

# 4. SSH availability + GitHub auth.
command -v ssh >/dev/null 2>&1 || pb_die "ssh is required"
if ! ssh -T git@github.com >/dev/null 2>&1; then
  existing_key=0
  for k in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/id_ecdsa.pub"; do
    [ -f "$k" ] && existing_key=1
  done
  if [ "$existing_key" -eq 1 ]; then
    pb_die "SSH auth to GitHub failed with an existing key; register your public key on GitHub"
  fi

  # 9. offer to create a user/machine ED25519 key (never per-project).
  if [ -t 0 ]; then
    printf 'No SSH key found and GitHub auth failed.\nCreate a new ED25519 key? (y/N): ' >&2
  fi
  IFS= read -r ans || ans=""
  case "$ans" in
    y|Y|yes)
      ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" -C "project-bootstrap" >/dev/null
      ;;
    *)
      pb_die "cannot proceed without working SSH access to GitHub"
      ;;
  esac
fi

# 12. ask for the SSH URL.
if [ -t 0 ]; then
  printf 'GitHub SSH URL (e.g. git@github.com:user/repo.git): ' >&2
fi
IFS= read -r URL || pb_die "no URL provided"
URL="$(pb_trim "$URL")"
[ -n "$URL" ] || pb_die "empty URL"

# 14. configure origin.
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$URL"
else
  git remote add origin "$URL"
fi

# 15. validate.
if ! git ls-remote origin >/dev/null 2>&1; then
  pb_die "origin validation failed: git ls-remote origin"
fi

printf 'origin configured: %s\n' "$(git remote get-url origin)"
