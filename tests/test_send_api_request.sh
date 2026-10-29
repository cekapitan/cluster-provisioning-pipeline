#!/usr/bin/env bash
# Unit tests for send-api-request.sh using mocked kubectl/curl (no cluster required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

MOCK_BIN="${TMP}/bin"
mkdir -p "${MOCK_BIN}"
CURL_CAPTURE="${TMP}/curl-args.txt"
CURL_BODY="${TMP}/curl-body.txt"
PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

write_kubectl_ok() {
  cat > "${MOCK_BIN}/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
if [[ "$args" == "get secret jenkins.service-account-token -n argo" ]]; then
  exit 0
fi
if [[ "$args" == "get secret jenkins.service-account-token -n argo -o jsonpath={.data.token}" ]]; then
  # base64("test-token")
  printf 'dGVzdC10b2tlbg=='
  exit 0
fi
echo "unexpected kubectl args: $args" >&2
exit 1
EOF
  chmod +x "${MOCK_BIN}/kubectl"
}

write_kubectl_missing() {
  cat > "${MOCK_BIN}/kubectl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "${MOCK_BIN}/kubectl"
}

write_curl_capture() {
  cat > "${MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
: > "${CURL_CAPTURE}"
body_next=0
for arg in "\$@"; do
  printf '%s\n' "\$arg" >> "${CURL_CAPTURE}"
  if [[ "\$body_next" -eq 1 ]]; then
    printf '%s' "\$arg" > "${CURL_BODY}"
    body_next=0
  fi
  if [[ "\$arg" == "--data" ]]; then
    body_next=1
  fi
done
printf '{"metadata":{"name":"provisioning-workflow-test"}}'
EOF
  chmod +x "${MOCK_BIN}/curl"
}

export PATH="${MOCK_BIN}:/usr/bin:/bin"

echo "test_send_api_request.sh"

# --- happy path ---
write_kubectl_ok
write_curl_capture
rm -f "${CURL_CAPTURE}" "${CURL_BODY}"
if out="$("${ROOT}/send-api-request.sh" 'hello "world"')" ; then
  if grep -qx 'Authorization: Bearer test-token' "${CURL_CAPTURE}"; then
    pass "sends Authorization Bearer with expanded token"
  else
    fail "Authorization header missing or wrong: $(tr '\n' ' ' < "${CURL_CAPTURE}")"
  fi

  if grep -qx -- "--url" "${CURL_CAPTURE}" \
    && grep -qx 'https://localhost:2746/api/v1/workflows/argo/submit' "${CURL_CAPTURE}"; then
    pass "posts to workflows submit endpoint"
  else
    fail "submit URL incorrect"
  fi

  if jq -e '
      .resourceKind == "WorkflowTemplate"
      and .resourceName == "provisioning-pipeline"
      and (.submitOptions.parameters | index("message=hello \"world\""))
    ' "${CURL_BODY}" >/dev/null; then
    pass "JSON payload includes template and escaped message"
  else
    fail "payload incorrect: $(cat "${CURL_BODY}")"
  fi

  if [[ "${out}" == *'provisioning-workflow-test'* ]]; then
    pass "prints curl response body"
  else
    fail "unexpected script output: ${out}"
  fi
else
  fail "happy path exited non-zero"
fi

# --- missing secret ---
write_kubectl_missing
write_curl_capture
if err="$("${ROOT}/send-api-request.sh" 'x' 2>&1)" ; then
  fail "missing secret should fail"
else
  if [[ "${err}" == *'not found'* ]] || [[ "${err}" == *'setup-argo-api-auth'* ]]; then
    pass "missing secret fails with helpful error"
  else
    fail "missing secret error unclear: ${err}"
  fi
fi

# --- single-quote regression guard ---
# Old bug: --header 'authorization: ${ARGO_TOKEN}' never expands.
if grep -E -- "--header[[:space:]]+'[Aa]uthorization:.*\\$\\{" "${ROOT}/send-api-request.sh" >/dev/null; then
  fail "Authorization header still uses unexpanded single-quoted variable"
elif grep -F -- '--header "Authorization: Bearer ${TOKEN}"' "${ROOT}/send-api-request.sh" >/dev/null; then
  pass "Authorization header uses double quotes for expansion"
else
  fail "could not confirm Authorization header quoting"
fi

echo
echo "send-api-request: ${PASS} passed, ${FAIL} failed"
if [[ "${FAIL}" -ne 0 ]]; then
  exit 1
fi
