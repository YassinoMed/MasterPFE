#!/usr/bin/env bash
# run-python-tests.sh — SecureRAG Hub
# Executes pytest for Python microservices (e.g., extraire)
# Generates XML coverage report

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARTIFACT_DIR="${REPO_ROOT}/.coverage-artifacts"

mkdir -p "${ARTIFACT_DIR}"

summary="${ARTIFACT_DIR}/python-test-summary.txt"
: > "${summary}"

echo "[INFO] Running Python tests for extraire" | tee -a "${summary}"

if [[ ! -d "${REPO_ROOT}/services/extraire" ]]; then
  echo "[FAIL] Missing extraire service directory" | tee -a "${summary}"
  exit 1
fi

set +e
(
  cd "${REPO_ROOT}/services/extraire"
  
  # Ensure pytest is installed
  if ! command -v pytest >/dev/null 2>&1; then
    python3 -m pip install pytest pytest-cov
  fi

  pytest --cov=src --cov-report=xml:"${ARTIFACT_DIR}/coverage-extraire.xml" --junitxml="${ARTIFACT_DIR}/junit-extraire.xml" tests/
  exit_code=$?
  exit "${exit_code}"
)
app_exit=$?
set -e

if [[ "${app_exit}" -ne 0 ]]; then
  echo "[FAIL] Python tests failed for extraire (exit code ${app_exit})" | tee -a "${summary}"
  exit 1
else
  echo "[PASS] Python tests passed for extraire" | tee -a "${summary}"
fi

echo "[INFO] Python test suite completed successfully." | tee -a "${summary}"
exit 0
