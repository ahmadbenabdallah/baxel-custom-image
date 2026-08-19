# Hermes Agent — Blaxel Sandbox Image

<p>
  <img src="https://img.shields.io/badge/Alpine-3.21-0D597F?style=for-the-badge&logo=alpinelinux&logoColor=white" alt="Alpine Linux 3.24" />
  <img src="https://img.shields.io/badge/Docker-ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
  <img src="https://img.shields.io/badge/Node.js-22.x-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js 22" />
  <img src="https://img.shields.io/badge/Python-3.11%20%2F%203.12-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python 3.11 / 3.12" />
  <img src="https://img.shields.io/badge/Blaxel-sandbox-6C5CE7?style=for-the-badge&logo=cloudsmith&logoColor=white" alt="Blaxel Sandbox" />
</p>

<p>
  <img src="https://img.shields.io/github/actions/workflow/status/ahmadbenabdallah/baxel-custom-image/docker-build-scan.yml?branch=main&style=flat-square&label=build" alt="Build status" />
  <img src="https://img.shields.io/badge/dependabot-enabled-025E8C?style=flat-square&logo=dependabot&logoColor=white" alt="Dependabot enabled" />
  <img src="https://img.shields.io/badge/scanned%20with-Trivy-1904DA?style=flat-square&logo=aquasecurity&logoColor=white" alt="Scanned with Trivy" />
  <img src="https://img.shields.io/badge/lint-hadolint-blue?style=flat-square" alt="Hadolint" />
  <img src="https://img.shields.io/github/license/OWNER/REPO?style=flat-square" alt="License" />
</p>


