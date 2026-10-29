#!/usr/bin/env bash
# Install Longhorn as the local-cluster storage backend (post-Kubespray).
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

CLUSTER_NAME="${CLUSTER_NAME:-}"
LONGHORN_VERSION="${LONGHORN_VERSION:-1.7.2}"
LONGHORN_NAMESPACE="${LONGHORN_NAMESPACE:-longhorn-system}"
DRY_RUN="${DRY_RUN:-true}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${ARTIFACTS_DIR}/kubeconfig}"

[[ -n "${CLUSTER_NAME}" ]] || die "CLUSTER_NAME is required"

helm_cmd=(
  helm upgrade --install longhorn longhorn/longhorn
  --namespace "${LONGHORN_NAMESPACE}"
  --create-namespace
  --version "${LONGHORN_VERSION}"
  --set persistence.defaultClass=true
  --set persistence.defaultClassReplicaCount=3
  --wait
)

if truthy "${DRY_RUN}"; then
  log "DRY_RUN=true — skipping Longhorn install"
  log "would run: ${helm_cmd[*]}"
  mkdir -p "${ARTIFACTS_DIR}"
  cat > "${ARTIFACTS_DIR}/longhorn-plan.txt" <<EOF
dry_run: true
cluster: ${CLUSTER_NAME}
longhorn_version: ${LONGHORN_VERSION}
namespace: ${LONGHORN_NAMESPACE}
command: ${helm_cmd[*]}
EOF
  exit 0
fi

[[ -f "${KUBECONFIG_PATH}" ]] || die "kubeconfig not found at ${KUBECONFIG_PATH}"
export KUBECONFIG="${KUBECONFIG_PATH}"

require_cmd helm
require_cmd kubectl

log "adding Longhorn helm repo"
helm repo add longhorn https://charts.longhorn.io >/dev/null
helm repo update longhorn >/dev/null

log "installing Longhorn ${LONGHORN_VERSION} into ${LONGHORN_NAMESPACE}"
"${helm_cmd[@]}"

kubectl -n "${LONGHORN_NAMESPACE}" wait --for=condition=available deploy/longhorn-driver-deployer --timeout=300s || true
log "Longhorn install requested for local cluster ${CLUSTER_NAME}"
