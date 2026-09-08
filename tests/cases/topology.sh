#!/usr/bin/env bash
# TOPOLOGY + name-override test cases.

test_dev_003() {
  local root="$1"
  local proj="$root/proj"
  mkdir -p "$proj"
  cat > "$proj/.project-bootstrap.conf" <<'EOF'
PROJECT_NAME=source-app
DEPLOY_NAME=deployed-app
EOF
  export HOMELAB_ROOT="$root/homelab"
  export HOOKS_ROOT="$root/etc/homelab-git/hooks"
  export DEPLOY_USER=""
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$proj" >/dev/null 2>&1
  assert_file_exists "$root/homelab/repos/deployed-app.git"
  assert_file_absent "$root/homelab/repos/source-app.git"
}
register "DEV-003" "accepts DEPLOY_NAME override" test_dev_003

test_topology_001() {
  local root="$1"
  export HOMELAB_ROOT="$root/homelab"
  export HOOKS_ROOT="$root/etc/homelab-git/hooks"
  export PROJECT_NAME="vaccine-fair-api"
  export DEPLOY_NAME="fair-principles-ic"
  export DEPLOY_USER=""
  mkdir -p "$root/proj"
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$root/proj" >/dev/null 2>&1
  assert_file_exists "$root/homelab/repos/fair-principles-ic.git"
  assert_file_exists "$root/homelab/apps/fair-principles-ic"
  assert_file_exists "$root/etc/homelab-git/hooks/fair-principles-ic.git"
  assert_file_absent "$root/homelab/repos/vaccine-fair-api.git"
}
register "TOPOLOGY-001" "PROJECT_NAME != DEPLOY_NAME yields correct paths" test_topology_001

test_topology_002() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_file_absent "$root/homelab/repos"
  assert_file_absent "$root/homelab/apps"
}
register "TOPOLOGY-002" "setup_dev does not touch homelab" test_topology_002

test_topology_003() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  git init --bare -q "$root/github/repo.git"
  printf '%s\n' "$root/github/repo.git" | "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_file_absent "$root/homelab/repos"
  assert_file_absent "$root/etc/homelab-git"
}
register "TOPOLOGY-003" "setup_git_remote does not touch homelab" test_topology_003

test_topology_004() {
  local root="$1"
  local ry="$root/ryzen/projects/demo"
  local hl="$root/homelab/apps/demo"
  make_git_project "$root/ryzen/projects" demo
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$hl/compose.yaml"
  printf 'services: {}\n' > "$hl/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$hl" >/dev/null 2>&1
  assert_file_exists "$hl/.env.production"
  assert_file_absent "$ry/.env.production"
}
register "TOPOLOGY-004" "setup_prod does not touch ryzen working copy" test_topology_004

test_topology_005() {
  local root="$1"
  export HOMELAB_ROOT="$root/homelab"
  export HOOKS_ROOT="$root/etc/homelab-git/hooks"
  export DEPLOY_NAME="demo"
  export DEPLOY_USER=""
  mkdir -p "$root/proj"
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$root/proj" >/dev/null 2>&1
  assert_file_absent "$root/proj/.env.development"
  assert_file_absent "$root/homelab/apps/demo/.env.development"
}
register "TOPOLOGY-005" "setup_git_deploy does not create .env.development" test_topology_005

test_topology_006() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  "$PB_PROJECT_ROOT/scripts/setup_dev.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "--env-file .env.development" "$root/docker.log"
  assert_not_contains ".env.production" "$root/docker.log"
}
register "TOPOLOGY-006" "development uses only .env.development" test_topology_006

test_topology_007() {
  local root="$1"
  local repo="$root/homelab/apps/demo"
  make_git_project "$root/homelab/apps" demo
  printf 'services: {}\n' > "$repo/compose.yaml"
  printf 'services: {}\n' > "$repo/compose.prod.yaml"
  "$PB_PROJECT_ROOT/scripts/setup_prod.sh" --project-dir "$repo" >/dev/null 2>&1
  assert_contains "--env-file .env.production" "$root/docker.log"
  assert_not_contains ".env.development" "$root/docker.log"
}
register "TOPOLOGY-007" "production uses only .env.production" test_topology_007

test_topology_008() {
  local root="$1"
  local repo="$root/ryzen/projects/demo"
  make_git_project "$root/ryzen/projects" demo
  git init --bare -q "$root/github/repo.git"
  printf '%s\n' "$root/github/repo.git" | "$PB_PROJECT_ROOT/scripts/setup_git_remote.sh" --project-dir "$repo" >/dev/null 2>&1
  git -C "$repo" remote | grep -q '^production$' && { pb_fail "setup_git_remote created production remote"; return 1; }
  export HOMELAB_ROOT="$root/homelab"
  export HOOKS_ROOT="$root/etc/homelab-git/hooks"
  export DEPLOY_NAME="demo"
  export DEPLOY_USER=""
  mkdir -p "$root/proj"
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$root/proj" >/dev/null 2>&1
  local bare="$root/homelab/repos/demo.git"
  [ -z "$(git --git-dir="$bare" remote)" ] || { pb_fail "setup_git_deploy created remotes on bare repo"; return 1; }
}
register "TOPOLOGY-008" "origin and production stay separate" test_topology_008
