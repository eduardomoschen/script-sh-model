#!/usr/bin/env bash
# REMOTE test cases (GitHub SSH + origin).

make_github_bare() {
  local root="$1"
  mkdir -p "$root/github"
  git init --bare -q "$root/github/repo.git"
}

test_remote_001() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  make_github_bare "$root"
  local url="$root/github/repo.git"
  printf '%s\n' "$url" | "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_file_absent "$root/ssh-keygen.log"
}
register "REMOTE-001" "does not create key when SSH works" test_remote_001

test_remote_002() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  make_github_bare "$root"
  git -C "$repo" remote add origin "$root/github/repo.git"
  "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" </dev/null >/dev/null 2>&1
  assert_eq "$root/github/repo.git" "$(git -C "$repo" remote get-url origin)"
}
register "REMOTE-002" "detects existing origin" test_remote_002

test_remote_003() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  make_github_bare "$root"
  git -C "$repo" remote add origin "$root/github/repo.git"
  "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" </dev/null >/dev/null 2>&1
  assert_eq "1" "$(git -C "$repo" remote | grep -c '^origin$')"
}
register "REMOTE-003" "does not duplicate origin" test_remote_003

test_remote_004() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  make_github_bare "$root"
  git -C "$repo" remote add origin "$root/github/repo.git"
  local other="git@github.com:user/other.git"
  printf '%s\n' "$other" | "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_eq "$root/github/repo.git" "$(git -C "$repo" remote get-url origin)"
}
register "REMOTE-004" "does not overwrite different origin silently" test_remote_004

test_remote_005() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  make_github_bare "$root"
  printf '%s\n' "$root/github/repo.git" | "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_eq "$root/github/repo.git" "$(git -C "$repo" remote get-url origin)"
}
register "REMOTE-005" "allows SSH URL via stdin" test_remote_005

test_remote_006() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  make_github_bare "$root"
  printf '%s\n' "$root/github/repo.git" | "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_eq "$root/github/repo.git" "$(git -C "$repo" remote get-url origin)"
}
register "REMOTE-006" "configures correct origin" test_remote_006

test_remote_007() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  make_github_bare "$root"
  printf '%s\n' "$root/github/repo.git" | "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" >/dev/null 2>&1
  git -C "$repo" ls-remote origin >/dev/null 2>&1 || { pb_fail "git ls-remote origin failed"; return 1; }
}
register "REMOTE-007" "validates with git ls-remote" test_remote_007

test_remote_008() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  make_github_bare "$root"
  mkdir -p "$HOME/.ssh"
  printf 'PRIVATEKEYMARKER=superprivate\n' > "$HOME/.ssh/id_ed25519"
  printf 'ssh-ed25519 AAAA public\n' > "$HOME/.ssh/id_ed25519.pub"
  local out
  out="$(printf '%s\n' "$root/github/repo.git" | "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" 2>&1)"
  if printf '%s' "$out" | grep -qF 'superprivate'; then
    pb_fail "private key leaked to output"; return 1
  fi
}
register "REMOTE-008" "never prints private key" test_remote_008
