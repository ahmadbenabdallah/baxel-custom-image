# Hermes Agent — custom Blaxel sandbox image
# Dependency set validated by hand on a bare Alpine 3.21 container before
# baking into this template (see notes below for why each package is here).

FROM alpine:3.21

# --- Blaxel sandbox API (REQUIRED) ------------------------------------------
# Every Blaxel sandbox image must include this binary — it's what gives you
# process management, file operations, and the /process HTTP API that the
# entrypoint below calls into. Without it the sandbox never becomes usable.
COPY --from=ghcr.io/blaxel-ai/sandbox:latest /sandbox-api /usr/local/bin/sandbox-api

# --- System packages ---------------------------------------------------------
# nodejs/npm    : Alpine's musl-native build. Hermes's installer bundles its
#                 own managed Node 26, but that's a glibc build and fails on
#                 musl with "cannot execute: required file not found".
# python3       : must resolve as `python3` on PATH — node-gyp shells out
#                 looking for a *system* python, separate from the uv-managed
#                 Python Hermes installs for itself into its own venv.
# build-base,
# gcc, g++, make,
# linux-headers : node-gyp needs a real C/C++ toolchain to compile native
#                 modules from source. node-pty (used for Hermes's terminal
#                 tooling) has no prebuilt binary for linux-x64-musl, so this
#                 is not optional — npm install fails without it.
# git           : required to clone the hermes-agent repo during install.
# ca-certificates: avoids TLS trust-store gaps that manifest as silent
#                 timeouts rather than clear cert errors.
# ripgrep, ffmpeg: installer warns and degrades (grep fallback / no TTS)
#                 without these — cheap to include upfront.
# openssh-client : installer tries SSH clone before falling back to HTTPS.
# bash, curl    : installer requires bash; curl fetches the install script.
RUN apk add --no-cache \
    bash \
    curl \
    git \
    ca-certificates \
    python3 \
    py3-pip \
    nodejs \
    npm \
    build-base \
    gcc \
    g++ \
    make \
    linux-headers \
    ripgrep \
    ffmpeg \
    openssh-client \
    netcat-openbsd

# Fail the build fast if any of the above didn't land correctly
RUN node -v && npm -v && python3 -V && git --version

# --- Hermes Agent install ----------------------------------------------------
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

# Explicitly re-run the Node.js dependency install from the correct directory.
# The installer's own attempt runs from the wrong cwd in some environments
# and silently no-ops; doing it here as a separate layer means a broken
# native-module compile fails the image build loudly instead of shipping
# a sandbox with half-installed browser tools.
WORKDIR /usr/local/lib/hermes-agent
RUN npm install

# Sanity check the full stack (Python + Node) resolves before shipping.
# Must use the venv's own Python — Hermes installs its deps (pyyaml, etc.)
# into /usr/local/lib/hermes-agent/venv via uv, not into system python.
RUN ./venv/bin/python run_agent.py --help

# --- Entrypoint ---------------------------------------------------------------
WORKDIR /root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
