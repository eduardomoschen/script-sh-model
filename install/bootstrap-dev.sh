#!/usr/bin/env bash
# bootstrap-dev.sh - standalone remote entrypoint for Development Hosts.
#
# Fetches a versioned project-bootstrap release and delegates installation to
# the source's own install/install-dev.sh. It is fully self-contained: it never
# sources a sibling file, so it works even when no local copy of
# project-bootstrap exists (e.g. downloaded and piped into bash).
#
# Recommended usage:
#   curl -fsSL https://raw.githubusercontent.com/eduardomoschen/script-sh-model/v0.2.0/install/bootstrap-dev.sh -o /tmp/project-bootstrap-bootstrap-dev.sh
#   less /tmp/project-bootstrap-bootstrap-dev.sh
#   bash /tmp/project-bootstrap-bootstrap-dev.sh

set -euo pipefail

PROJECT_BOOTSTRAP_REPOSITORY="${PROJECT_BOOTSTRAP_REPOSITORY:-eduardomoschen/script-sh-model}"
PROJECT_BOOTSTRAP_VERSION="${PROJECT_BOOTSTRAP_VERSION:-v0.2.0}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [ "$(id -u)" -eq 0 ]; then
  die "bootstrap-dev.sh must run as a normal user (no root)"
fi

repo="$PROJECT_BOOTSTRAP_REPOSITORY"
version="$PROJECT_BOOTSTRAP_VERSION"

case "$repo" in
  ''|*[!A-Za-z0-9._/-]*) die "invalid PROJECT_BOOTSTRAP_REPOSITORY: $repo" ;;
esac
case "$repo" in
  *..*|/*|*/|*//*) die "invalid PROJECT_BOOTSTRAP_REPOSITORY: $repo" ;;
esac
case "$version" in
  ''|*[!A-Za-z0-9._-]*) die "invalid PROJECT_BOOTSTRAP_VERSION: $version" ;;
esac

tmp="$(mktemp -d /tmp/project-bootstrap-bootstrap.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

archive="$tmp/source.tar.gz"
url="https://github.com/${repo}/archive/refs/tags/${version}.tar.gz"

if ! curl --fail --silent --show-error --location "$url" -o "$archive"; then
  die "download failed: $url"
fi

[ -s "$archive" ] || die "downloaded archive is empty: $url"

if ! tar -tzf "$archive" > "$tmp/listing" 2>/dev/null; then
  die "downloaded archive is not a valid tar.gz: $url"
fi

while IFS= read -r entry || [ -n "$entry" ]; do
  case "$entry" in
    /*) die "archive contains an absolute path: $entry" ;;
  esac
  IFS='/' read -r -a _parts <<< "$entry"
  for _p in "${_parts[@]}"; do
    [ "$_p" = ".." ] && die "archive contains path traversal: $entry"
  done
done < "$tmp/listing"

extract="$tmp/extract"
mkdir -p "$extract"
if ! tar -xzf "$archive" -C "$extract"; then
  die "failed to extract archive: $url"
fi

find_source_root() {
  local base="$1"
  local d
  if [ -f "$base/VERSION" ] && [ -f "$base/install/install-dev.sh" ]; then
    printf '%s\n' "$base"
    return 0
  fi
  for d in "$base"/*/; do
    [ -d "$d" ] || continue
    if [ -f "$d/VERSION" ] && [ -f "$d/install/install-dev.sh" ]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

source_root="$(find_source_root "$extract")" \
  || die "extracted source is missing VERSION/install/install-dev.sh"

for item in scripts lib templates bin VERSION install; do
  [ -e "$source_root/$item" ] || die "extracted source missing required item: $item"
done
[ -f "$source_root/install/install-dev.sh" ] || die "extracted source missing install/install-dev.sh"

source_version="$(tr -d '[:space:]' < "$source_root/VERSION")"
if [ "$source_version" != "$version" ]; then
  die "source version $source_version does not match requested $version"
fi

"$source_root/install/install-dev.sh" --source "$source_root" "$@"
