#!/usr/bin/env bash
# Run offline unit/static tests (no Kind/cluster required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

echo "==> bash syntax: send-api-request.sh"
bash -n send-api-request.sh

echo "==> unit: send-api-request.sh"
bash tests/test_send_api_request.sh

echo "==> unit: manifests"
python3 tests/test_manifests.py

echo
echo "All offline tests passed."
