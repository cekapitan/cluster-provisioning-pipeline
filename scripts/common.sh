#!/usr/bin/env bash
# Shared helpers for local provisioning scripts.
set -euo pipefail

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y) return 0 ;;
    *) return 1 ;;
  esac
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

# Prefer SECRETS_DIR (Vault Agent / CSI mount). Fall back to empty for dry-run.
SECRETS_DIR="${SECRETS_DIR:-/secrets}"
SSH_PRIVATE_KEY_FILE="${SSH_PRIVATE_KEY_FILE:-${SECRETS_DIR}/ssh-private-key}"
WORK_DIR="${WORK_DIR:-/work}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${WORK_DIR}/artifacts}"
