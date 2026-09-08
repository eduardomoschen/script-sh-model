# project-bootstrap — Operational Setup

This document describes how to bootstrap a project across the three machines of
the canonical topology:

- **Development Host** (working copies, e.g. a workstation)
- **GitHub** (central repository, remote `origin`)
- **Production Host** (homelab: bare repo + apps + Docker Compose)

The names `Ryzen` and `homelab` are examples used for readability; no personal
machine name is a requirement of the tool.

## Concepts

- **PROJECT_NAME** — name of the working repository (e.g. `vaccine-fair-api`).
- **DEPLOY_NAME** — name used for the deploy on the Production Host
  (e.g. `fair-principles-ic`). Defaults to `PROJECT_NAME` but must be kept as a
  distinct concept because they are not always equal.
- **`.project-bootstrap.conf`** — non-secret, versionable, per-project config
  with topology/behavior overrides only. Never put credentials in it.

## 1. Install the tool

Development Host:

```sh
./install/install-dev.sh
```

Production Host (inspect the script first, then run privileged):

```sh
curl -fsSL <url>/install-prod.sh -o /tmp/project-bootstrap-install-prod.sh
# inspect /tmp/project-bootstrap-install-prod.sh
sudo bash /tmp/project-bootstrap-install-prod.sh
```

Installing the tool and configuring a project are distinct operations.

## 2. Development Host

```sh
cd /path/to/your/project
project-bootstrap dev          # -> .env.development + compose.yaml + compose.dev.yaml
project-bootstrap git-remote   # -> GitHub SSH + origin (interactive)
```

`project-bootstrap dev`:

- infers `PROJECT_NAME` from the Git toplevel;
- creates `.project-bootstrap.conf` from the template if missing;
- creates `.env.development` (copies `.env.example` if present) without ever
  overwriting an existing one, then `chmod 600`;
- guarantees `.env`, `.env.*` and `!.env.example` are in `.gitignore`;
- validates `docker compose --env-file .env.development -f compose.yaml -f compose.dev.yaml config --quiet`
  and only then runs `up -d --build`.

`project-bootstrap git-remote` configures `origin` and validates it with
`git ls-remote origin`. It never creates a key per project: the key belongs to
the user/machine, and is only offered (ED25519) when SSH to GitHub fails and no
key exists yet.

## 3. GitHub (central repository)

Create the repository on GitHub and push:

```sh
git push origin main
```

## 4. Production Host

```sh
cd /path/to/checkout-or-config
project-bootstrap prod           # -> .env.production + compose.yaml + compose.prod.yaml
sudo project-bootstrap git-deploy  # -> bare repo + hooks (needs /etc write)
```

`project-bootstrap prod`:

- creates `.env.production` (copies `.env.example` if present), never
  overwriting, then `chmod 600`;
- validates the mandatory compose files exist;
- validates
  `docker compose --env-file .env.production -f compose.yaml -f compose.prod.yaml config --quiet`
  and only then runs
  `up -d --build --remove-orphans --wait --wait-timeout 120`.

`project-bootstrap git-deploy` creates:

```
HOMELAB_ROOT/
├── apps/<DEPLOY_NAME>/            # checkout target
└── repos/<DEPLOY_NAME>.git        # bare repository
```

and centralized hooks:

```
HOOKS_ROOT/<DEPLOY_NAME>.git/
├── pre-receive
└── post-receive
```

with the bare repo configured as:

```
core.hooksPath = HOOKS_ROOT/<DEPLOY_NAME>.git
```

The effective hooks path is validated with `git rev-parse --git-path hooks`
(this is how a stale hook still active in `<bare>/hooks` was discovered in
FAIR). A hook is never validated against `<bare>/hooks` while `core.hooksPath`
points elsewhere.

## 5. Push flow (daily use)

```sh
git push origin main       # GitHub receives the commit
git push production main   # homelab bare repo receives the commit
```

where `production` is a remote pointing at the bare repository, e.g.
`ssh://deploy@<homelab>/home/<deploy>/homelab/repos/<DEPLOY_NAME>.git`.

On the Production Host, the flow is:

```
push -> pre-receive validates -> post-receive checks out into apps/<DEPLOY_NAME>
     -> .env.production preserved -> Docker Compose validated -> stack updated
```

Production is never a substitute for GitHub.

## 6. Hooks contract

**pre-receive** allows files ending exactly in `.example`
(`.env.example`, `backend/.env.example`); blocks `.env*` secrets in any branch
(`.env`, `.env.development`, `.env.production`, `.env.local`, nested, etc.);
rejects deletion of `main`; chains `GLOBAL_PRE_RECEIVE` when configured and
executable (stdin preserved).

**post-receive** reacts only to `refs/heads/main`; rejects a removed main;
defends against versioned `.env*`; checks out into `APPS_ROOT/DEPLOY_NAME`;
requires a readable `.env.production`, `compose.yaml` and `compose.prod.yaml`;
runs `config --quiet` before `up`; and runs
`up -d --build --remove-orphans --wait --wait-timeout 120`.

## 7. First deployment (order matters)

1. `project-bootstrap git-deploy` (bare repo + hooks + app dir).
2. Create `.env.production` inside `apps/<DEPLOY_NAME>/` (via
   `project-bootstrap prod` in a checkout, or manually, mode `600`).
3. `git push production main`.

## 8. Idempotency

All four scripts and both installers are idempotent:

- existing `.env.development` / `.env.production` are never overwritten;
- `.gitignore` entries are only appended when missing;
- an existing bare repository is never destroyed;
- hooks are re-installed from templates, and `core.hooksPath` is re-validated.

## 9. Running the harness

```sh
./tests/harness.sh fast
./tests/harness.sh fast --only DEPLOY-014
HARNESS_VERBOSE=1 ./tests/harness.sh fast --only DEPLOY-014
```

The harness models two isolated machines under `/tmp/project-bootstrap-harness.*`
and proves no script writes to the wrong machine.
