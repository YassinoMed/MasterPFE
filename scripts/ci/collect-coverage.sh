#!/usr/bin/env bash

set -euo pipefail

mkdir -p .coverage-artifacts

COVERAGE_XML=".coverage-artifacts/coverage.xml"
SUMMARY_FILE=".coverage-artifacts/coverage-summary.txt"
MIN_COVERAGE="${COVERAGE_MIN:-70}"

if [ ! -f "${COVERAGE_XML}" ]; then
  {
    echo "coverage_percent=not-available"
    echo "coverage_minimum=${MIN_COVERAGE}"
    echo "status=skipped-no-tests"
  } > "${SUMMARY_FILE}"

  echo "Coverage report not generated yet; threshold enforcement skipped."
  exit 0
fi

python3 - "${COVERAGE_XML}" "${SUMMARY_FILE}" "${MIN_COVERAGE}" <<'PY'
import sys
import xml.etree.ElementTree as ET

coverage_path, summary_path, min_coverage = sys.argv[1], sys.argv[2], float(sys.argv[3])

root = ET.parse(coverage_path).getroot()
line_rate = float(root.attrib.get("line-rate", "0"))
coverage_percent = line_rate * 100

with open(summary_path, "w", encoding="utf-8") as summary:
    summary.write(f"coverage_percent={coverage_percent:.2f}\n")
    summary.write(f"coverage_minimum={min_coverage:.2f}\n")
    summary.write("status=measured\n")

if coverage_percent < min_coverage:
    print(
        f"Coverage {coverage_percent:.2f}% is below the required threshold {min_coverage:.2f}%.",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"Coverage threshold satisfied: {coverage_percent:.2f}% >= {min_coverage:.2f}%")
PY
