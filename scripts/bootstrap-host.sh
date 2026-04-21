#!/usr/bin/env bash
# One-time setup on a fresh Hetzner Cloud VM (Ubuntu 22.04/24.04).
# Installs Docker, drops the compose file + .env template into
# $DEPLOY_DIR, and brings the stack up. Safe to re-run; each step is
# idempotent.
#
#   curl -fsSL https://raw.githubusercontent.com/AlexDickerson/foundry-character-creator/main/scripts/bootstrap-host.sh | sudo bash
#
# Or, if your images are private on GHCR:
#   export GITHUB_TOKEN=ghp_xxx
#   export GITHUB_USER=AlexDickerson
#   curl -fsSL .../bootstrap-host.sh | sudo -E bash

set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/foundry-stack}"
GITHUB_USER="${GITHUB_USER:-AlexDickerson}"
COMPOSE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/foundry-character-creator/main/docker-compose.yml"
ENV_URL="https://raw.githubusercontent.com/${GITHUB_USER}/foundry-character-creator/main/.env.example"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# 1) Docker ------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log "installing docker"
  curl -fsSL https://get.docker.com | sh
else
  log "docker already installed: $(docker --version)"
fi

# Add the invoking user to the docker group if we're running under sudo.
# Lets them run `docker compose` without sudo after a fresh login.
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  usermod -aG docker "${SUDO_USER}"
fi

# 2) Deploy dir --------------------------------------------------------------
log "preparing ${DEPLOY_DIR}"
mkdir -p "${DEPLOY_DIR}"
cd "${DEPLOY_DIR}"

# 3) Compose + env -----------------------------------------------------------
log "fetching docker-compose.yml"
curl -fsSL "${COMPOSE_URL}" -o docker-compose.yml

if [[ ! -f .env ]]; then
  log "creating .env from template — EDIT THIS BEFORE STARTING"
  curl -fsSL "${ENV_URL}" -o .env
  chmod 600 .env
else
  log ".env already exists, leaving it alone"
fi

# 4) GHCR login (only needed if any of the three images are private) --------
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  log "logging into ghcr.io as ${GITHUB_USER}"
  echo "${GITHUB_TOKEN}" | docker login ghcr.io -u "${GITHUB_USER}" --password-stdin
else
  log "skipping ghcr.io login (GITHUB_TOKEN not set — fine for public images)"
fi

# 5) Pull + start ------------------------------------------------------------
# Skip `up` on first run if .env still has blank FOUNDRY credentials —
# starting would just crash-loop foundry waiting for them.
if grep -qE '^FOUNDRY_USERNAME=\s*$' .env; then
  log "FOUNDRY_USERNAME is empty in .env — edit ${DEPLOY_DIR}/.env then run:"
  echo "    cd ${DEPLOY_DIR} && docker compose up -d"
  exit 0
fi

log "pulling images"
docker compose pull

log "starting stack"
docker compose up -d

log "done. stack listening on :$(awk -F= '/^WEB_PORT=/ {print $2}' .env | tr -d ' ' || echo 8080)"
docker compose ps
