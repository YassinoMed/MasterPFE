#!/usr/bin/env bash
# chaos-report.sh — Generate Markdown Chaos Engineering Report
# Reads experiment result files and produces a comprehensive markdown report.
#
# Usage: bash scripts/chaos/chaos-report.sh [--input <dir>] [--output <file>]
#
# Input:  artifacts/chaos/*.log or custom directory
# Output: artifacts/chaos/report-<ts>.md

set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
INPUT_DIR="${INPUT_DIR:-artifacts/chaos}"
OUTPUT_FILE="${OUTPUT_FILE:-${INPUT_DIR}/chaos-report-${TS}.md}"
mkdir -p "${INPUT_DIR}"

echo "[INFO] Chaos Report Generator"
echo "[INFO] Input:  ${INPUT_DIR}"
echo "[INFO] Output: ${OUTPUT_FILE}"

# Gather all result files
result_files=()
while IFS= read -r -d '' f; do
  result_files+=("${f}")
done < <(find "${INPUT_DIR}" -name '*.log' -not -name 'chaos-report-*' -print0 2>/dev/null || true)

if [ ${#result_files[@]} -eq 0 ]; then
  echo "[WARN] No result files found in ${INPUT_DIR}"
  # Generate minimal report
  {
    echo "# Chaos Engineering Report"
    echo ""
    echo "_Generated: $(date -u)_"
    echo "_Status: NO DATA — no experiment results found_"
    echo ""
    echo "No chaos experiments have been executed yet, or results are in a different location."
    echo ""
    echo "Run \`scripts/chaos/chaos-smoke-test.sh\` first to produce results."
  } > "${OUTPUT_FILE}"
  echo "[INFO] Wrote minimal report to ${OUTPUT_FILE}"
  exit 0
fi

echo "[INFO] Found ${#result_files[@]} result file(s)"

# Parse all results
declare -A experiment_data
declare -a experiment_names
total_experiments=0
total_slo_pass=0
total_avail_pass=0

collect_experiment() {
  local file="$1"
  while IFS=: read -r _ name avail_str rto_str slo_str avail_str2; do
    local name_clean="${name}"
    local avail="${avail_str#availability=}"
    local rto="${rto_str#rto=}"
    local slo="${slo_str#slo=}"
    local avail_flag="${avail_str2#avail=}"
    experiment_data["${name_clean}_avail"]="${avail}"
    experiment_data["${name_clean}_rto"]="${rto}"
    experiment_data["${name_clean}_slo"]="${slo}"
    experiment_data["${name_clean}_avail_flag"]="${avail_flag}"
    experiment_names+=("${name_clean}")
    total_experiments=$((total_experiments + 1))
    if [ "${slo}" = "PASS" ]; then total_slo_pass=$((total_slo_pass + 1)); fi
    if [ "${avail_flag}" = "PASS" ]; then total_avail_pass=$((total_avail_pass + 1)); fi
  done < <(grep '^RESULT:' "${file}" 2>/dev/null || true)
}

for f in "${result_files[@]}"; do
  collect_experiment "${f}"
done

# Compute overall availability
overall_avail=0
if [ "${total_experiments}" -gt 0 ]; then
  sum=0
  for name in "${experiment_names[@]}"; do
    sum=$(echo "${sum} + ${experiment_data[${name}_avail]}" | bc 2>/dev/null || echo 0)
  done
  overall_avail=$(echo "scale=2; ${sum} / ${total_experiments}" | bc 2>/dev/null || echo 0)
fi

overall_verdict="PASS"
if [ "${total_slo_pass}" -lt "${total_experiments}" ] || [ "${total_avail_pass}" -lt "${total_experiments}" ]; then
  overall_verdict="DEGRADED"
fi

# Compute average RTO
avg_rto=0
rto_sum=0
rto_count=0
for name in "${experiment_names[@]}"; do
  rto_val="${experiment_data[${name}_rto]}"
  if [[ "${rto_val}" =~ ^[0-9]+$ ]]; then
    rto_sum=$((rto_sum + rto_val))
    rto_count=$((rto_count + 1))
  fi
done
if [ "${rto_count}" -gt 0 ]; then
  avg_rto=$((rto_sum / rto_count))
fi

# Generate report
{
  echo "# Chaos Engineering Report — SecureRAG Hub"
  echo ""
  echo "_Generated: $(date -u)_"
  echo "_Data Source: ${INPUT_DIR}_"
  echo ""
  echo "---"
  echo ""
  echo "## Executive Summary"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|-------|"
  echo "| Experiments Analyzed | ${total_experiments} |"
  echo "| SLO Passed (RTO ≤ 60s) | ${total_slo_pass}/${total_experiments} |"
  echo "| SLO Passed (Availability ≥ 99.5%) | ${total_avail_pass}/${total_experiments} |"
  echo "| Overall Availability | ${overall_avail}% |"
  echo "| Average RTO | ${avg_rto}s |"
  echo "| Overall Verdict | **${overall_verdict}** |"
  echo ""
  echo "---"
  echo ""
  echo "## Experiment Results"
  echo ""
  echo "| # | Experiment | Availability (%) | RTO (s) | RTO SLO | Avail SLO |"
  echo "|---|------------|-----------------|---------|---------|-----------|"

  idx=1
  for name in "${experiment_names[@]}"; do
    avail="${experiment_data[${name}_avail]}"
    rto="${experiment_data[${name}_rto]}"
    slo="${experiment_data[${name}_slo]}"
    avail_flag="${experiment_data[${name}_avail_flag]}"
    echo "| ${idx} | ${name} | ${avail} | ${rto} | ${slo} | ${avail_flag} |"
    idx=$((idx + 1))
  done
  echo ""
  echo "---"
  echo ""
  echo "## SLO Compliance"
  echo ""
  echo "- **RTO SLO**: Recovery Time Objective ≤ 60 seconds"
  echo "- **Availability SLO**: Service availability ≥ 99.5% during chaos"
  echo ""
  echo "### RTO SLO Results"
  echo ""
  for name in "${experiment_names[@]}"; do
    slo="${experiment_data[${name}_slo]}"
    rto="${experiment_data[${name}_rto]}"
    if [ "${slo}" = "PASS" ]; then
      echo "- ✅ ${name}: RTO ${rto}s (within SLO)"
    else
      echo "- ❌ ${name}: RTO ${rto}s (exceeds SLO of 60s)"
    fi
  done
  echo ""
  echo "### Availability SLO Results"
  echo ""
  for name in "${experiment_names[@]}"; do
    avail_flag="${experiment_data[${name}_avail_flag]}"
    avail="${experiment_data[${name}_avail]}"
    if [ "${avail_flag}" = "PASS" ]; then
      echo "- ✅ ${name}: ${avail}% availability (within SLO)"
    else
      echo "- ❌ ${name}: ${avail}% availability (below SLO of 99.5%)"
    fi
  done
  echo ""
  echo "---"
  echo ""
  echo "## Recommendations"
  echo ""
  if [ "${overall_verdict}" = "PASS" ]; then
    echo "All experiments passed SLO thresholds. The system is resilient under the tested failure scenarios."
    echo ""
    echo "Consider expanding the test suite with:"
    echo "- HTTP chaos (request errors, status code injection)"
    echo "- IO stress (disk pressure)"
    echo "- Node-level failures (node reboot, network partition)"
  else
    echo "Some experiments failed SLO thresholds. Recommended actions:"
    for name in "${experiment_names[@]}"; do
      slo="${experiment_data[${name}_slo]}"
      avail_flag="${experiment_data[${name}_avail_flag]}"
      if [ "${slo}" = "FAIL" ]; then
        echo "- **${name}**: RTO exceeded — review startup probes, init containers, and resource limits"
      fi
      if [ "${avail_flag}" = "FAIL" ]; then
        echo "- **${name}**: Availability dropped — increase replica count, tune HPA, or add circuit breakers"
      fi
    done
  fi
  echo ""
  echo "---"
  echo ""
  echo "## Raw Data Files"
  echo ""
  for f in "${result_files[@]}"; do
    echo "- \`${f}\`"
  done
  echo ""
  echo "_End of Report_"

} > "${OUTPUT_FILE}"

echo "[INFO] Report written to ${OUTPUT_FILE}"
echo "[INFO] Verdict: ${overall_verdict} — ${total_slo_pass}/${total_experiments} SLO passed"
