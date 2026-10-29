#!/usr/bin/env bash
# Submit the provisioning-pipeline WorkflowTemplate via the Argo HTTP API.
# Requires: kubectl access, port-forward to argo-server :2746, jq, and
# `make setup-argo-api-auth` (jenkins SA token Secret in the argo namespace).
set -euo pipefail

NAMESPACE="${ARGO_NAMESPACE:-argo}"
SECRET_NAME="${ARGO_TOKEN_SECRET:-jenkins.service-account-token}"
TEMPLATE_NAME="${ARGO_WORKFLOW_TEMPLATE:-provisioning-pipeline}"
MESSAGE="${1:-Hello, Argo!}"
ARGO_SERVER="${ARGO_SERVER:-https://localhost:2746}"

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
  --arg message "${MESSAGE}" \
  '{
    namespace: $ns,
    resourceKind: "WorkflowTemplate",
    resourceName: $template,
    submitOptions: {
      generateName: "provisioning-workflow-",
      parameters: ["message=\($message)"]
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
