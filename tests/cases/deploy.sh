#!/usr/bin/env bash
# DEPLOY + TOPOLOGY test cases (bare repo + centralized hooks).

deploy_prepare() {
  local root="$1" deploy_name="$2" project_name="$3"
  export HOMELAB_ROOT="$root/homelab"
  export HOOKS_ROOT="$root/etc/homelab-git/hooks"
  export DEPLOY_NAME="$deploy_name"
  export PROJECT_NAME="$project_name"
  export DEPLOY_USER=""
  mkdir -p "$root/proj"
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$root/proj" >/dev/null 2>&1
  BARE="$root/homelab/repos/$deploy_name.git"
  HOOKD="$root/etc/homelab-git/hooks/$deploy_name.git"
  APPD="$root/homelab/apps/$deploy_name"
}

make_work() {
  local root="$1" name="$2"
  make_git_project "$root/ryzen/projects" "$name"
  WORK="$root/ryzen/projects/$name"
  git -C "$WORK" remote add deploy "$BARE" 2>/dev/null
}

add_file() {
  local path="$1"
  mkdir -p "$(dirname "$WORK/$path")"
  printf 'x\n' > "$WORK/$path"
  git -C "$WORK" add "$path"
}

test_deploy_001() {
  local root="$1"
  deploy_prepare "$root" demo demo
  assert_file_exists "$BARE"
  assert_eq "true" "$(git --git-dir="$BARE" rev-parse --is-bare-repository)"
}
register "DEPLOY-001" "creates bare repository" test_deploy_001

test_deploy_002() {
  local root="$1"
  deploy_prepare "$root" demo demo
  assert_eq "refs/heads/main" "$(git --git-dir="$BARE" symbolic-ref HEAD)"
}
register "DEPLOY-002" "bare HEAD=main" test_deploy_002

test_deploy_003() {
  local root="$1"
  deploy_prepare "$root" demo demo
  assert_file_exists "$APPD"
}
register "DEPLOY-003" "creates apps target" test_deploy_003

test_deploy_004() {
  local root="$1"
  deploy_prepare "$root" demo demo
  assert_file_exists "$HOOKD"
}
register "DEPLOY-004" "creates central hooks directory" test_deploy_004

test_deploy_005() {
  local root="$1"
  deploy_prepare "$root" demo demo
  assert_eq "$HOOKD" "$(git --git-dir="$BARE" config core.hooksPath)"
}
register "DEPLOY-005" "configures core.hooksPath" test_deploy_005

test_deploy_006() {
  local root="$1"
  deploy_prepare "$root" demo demo
  assert_eq "$HOOKD" "$(git --git-dir="$BARE" rev-parse --git-path hooks)"
}
register "DEPLOY-006" "rev-parse --git-path hooks is central dir" test_deploy_006

# --- pre-receive behavior (via real push) ---

push_repo() {
  local branch="$1"
  git -C "$WORK" push deploy "$branch" 2>&1
}

test_deploy_007() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file ".env.example"
  git -C "$WORK" commit -qm "add .env.example"
  push_repo main >/dev/null
}
register "DEPLOY-007" "pre-receive allows .env.example" test_deploy_007

test_deploy_008() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file "backend/.env.example"
  git -C "$WORK" commit -qm "add nested .env.example"
  push_repo main >/dev/null
}
register "DEPLOY-008" "pre-receive allows nested .env.example" test_deploy_008

test_deploy_009() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file ".env"
  git -C "$WORK" commit -qm "add .env"
  if push_repo main >/dev/null; then pb_fail "expected push to be rejected"; return 1; fi
}
register "DEPLOY-009" "blocks .env" test_deploy_009

test_deploy_010() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file ".env.development"
  git -C "$WORK" commit -qm "add .env.development"
  if push_repo main >/dev/null; then pb_fail "expected push to be rejected"; return 1; fi
}
register "DEPLOY-010" "blocks .env.development" test_deploy_010

