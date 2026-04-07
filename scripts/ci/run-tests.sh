#!/usr/bin/env bash

set -euo pipefail

mkdir -p .coverage-artifacts

if ! command -v pytest >/dev/null 2>&1; then
  echo "pytest is required but not installed." >&2
  exit 1
fi

discovered_tests=()

while IFS= read -r test_file; do
  discovered_tests+=("${test_file}")
done < <(find services tests -type f \( -name "test_*.py" -o -name "*_test.py" \) 2>/dev/null | sort)

if ((${#discovered_tests[@]} == 0)); then
  echo "No Python tests discovered yet." | tee .coverage-artifacts/no-tests.txt
  exit 0
fi

test_roots=()

if [ -d services ]; then
  test_roots+=("services")
fi

if [ -d tests ]; then
  test_roots+=("tests")
fi

if pytest --help 2>/dev/null | grep -q -- "--cov"; then
  pytest "${test_roots[@]}" \
    --cov=services \
    --cov-branch \
    --cov-report=term-missing \
    --cov-report=xml:.coverage-artifacts/coverage.xml \
    --junitxml=.coverage-artifacts/junit.xml
else
  echo "pytest-cov is not installed; running tests without coverage instrumentation."
  pytest "${test_roots[@]}" \
    --junitxml=.coverage-artifacts/junit.xml
fi
