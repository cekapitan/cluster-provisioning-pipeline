#!/usr/bin/env bash
# Run Kubespray cluster.yml against the prepared local inventory.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

CLUSTER_NAME="${CLUSTER_NAME:-}"
KUBESPRAY_VERSION="${KUBESPRAY_VERSION:-v2.26.0}"
DRY_RUN="${DRY_RUN:-true}"
INVENTORY_DIR="${INVENTORY_DIR:-${WORK_DIR}/inventory/${CLUSTER_NAME}}"
KUBESPRAY_DIR="${KUBESPRAY_DIR:-${WORK_DIR}/kubespray}"

[[ -n "${CLUSTER_NAME}" ]] || die "CLUSTER_NAME is required"
[[ -f "${INVENTORY_DIR}/hosts.yaml" ]] || die "inventory not found at ${INVENTORY_DIR}/hosts.yaml"

playbook_cmd=(
  ansible-playbook
  -i "${INVENTORY_DIR}/hosts.yaml"
  --become
  --become-user=root
  cluster.yml
)

if truthy "${DRY_RUN}"; then
  log "DRY_RUN=true — skipping Kubespray execution"
  log "would clone kubespray@${KUBESPRAY_VERSION} into ${KUBESPRAY_DIR}"
  log "would run: ${playbook_cmd[*]}"
  mkdir -p "${ARTIFACTS_DIR}"
  cat > "${ARTIFACTS_DIR}/kubespray-plan.txt" <<EOF
dry_run: true
kubespray_version: ${KUBESPRAY_VERSION}
inventory: ${INVENTORY_DIR}/hosts.yaml
command: ${playbook_cmd[*]}
EOF
  exit 0
fi

[[ -f "${SSH_PRIVATE_KEY_FILE}" ]] || die "SSH private key not found at ${SSH_PRIVATE_KEY_FILE} (mount via Secret/Vault)"
chmod 600 "${SSH_PRIVATE_KEY_FILE}"
export SSH_PRIVATE_KEY_FILE

require_cmd git
require_cmd ansible-playbook

if [[ ! -d "${KUBESPRAY_DIR}/.git" ]]; then
  log "cloning kubespray ${KUBESPRAY_VERSION}"
  git clone --depth 1 --branch "${KUBESPRAY_VERSION}" \
    https://github.com/kubernetes-sigs/kubespray.git "${KUBESPRAY_DIR}"
fi

cd "${KUBESPRAY_DIR}"
if [[ -f requirements.txt ]]; then
  require_cmd pip3
  pip3 install --quiet -r requirements.txt
fi

log "running Kubespray cluster.yml for ${CLUSTER_NAME}"
"${playbook_cmd[@]}"

# kubeconfig_localhost writes to inventory artifacts when configured
if [[ -f "${INVENTORY_DIR}/artifacts/admin.conf" ]]; then
  mkdir -p "${ARTIFACTS_DIR}"
  cp "${INVENTORY_DIR}/artifacts/admin.conf" "${ARTIFACTS_DIR}/kubeconfig"
  log "copied kubeconfig to ${ARTIFACTS_DIR}/kubeconfig"
elif [[ -f "${KUBESPRAY_DIR}/inventory/${CLUSTER_NAME}/artifacts/admin.conf" ]]; then
  mkdir -p "${ARTIFACTS_DIR}"
  cp "${KUBESPRAY_DIR}/inventory/${CLUSTER_NAME}/artifacts/admin.conf" "${ARTIFACTS_DIR}/kubeconfig"
fi

log "Kubespray finished for ${CLUSTER_NAME}"