test_deploy_011() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file ".env.production"
  git -C "$WORK" commit -qm "add .env.production"
  if push_repo main >/dev/null; then pb_fail "expected push to be rejected"; return 1; fi
}
register "DEPLOY-011" "blocks .env.production" test_deploy_011

test_deploy_012() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file "backend/.env.production"
  git -C "$WORK" commit -qm "add nested .env.production"
  if push_repo main >/dev/null; then pb_fail "expected push to be rejected"; return 1; fi
}
register "DEPLOY-012" "blocks nested .env.production" test_deploy_012

test_deploy_013() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file "ok.txt"
  git -C "$WORK" commit -qm "base"
  push_repo main >/dev/null
  git -C "$WORK" checkout -q -b feature
  add_file ".env"
  git -C "$WORK" commit -qm "bad .env on feature"
  if push_repo feature >/dev/null; then pb_fail "expected feature push with .env to be rejected"; return 1; fi
}
register "DEPLOY-013" "blocks .env outside main" test_deploy_013

test_deploy_014() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file "ok.txt"
  git -C "$WORK" commit -qm "base"
  push_repo main >/dev/null
  if git -C "$WORK" push deploy :main >/dev/null 2>&1; then pb_fail "expected main deletion to be rejected"; return 1; fi
}
register "DEPLOY-014" "main cannot be removed" test_deploy_014

test_deploy_015() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file "ok.txt"
  git -C "$WORK" commit -qm "base"
  git -C "$WORK" checkout -q -b feature
  add_file "feature.txt"
  git -C "$WORK" commit -qm "feature work"
  push_repo feature >/dev/null
}
register "DEPLOY-015" "normal feature is allowed" test_deploy_015

# --- post-receive deploy behavior ---

prep_prod_app() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file "compose.yaml"
  add_file "compose.prod.yaml"
  git -C "$WORK" commit -qm "compose files"
}

test_deploy_016() {
  local root="$1"
  prep_prod_app "$root"
  git -C "$WORK" checkout -q -b feature
  add_file "feature.txt"
  git -C "$WORK" commit -qm "feature"
  push_repo feature >/dev/null
  assert_not_contains " up " "$root/docker.log"
}
register "DEPLOY-016" "feature does not trigger deploy" test_deploy_016

test_deploy_017() {
  local root="$1"
  prep_prod_app "$root"
  mkdir -p "$APPD"
  printf 'K=1\n' > "$APPD/.env.production"
  push_repo main >/dev/null
  assert_contains " up " "$root/docker.log"
}
register "DEPLOY-017" "main triggers deploy" test_deploy_017

test_deploy_018() {
  local root="$1"
  prep_prod_app "$root"
  mkdir -p "$APPD"
  printf 'LOCALSECRET=keepme\n' > "$APPD/.env.production"
  push_repo main >/dev/null
  assert_contains "LOCALSECRET=keepme" "$APPD/.env.production"
}
register "DEPLOY-018" "local .env.production is preserved" test_deploy_018

test_deploy_019() {
  local root="$1"
  prep_prod_app "$root"
  local out
  out="$(push_repo main)"
  assert_not_contains " up " "$root/docker.log"
  printf '%s' "$out" | grep -qF ".env.production" || { pb_fail "expected .env.production error"; return 1; }
}
register "DEPLOY-019" "missing .env.production fails before docker" test_deploy_019

test_deploy_020() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file "compose.prod.yaml"
  git -C "$WORK" commit -qm "only prod override"
  mkdir -p "$APPD"
  printf 'K=1\n' > "$APPD/.env.production"
  push_repo main >/dev/null
  assert_not_contains " up " "$root/docker.log"
}
register "DEPLOY-020" "missing compose.yaml fails before docker" test_deploy_020

test_deploy_021() {
  local root="$1"
  deploy_prepare "$root" demo demo
  make_work "$root" demo-work
  add_file "compose.yaml"
  git -C "$WORK" commit -qm "only base"
  mkdir -p "$APPD"
  printf 'K=1\n' > "$APPD/.env.production"
  push_repo main >/dev/null
  assert_not_contains " up " "$root/docker.log"
}
register "DEPLOY-021" "missing compose.prod.yaml fails before docker" test_deploy_021

