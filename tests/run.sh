#!/usr/bin/env bash
# Run offline unit/static tests (no Kind/cluster required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

echo "==> bash syntax: scripts + submit"
bash -n send-api-request.sh
for script in scripts/*.sh; do
  bash -n "${script}"
done

echo "==> unit: send-api-request.sh"
bash tests/test_send_api_request.sh

echo "==> unit: manifests"
python3 tests/test_manifests.py

echo "==> unit: local scripts dry-run"
bash tests/test_local_scripts.sh

echo
echo "All offline tests passed."
