#!/usr/bin/env bash
# End-to-end local provision: Kubespray then Longhorn.
# Runs in a single workflow pod so /work is shared across stages.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

export CLUSTER_NAME="${CLUSTER_NAME:-}"
export NODE_IPS="${NODE_IPS:-}"
export SSH_USER="${SSH_USER:-ubuntu}"
export KUBESPRAY_VERSION="${KUBESPRAY_VERSION:-v2.26.0}"
export LONGHORN_VERSION="${LONGHORN_VERSION:-1.7.2}"
export DRY_RUN="${DRY_RUN:-true}"
export WORK_DIR="${WORK_DIR:-/work}"
export ARTIFACTS_DIR="${ARTIFACTS_DIR:-${WORK_DIR}/artifacts}"
export INVENTORY_DIR="${INVENTORY_DIR:-${WORK_DIR}/inventory/${CLUSTER_NAME}}"
export SECRETS_DIR="${SECRETS_DIR:-/secrets}"

mkdir -p "${ARTIFACTS_DIR}"

log "=== validate-request ==="
"${SCRIPT_DIR}/validate-request.sh"

log "=== prepare-inventory ==="
"${SCRIPT_DIR}/prepare-inventory.sh"

log "=== run-kubespray ==="
"${SCRIPT_DIR}/run-kubespray.sh"

log "=== install-longhorn ==="
"${SCRIPT_DIR}/install-longhorn.sh"

log "=== wait-cluster-ready ==="
"${SCRIPT_DIR}/wait-cluster-ready.sh"

log "local provisioning finished for ${CLUSTER_NAME}"
cat "${ARTIFACTS_DIR}/status.json"
