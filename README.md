# project-bootstrap

Reproduces, in a safe, idempotent and professional way, the Development /
Production / GitHub SSH / Git bare deploy architecture validated in the FAIR
project. It does not touch FAIR, Core ERP, IPMS or any real homelab.

The core principle is that the *orchestrator* chooses the environment. No
implicit `.env` dependency exists: applications never need to discover whether
they are running in development or production.

## The four public scripts

| Script | Machine | What it does |
| --- | --- | --- |
| `scripts/setup_dev.sh` | Development Host | creates `.env.development`, runs `compose.yaml + compose.dev.yaml` |
| `scripts/setup_prod.sh` | Production Host | creates `.env.production`, runs `compose.yaml + compose.prod.yaml` |
| `scripts/setup_git_remote.sh` | Development Host | configures GitHub SSH + remote `origin` (the only interactive one) |
| `scripts/setup_git_deploy.sh` | Production Host | bare repo + centralized hooks + `core.hooksPath` |

Each script keeps a single responsibility; there is no monolithic setup script.

## Command line

```
project-bootstrap dev
project-bootstrap prod
project-bootstrap git-remote
project-bootstrap git-deploy
project-bootstrap doctor
project-bootstrap version
```

The CLI delegates to the scripts above. See `SETUP.md` for the operational
workflow and `install/` for the installers.

## Installing via curl

`curl` installs the **tool** (the `project-bootstrap` command). It does **not**
configure a project automatically.

Development Host (user-space, no root):

```sh
curl -fsSL \
  https://raw.githubusercontent.com/eduardomoschen/script-sh-model/v0.2.0/install/bootstrap-dev.sh \
  | bash
```

Production Host (inspect first, then run privileged):

```sh
curl -fsSL \
  https://raw.githubusercontent.com/eduardomoschen/script-sh-model/v0.2.0/install/bootstrap-prod.sh \
  -o /tmp/project-bootstrap-install.sh

less /tmp/project-bootstrap-install.sh
sudo bash /tmp/project-bootstrap-install.sh
```

The `bootstrap-*.sh` scripts are standalone remote entrypoints: they download a
versioned release (`PROJECT_BOOTSTRAP_REPOSITORY` / `PROJECT_BOOTSTRAP_VERSION`,
overridable by environment) and delegate to the source's own `install/install-*.sh`.
After installing, configure a project with:

```sh
project-bootstrap dev
project-bootstrap git-remote
```

or:

```sh
project-bootstrap prod
sudo project-bootstrap git-deploy
```

## Tests

```
./tests/harness.sh fast                 # run the full fast suite
./tests/harness.sh fast --only DEV-010  # run a single test
HARNESS_VERBOSE=1 ./tests/harness.sh fast --only DEV-010
```

Fast tests use real Git and fake `docker`/`ssh`/`ssh-keygen`/`curl` binaries in a
temporary directory. They never touch real Docker, GitHub, the network, sudo or
`/etc`.
