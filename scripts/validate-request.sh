#!/usr/bin/env bash
# Validate local cluster request parameters before provisioning.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

CLUSTER_NAME="${CLUSTER_NAME:-}"
NODE_IPS="${NODE_IPS:-}"
SSH_USER="${SSH_USER:-ubuntu}"
KUBESPRAY_VERSION="${KUBESPRAY_VERSION:-v2.26.0}"
LONGHORN_VERSION="${LONGHORN_VERSION:-1.7.2}"
DRY_RUN="${DRY_RUN:-true}"

[[ -n "${CLUSTER_NAME}" ]] || die "CLUSTER_NAME is required"
[[ "${CLUSTER_NAME}" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || die "CLUSTER_NAME must be a DNS-1123 label"
[[ -n "${NODE_IPS}" ]] || die "NODE_IPS is required (comma-separated)"

IFS=',' read -r -a IPS <<< "${NODE_IPS}"
[[ "${#IPS[@]}" -ge 1 ]] || die "NODE_IPS must contain at least one IP"

for ip in "${IPS[@]}"; do
  ip_trimmed="$(echo "${ip}" | xargs)"
  [[ -n "${ip_trimmed}" ]] || die "NODE_IPS contains an empty entry"
done

log "validated local cluster request"
log "  cluster_name=${CLUSTER_NAME}"
log "  node_count=${#IPS[@]}"
log "  ssh_user=${SSH_USER}"
log "  kubespray_version=${KUBESPRAY_VERSION}"
log "  longhorn_version=${LONGHORN_VERSION}"
log "  storage=longhorn (local profile)"
log "  dry_run=${DRY_RUN}"

mkdir -p "${ARTIFACTS_DIR}"
ips_json="["
first=1
for raw in "${IPS[@]}"; do
  ip="$(echo "${raw}" | xargs)"
  if [[ "${first}" -eq 1 ]]; then
    first=0
  else
    ips_json+=", "
  fi
  ips_json+="\"${ip}\""
done
ips_json+="]"
dry_json="false"
truthy "${DRY_RUN}" && dry_json="true"

cat > "${ARTIFACTS_DIR}/request.json" <<EOF
{
  "cluster_name": "${CLUSTER_NAME}",
  "node_ips": ${ips_json},
  "ssh_user": "${SSH_USER}",
  "kubespray_version": "${KUBESPRAY_VERSION}",
  "longhorn_version": "${LONGHORN_VERSION}",
  "environment": "local",
  "storage_backend": "longhorn",
  "dry_run": ${dry_json}
}
EOF

log "wrote ${ARTIFACTS_DIR}/request.json"
