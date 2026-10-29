#!/usr/bin/env bash
# Offline dry-run of local Kubespray + Longhorn scripts (no cluster / SSH).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

export WORK_DIR="${TMP}/work"
export ARTIFACTS_DIR="${WORK_DIR}/artifacts"
export CLUSTER_NAME="lab-test"
export NODE_IPS="10.0.0.10,10.0.0.11,10.0.0.12"
export SSH_USER="ubuntu"
export KUBESPRAY_VERSION="v2.26.0"
export LONGHORN_VERSION="1.7.2"
export DRY_RUN="true"
export INVENTORY_DIR="${WORK_DIR}/inventory/${CLUSTER_NAME}"

mkdir -p "${ARTIFACTS_DIR}"
chmod +x "${ROOT}/scripts/"*.sh

echo "test_local_scripts.sh"

"${ROOT}/scripts/provision-local.sh"
test -f "${ARTIFACTS_DIR}/request.json"
grep -q '"storage_backend": "longhorn"' "${ARTIFACTS_DIR}/request.json"
grep -q '"environment": "local"' "${ARTIFACTS_DIR}/request.json"
test -f "${INVENTORY_DIR}/hosts.yaml"
grep -q '10.0.0.10' "${INVENTORY_DIR}/hosts.yaml"
grep -q 'cloud_provider: null' "${INVENTORY_DIR}/group_vars/all/all.yml"
test -f "${ARTIFACTS_DIR}/kubespray-plan.txt"
grep -q 'dry_run: true' "${ARTIFACTS_DIR}/kubespray-plan.txt"
test -f "${ARTIFACTS_DIR}/longhorn-plan.txt"
grep -q 'longhorn' "${ARTIFACTS_DIR}/longhorn-plan.txt"
test -f "${ARTIFACTS_DIR}/status.json"
grep -q '"phase": "Succeeded"' "${ARTIFACTS_DIR}/status.json"
grep -q '"provisioner": "kubespray"' "${ARTIFACTS_DIR}/status.json"
echo "  PASS: provision-local dry-run chain"

# Negative: bad cluster name
if CLUSTER_NAME='BAD_NAME' "${ROOT}/scripts/validate-request.sh" 2>/dev/null; then
  echo "  FAIL: expected validate to reject BAD_NAME"
  exit 1
fi
echo "  PASS: reject invalid cluster_name"

echo "local scripts: all passed"
