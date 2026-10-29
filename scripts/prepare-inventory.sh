#!/usr/bin/env bash
# Build a Kubespray inventory for the local cluster from NODE_IPS.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

CLUSTER_NAME="${CLUSTER_NAME:-}"
NODE_IPS="${NODE_IPS:-}"
SSH_USER="${SSH_USER:-ubuntu}"
INVENTORY_DIR="${INVENTORY_DIR:-${WORK_DIR}/inventory/${CLUSTER_NAME}}"

[[ -n "${CLUSTER_NAME}" ]] || die "CLUSTER_NAME is required"
[[ -n "${NODE_IPS}" ]] || die "NODE_IPS is required"

IFS=',' read -r -a IPS <<< "${NODE_IPS}"
mkdir -p "${INVENTORY_DIR}/group_vars/all" "${INVENTORY_DIR}/group_vars/k8s_cluster"

hosts_yaml="${INVENTORY_DIR}/hosts.yaml"
{
  echo "all:"
  echo "  hosts:"
  i=1
  for raw in "${IPS[@]}"; do
    ip="$(echo "${raw}" | xargs)"
    echo "    node${i}:"
    echo "      ansible_host: ${ip}"
    echo "      ip: ${ip}"
    echo "      access_ip: ${ip}"
    i=$((i + 1))
  done
  echo "  children:"
  echo "    kube_control_plane:"
  echo "      hosts:"
  echo "        node1:"
  echo "    kube_node:"
  echo "      hosts:"
  i=1
  for _ in "${IPS[@]}"; do
    echo "        node${i}:"
    i=$((i + 1))
  done
  echo "    etcd:"
  echo "      hosts:"
  echo "        node1:"
  echo "    k8s_cluster:"
  echo "      children:"
  echo "        kube_control_plane:"
  echo "        kube_node:"
  echo "    calico_rr:"
  echo "      hosts: {}"
} > "${hosts_yaml}"

cat > "${INVENTORY_DIR}/group_vars/all/all.yml" <<EOF
---
cloud_provider: null
ansible_user: ${SSH_USER}
ansible_ssh_private_key_file: ${SSH_PRIVATE_KEY_FILE}
ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
EOF

cat > "${INVENTORY_DIR}/group_vars/k8s_cluster/k8s-cluster.yml" <<EOF
---
kube_network_plugin: calico
kubeconfig_localhost: true
kubectl_localhost: true
persistent_volumes_enabled: false
helm_enabled: true
metrics_server_enabled: true
EOF

mkdir -p "${ARTIFACTS_DIR}/inventory"
cp -a "${INVENTORY_DIR}/." "${ARTIFACTS_DIR}/inventory/"
log "prepared Kubespray inventory at ${INVENTORY_DIR} (${#IPS[@]} nodes)"
printf '%s\n' "${INVENTORY_DIR}" > "${ARTIFACTS_DIR}/inventory_dir.txt"
