#!/usr/bin/env bash
# Submit the local provisioning-pipeline WorkflowTemplate via the Argo HTTP API.
# Requires: kubectl access, port-forward to argo-server :2746, jq, and
# `make setup-argo-api-auth` + `make deploy-provisioning-scripts`.
set -euo pipefail

NAMESPACE="${ARGO_NAMESPACE:-argo}"
SECRET_NAME="${ARGO_TOKEN_SECRET:-jenkins.service-account-token}"
TEMPLATE_NAME="${ARGO_WORKFLOW_TEMPLATE:-provisioning-pipeline}"
ARGO_SERVER="${ARGO_SERVER:-https://localhost:2746}"

CLUSTER_NAME="${CLUSTER_NAME:-local-demo}"
NODE_IPS="${NODE_IPS:-192.168.1.11,192.168.1.12,192.168.1.13}"
SSH_USER="${SSH_USER:-ubuntu}"
KUBESPRAY_VERSION="${KUBESPRAY_VERSION:-v2.26.0}"
LONGHORN_VERSION="${LONGHORN_VERSION:-1.7.2}"
DRY_RUN="${DRY_RUN:-true}"

# Backward-compatible positional: ./send-api-request.sh <cluster_name>
if [[ "${1:-}" != "" ]]; then
  CLUSTER_NAME="$1"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to build the submit payload safely" >&2
  exit 1
fi

if ! kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "error: secret/${SECRET_NAME} not found in namespace/${NAMESPACE}" >&2
  echo "hint: run 'make setup-argo-api-auth' first" >&2
  exit 1
fi

TOKEN="$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.token}' | base64 --decode)"
if [[ -z "${TOKEN}" ]]; then
  echo "error: secret/${SECRET_NAME} has an empty token" >&2
  exit 1
fi

PAYLOAD="$(jq -n \
  --arg ns "${NAMESPACE}" \
  --arg template "${TEMPLATE_NAME}" \
  --arg cluster_name "${CLUSTER_NAME}" \
  --arg node_ips "${NODE_IPS}" \
  --arg ssh_user "${SSH_USER}" \
  --arg kubespray_version "${KUBESPRAY_VERSION}" \
  --arg longhorn_version "${LONGHORN_VERSION}" \
  --arg dry_run "${DRY_RUN}" \
  '{
    namespace: $ns,
    resourceKind: "WorkflowTemplate",
    resourceName: $template,
    submitOptions: {
      generateName: "provisioning-workflow-",
      parameters: [
        "cluster_name=\($cluster_name)",
        "node_ips=\($node_ips)",
        "ssh_user=\($ssh_user)",
        "kubespray_version=\($kubespray_version)",
        "longhorn_version=\($longhorn_version)",
        "dry_run=\($dry_run)"
      ]
    }
  }')"

curl --request POST \
  --insecure \
  --silent \
  --show-error \
  --fail-with-body \
  --url "${ARGO_SERVER}/api/v1/workflows/${NAMESPACE}/submit" \
  --header 'content-type: application/json' \
  --header "Authorization: Bearer ${TOKEN}" \
  --data "${PAYLOAD}"
echo