test_deploy_022() {
  local root="$1"
  prep_prod_app "$root"
  mkdir -p "$APPD"
  printf 'K=1\n' > "$APPD/.env.production"
  push_repo main >/dev/null
  local ci ui
  ci="$(grep -n ' config ' "$root/docker.log" | head -1 | cut -d: -f1)"
  ui="$(grep -n ' up ' "$root/docker.log" | head -1 | cut -d: -f1)"
  [ -n "$ci" ] && [ -n "$ui" ] || { pb_fail "config or up missing"; return 1; }
  [ "$ci" -lt "$ui" ] || { pb_fail "expected config before up"; return 1; }
}
register "DEPLOY-022" "compose config runs before up" test_deploy_022

test_deploy_023() {
  local root="$1"
  prep_prod_app "$root"
  mkdir -p "$APPD"
  printf 'K=1\n' > "$APPD/.env.production"
  export PB_FAKE_DOCKER_CONFIG_FAIL=1
  push_repo main >/dev/null
  assert_not_contains " up " "$root/docker.log"
}
register "DEPLOY-023" "config failure prevents up" test_deploy_023

test_deploy_024() {
  local root="$1"
  prep_prod_app "$root"
  mkdir -p "$APPD"
  printf 'K=1\n' > "$APPD/.env.production"
  push_repo main >/dev/null
  assert_contains "up -d --build --remove-orphans --wait --wait-timeout 120" "$root/docker.log"
}
register "DEPLOY-024" "up contains --remove-orphans" test_deploy_024

test_deploy_025() {
  local root="$1"
  prep_prod_app "$root"
  mkdir -p "$APPD"
  printf 'K=1\n' > "$APPD/.env.production"
  push_repo main >/dev/null
  assert_contains "--wait" "$root/docker.log"
}
register "DEPLOY-025" "up contains --wait" test_deploy_025

test_deploy_026() {
  local root="$1"
  prep_prod_app "$root"
  mkdir -p "$APPD"
  printf 'K=1\n' > "$APPD/.env.production"
  push_repo main >/dev/null
  assert_contains "--wait-timeout 120" "$root/docker.log"
}
register "DEPLOY-026" "wait-timeout is 120" test_deploy_026

test_deploy_027() {
  local root="$1"
  deploy_prepare "$root" demo demo
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$root/proj" >/dev/null 2>&1
  assert_eq "refs/heads/main" "$(git --git-dir="$BARE" symbolic-ref HEAD)"
  assert_file_exists "$HOOKD/post-receive"
}
register "DEPLOY-027" "second install is idempotent" test_deploy_027

test_deploy_028() {
  local root="$1"
  prep_prod_app "$root"
  mkdir -p "$APPD"
  printf 'K=1\n' > "$APPD/.env.production"
  push_repo main >/dev/null
  local rev_before
  rev_before="$(git --git-dir="$BARE" rev-parse refs/heads/main)"
  "$PB_PROJECT_ROOT/scripts/setup_git_deploy.sh" --project-dir "$root/proj" >/dev/null 2>&1
  assert_eq "$rev_before" "$(git --git-dir="$BARE" rev-parse refs/heads/main)"
}
register "DEPLOY-028" "existing bare is not destroyed" test_deploy_028

test_deploy_029() {
  local root="$1"
  deploy_prepare "$root" demo demo
  mkdir -p "$BARE/hooks"
  cat > "$BARE/hooks/pre-receive" <<'EOF'
#!/usr/bin/env bash
echo "STALE HOOK" >&2
exit 1
EOF
  chmod +x "$BARE/hooks/pre-receive"
  assert_eq "$HOOKD" "$(git --git-dir="$BARE" rev-parse --git-path hooks)"
  make_work "$root" demo-work
  add_file "ok.txt"
  git -C "$WORK" commit -qm "valid commit"
  push_repo main >/dev/null
}
register "DEPLOY-029" "effective hooks path is central, not <bare>/hooks" test_deploy_029
