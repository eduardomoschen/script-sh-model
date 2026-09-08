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

## Tests

```
./tests/harness.sh fast                 # run the full fast suite
./tests/harness.sh fast --only DEV-010  # run a single test
HARNESS_VERBOSE=1 ./tests/harness.sh fast --only DEV-010
```

Fast tests use real Git and fake `docker`/`ssh`/`ssh-keygen`/`curl` binaries in a
temporary directory. They never touch real Docker, GitHub, the network, sudo or
`/etc`.
