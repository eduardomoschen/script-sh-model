#!/usr/bin/env bash
# CONFIG parser test cases.

test_config_001() {
  local root="$1"
  local proj="$root/proj"
  mkdir -p "$proj"
  cat > "$proj/.project-bootstrap.conf" <<'EOF'
DEPLOY_USX*=1
PROJECT_NAME=myapp
EOF
  export HOMELAB_ROOT="$root/homelab"
  export HOOKS_ROOT="$root/etc/homelab-git/hooks"
  export DEPLOY_USER=""
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$proj" >/dev/null 2>&1
  assert_file_exists "$root/homelab/repos/myapp.git"
}
register "CONFIG-001" "invalid key does not glob-match allowlist" test_config_001

test_config_002() {
  local root="$1"
  local proj="$root/proj"
  mkdir -p "$proj"
  printf 'PROJECT_NAME=my project\n' > "$proj/.project-bootstrap.conf"
  export HOMELAB_ROOT="$root/homelab"
  export HOOKS_ROOT="$root/etc/homelab-git/hooks"
  export DEPLOY_USER=""
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$proj" >/dev/null 2>&1
  assert_file_exists "$root/homelab/repos/my project.git"
}
register "CONFIG-002" "value with spaces preserved" test_config_002

test_config_003() {
  local root="$1"
  local proj="$root/proj"
  mkdir -p "$proj"
  printf 'PROJECT_NAME=$(touch /tmp/pwned)\n' > "$proj/.project-bootstrap.conf"
  export HOMELAB_ROOT="$root/homelab"
  export HOOKS_ROOT="$root/etc/homelab-git/hooks"
  export DEPLOY_USER=""
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$proj" >/dev/null 2>&1
  assert_file_absent "/tmp/pwned"
}
register "CONFIG-003" "no command substitution from config value" test_config_003
