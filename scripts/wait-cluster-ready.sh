#!/usr/bin/env bash
# Confirm local cluster API and Longhorn StorageClass are ready.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

CLUSTER_NAME="${CLUSTER_NAME:-}"
DRY_RUN="${DRY_RUN:-true}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${ARTIFACTS_DIR}/kubeconfig}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"

[[ -n "${CLUSTER_NAME}" ]] || die "CLUSTER_NAME is required"
mkdir -p "${ARTIFACTS_DIR}"

if truthy "${DRY_RUN}"; then
  log "DRY_RUN=true — synthesizing ready status for ${CLUSTER_NAME}"
  cat > "${ARTIFACTS_DIR}/status.json" <<EOF
{
  "cluster_name": "${CLUSTER_NAME}",
  "environment": "local",
  "provisioner": "kubespray",
  "storage_backend": "longhorn",
  "phase": "Succeeded",
  "dry_run": true
}
EOF
  exit 0
fi

[[ -f "${KUBECONFIG_PATH}" ]] || die "kubeconfig not found at ${KUBECONFIG_PATH}"
export KUBECONFIG="${KUBECONFIG_PATH}"
require_cmd kubectl

log "waiting for nodes to become Ready"
end=$((SECONDS + TIMEOUT_SECONDS))
until kubectl get nodes --no-headers 2>/dev/null | grep -qv NotReady; do
  [[ "${SECONDS}" -lt "${end}" ]] || die "timed out waiting for Ready nodes"
  sleep 5
done

log "waiting for Longhorn StorageClass"
end=$((SECONDS + TIMEOUT_SECONDS))
until kubectl get storageclass longhorn >/dev/null 2>&1; do
  [[ "${SECONDS}" -lt "${end}" ]] || die "timed out waiting for StorageClass/longhorn"
  sleep 5
done

cat > "${ARTIFACTS_DIR}/status.json" <<EOF
{
  "cluster_name": "${CLUSTER_NAME}",
  "environment": "local",
  "provisioner": "kubespray",
  "storage_backend": "longhorn",
  "phase": "Succeeded",
  "dry_run": false
}
EOF
log "local cluster ${CLUSTER_NAME} is ready (Kubespray + Longhorn)"