A production-ready [Blaxel](https://www.blaxel.ai) sandbox image that ships [Hermes Agent](https://hermes-agent.nousresearch.com) (Nous Research) pre-installed on Alpine Linux, with the full native-module toolchain it needs to build cleanly on first boot — no dependency surprises at runtime.

Built and hardened through iterative debugging of the real installer failure modes on musl/Alpine (glibc mismatches, missing compiler toolchain, Python path resolution), so sandboxes spun up from this image work the first time.

---

## Table of contents

- [Overview](#overview)
- [Technology stack](#technology-stack)
- [Repository structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Local build & test](#local-build--test)
- [Deploying to Blaxel](#deploying-to-blaxel)
- [Running Hermes inside a sandbox](#running-hermes-inside-a-sandbox)
- [Configuration](#configuration)
- [CI/CD & security](#cicd--security)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Overview

[Hermes Agent](https://hermes-agent.nousresearch.com) is an open-source AI agent from Nous Research. Its official installer assumes a glibc-based Linux distribution with Node.js, Python, and a C/C++ toolchain already present — none of which hold true on a bare Alpine container, which is what most [Blaxel sandbox](https://docs.blaxel.ai/Sandboxes/Overview) base images use for fast cold starts.

This repo packages the exact dependency set required to make the installer succeed cleanly on Alpine, wraps it in a [Blaxel-compatible](https://docs.blaxel.ai/Sandboxes/Templates) Dockerfile (with the required `sandbox-api` binary and entrypoint), and adds CI to keep the resulting image patched and verifiably free of known critical/high vulnerabilities.

**Use this if you want to:**
- Spin up disposable, isolated Hermes Agent instances on demand (e.g. as workers in a multi-agent orchestration pipeline)
- Avoid re-debugging the same Alpine/musl dependency issues every time you provision a new sandbox
- Have a repeatable, scanned, version-controlled base image rather than a hand-patched container

---

## Technology stack

| Layer | Technology | Notes |
|---|---|---|
| Base OS | Alpine Linux 3.21 | Pinned by digest, not tag — see [Security](#cicd--security) |
| Sandbox runtime | [Blaxel sandbox-api](https://docs.blaxel.ai) | Injected via `COPY --from=ghcr.io/blaxel-ai/sandbox:latest` |
| Agent runtime | [Hermes Agent](https://hermes-agent.nousresearch.com) (Nous Research) | Installed via official installer script |
| Python | 3.11 (via [`uv`](https://github.com/astral-sh/uv), isolated venv) + system Python 3.12 | Hermes runs in its own `uv`-managed venv, separate from system Python |
| Node.js | 22.x (Alpine musl-native package, not Hermes's bundled glibc build) | Required for Hermes's browser tooling (Playwright, node-pty) |
| Native build toolchain | `build-base`, `gcc`, `g++`, `make`, `linux-headers` | Required for `node-gyp` to compile `node-pty` from source (no musl prebuilt exists) |
| Browser automation | Playwright (Chromium) | Installed by the Hermes installer; Alpine has no auto-deps support, handled manually if needed |
| CI | GitHub Actions | Build, lint, scan on every push/PR + weekly scheduled scan |
| Linting | [Hadolint](https://github.com/hadolint/hadolint) | Dockerfile best-practices linting |
| Vulnerability scanning | [Trivy](https://github.com/aquasecurity/trivy) | Scans the *built* image, not just the Dockerfile |
| Secret scanning | [Gitleaks](https://github.com/gitleaks/gitleaks) + GitHub push protection | Repo-level, not just image-level |
| Dependency updates | [Dependabot](https://docs.github.com/en/code-security/dependabot) | `docker` + `github-actions` ecosystems |

---

## Repository structure

```
hermes-blaxel/
├── Dockerfile                          # Image definition (Alpine + toolchain + Hermes)
├── entrypoint.sh                       # Starts sandbox-api, optionally launches Hermes
├── blaxel.toml                         # Blaxel runtime config (memory, ports, env)
├── Makefile                            # Local build/run/push/deploy shortcuts
├── .gitignore                          # Excludes secrets, Hermes runtime data
├── SECURITY.md                         # Supply-chain trust notes, what CI does/doesn't cover
├── README.md                           # This file
└── .github/
    ├── dependabot.yml                  # Weekly base-image + Actions update checks
    └── workflows/
        └── docker-build-scan.yml       # Hadolint + build + Trivy + Gitleaks on every push
```

---

## Prerequisites

| Tool | Required for | Install |
|---|---|---|
| Docker | Local build/test | [docker.com](https://docs.docker.com/get-docker/) |
| [Blaxel CLI](https://docs.blaxel.ai) (`bl`) | Pushing/deploying to Blaxel | See [Deploying to Blaxel](#deploying-to-blaxel) |
| A Blaxel account + workspace | Pushing/deploying to Blaxel | [app.blaxel.ai](https://app.blaxel.ai) |

Local build/test requires **no** Blaxel account — only `bl push`/`bl deploy` do.

---

## Quick start

```sh
git clone <this-repo-url>
cd hermes-blaxel

# Build and run locally first (recommended before pushing to Blaxel)
make build
make run

# Once you're ready to ship it to Blaxel
bl login YOUR-WORKSPACE
bl deploy
```

---

## Local build & test

Test the full image build on your own machine before spending a remote Blaxel build cycle on it — this is where you'll catch dependency issues fastest.

```sh
make build          # docker build -t hermes-agent-sandbox .
make run            # docker run --rm -it -p 8080:8080 -p 8000:8000 hermes-agent-sandbox
```

Once running, confirm the sandbox API responded:

```sh
curl http://127.0.0.1:8080/process
```

---

## Deploying to Blaxel

### 1. Install the Blaxel CLI

```sh
curl -fsSL https://raw.githubusercontent.com/blaxel-ai/toolkit/main/install.sh | BINDIR=/usr/local/bin sudo -E sh
bl --version
```

### 2. Authenticate

```sh
bl login YOUR-WORKSPACE
```

Your workspace name is visible in the URL when logged into `app.blaxel.ai/{workspace}`. If prompted for an API key, generate one at `app.blaxel.ai/profile/security`.

### 3. Push (build image only) or deploy (build + spin up a live sandbox)

```sh
bl push      # builds and stores the image in your workspace registry
# — or —
bl deploy    # same, plus creates a first live sandbox from it
```

### 4. Monitor the build

```sh
bl get sandbox hermes-agent --watch
```

Status progresses `UPLOADING → BUILDING → DEPLOYING → DEPLOYED`. On `FAILED`:

```sh
bl logs sandbox hermes-agent
```

### 5. Spawn additional sandboxes from the pushed image

```sh
bl get image sandbox/hermes-agent --latest
```

```python
from blaxel.core import SandboxInstance

sandbox = await SandboxInstance.create({
    "name": "hermes-worker-1",
    "image": "IMAGE_ID",
    "memory": 4096,
    "region": "us-pdx-1",
})
```

---

## Running Hermes inside a sandbox

By design, `entrypoint.sh` does **not** auto-launch Hermes on sandbox boot — it only starts the required `sandbox-api`. This keeps sandboxes idle and controllable rather than free-running an agent process the moment they come up, which matters if you're driving Hermes from an external orchestrator with human approval gates.

Launch Hermes on demand via the sandbox API:

```sh
curl http://127.0.0.1:8080/process -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "workingDir": "/usr/local/lib/hermes-agent",
    "command": "./venv/bin/python run_agent.py",
    "waitForCompletion": false
  }'
```

> **Important:** always call `./venv/bin/python`, not system `python`. Hermes installs its dependencies (`pyyaml`, etc.) into its own `uv`-managed virtual environment at `/usr/local/lib/hermes-agent/venv`, separate from the system Python on the image.

Alternatively, use the `hermes` launcher already on `PATH` (installed by Hermes's own installer, handles venv activation automatically):

```sh
curl http://127.0.0.1:8080/process -X POST \
  -H "Content-Type: application/json" \
  -d '{"workingDir": "/usr/local/lib/hermes-agent", "command": "hermes", "waitForCompletion": false}'
```

To have Hermes start automatically on every sandbox boot instead, uncomment the relevant block at the bottom of `entrypoint.sh`.

---

## Configuration

### `blaxel.toml`

Controls sandbox memory, exposed ports, and environment variables at the Blaxel platform level.

```toml
[runtime]
memory = 4096              # bump to 8192 for heavier multi-agent workloads

[[runtime.ports]]
name = "hermes-api"
target = 8000
```

> Environment variables cannot be added or changed after a sandbox is created — set everything needed in `blaxel.toml`, the `Dockerfile`, or at creation time via the SDK.

### Hermes's own configuration

Generated on first install inside the image at:

- `~/.hermes/config.yaml` — main config
- `~/.hermes/.env` — API keys (never commit this — see `.gitignore`)
- `~/.hermes/SOUL.md` — agent personality/behavior customization

---

## CI/CD & security

Every push and PR to `main` runs:

1. **Hadolint** — Dockerfile linting
2. **Docker build** — full image build, cached via GitHub Actions cache
3. **Trivy** — scans the built image; fails on unresolved CRITICAL/HIGH CVEs
4. **Gitleaks** — scans the repo for accidentally committed secrets

A scheduled weekly run also re-scans the image even with no code changes, since newly disclosed CVEs in already-baked packages won't otherwise surface.

**Dependabot** opens weekly PRs for Alpine base image tag updates and GitHub Actions version bumps.

Both `FROM` lines in the Dockerfile are pinned by **digest**, not just tag — this closes the gap where a maintainer republishes different bytes under the same tag without Dependabot noticing. See [`SECURITY.md`](./SECURITY.md) for the full threat model, including the one thing none of this tooling covers: the third-party `curl | bash` Hermes installer itself.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `cannot execute: required file not found` on Node | glibc/musl mismatch — Hermes's bundled Node build is glibc-only | Use Alpine's native `apk add nodejs npm` (already done in this Dockerfile) |
| `npm error enoent ... package.json` | Ran `npm install` from the wrong directory | Run from `/usr/local/lib/hermes-agent`, where the real `package.json` lives |
| `node-gyp` fails with `Could not find any Python installation` | No system `python3` on `PATH` for node-gyp to shell out to | Ensure `python3` is installed via `apk` (already done here) |
| `ModuleNotFoundError: No module named 'yaml'` running `run_agent.py` | Called system `python` instead of Hermes's venv Python | Use `./venv/bin/python run_agent.py`, not bare `python` |
| `glibc (no such package)` from `apk add glibc` | Full glibc isn't in Alpine's standard repos | Not needed — use musl-native `nodejs`/`npm` instead (see above) |

---

## Contributing

Issues and PRs welcome. If you're proposing a Dockerfile change, please:

1. Run `make build` locally first — CI will re-verify, but faster local iteration saves everyone's build minutes.
2. Keep new packages justified with a comment explaining *why* they're needed (see the existing `Dockerfile` for the pattern).
3. Re-pin any changed base image by digest, not just tag.
