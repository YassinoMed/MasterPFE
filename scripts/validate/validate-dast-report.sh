#!/usr/bin/env bash
# validate-dast-report.sh — Analyse OWASP ZAP JSON report and flag HIGH/CRITICAL alerts
#
# Usage:
#   bash scripts/validate/validate-dast-report.sh
#
# Inputs:
#   DAST_REPORT  — Path to ZAP JSON report (default: artifacts/dast/dast-baseline-report.json)
#   REPORT_DIR   — Output directory for the validation summary (default: artifacts/dast)
#   DAST_FAIL_ON — Minimum risk level to fail: "High", "Medium", or "Low" (default: High)
#
# Outputs:
#   artifacts/dast/dast-validation-summary.md — Human-readable summary
#   Exit code 0 if no alerts at or above DAST_FAIL_ON level, 1 otherwise.
set -euo pipefail

DAST_REPORT="${DAST_REPORT:-artifacts/dast/dast-baseline-report.json}"
REPORT_DIR="${REPORT_DIR:-artifacts/dast}"
SUMMARY_FILE="${REPORT_DIR}/dast-validation-summary.md"
DAST_FAIL_ON="${DAST_FAIL_ON:-High}"

mkdir -p "${REPORT_DIR}"

# ── Pre-flight ─────────────────────────────────────────────────────────
if [[ ! -f "${DAST_REPORT}" ]]; then
  {
    printf '# DAST Validation Summary\n\n'
    printf '## Status: SKIPPED\n\n'
    printf 'No DAST report found at `%s`.\n\n' "${DAST_REPORT}"
    printf 'Run `make dast-baseline` or enable `RUN_DAST=true` in Jenkins CD.\n'
  } > "${SUMMARY_FILE}"
  printf '[SKIP] No DAST report found at %s\n' "${DAST_REPORT}"
  exit 0
fi

if ! command -v python3 > /dev/null 2>&1; then
  printf '[SKIP] python3 not found; cannot parse DAST report\n'
  exit 0
fi

# ── Parse ZAP JSON report ─────────────────────────────────────────────
python3 - "${DAST_REPORT}" "${SUMMARY_FILE}" "${DAST_FAIL_ON}" << 'PYEOF'
import json, sys, os

report_path = sys.argv[1]
summary_path = sys.argv[2]
fail_on = sys.argv[3]

risk_levels = {"Informational": 0, "Low": 1, "Medium": 2, "High": 3}
fail_threshold = risk_levels.get(fail_on, 3)

try:
    with open(report_path, 'r') as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError) as e:
    with open(summary_path, 'w') as f:
        f.write(f"# DAST Validation Summary\n\n## Status: ERROR\n\nFailed to parse report: {e}\n")
    print(f"[ERROR] Failed to parse DAST report: {e}")
    sys.exit(1)

# ZAP JSON structure: {"site": [{"alerts": [...]}]}
alerts = []
sites = data.get("site", [])
if isinstance(sites, list):
    for site in sites:
        alerts.extend(site.get("alerts", []))
elif isinstance(sites, dict):
    alerts.extend(sites.get("alerts", []))

# Aggregate by risk
counts = {"Informational": 0, "Low": 0, "Medium": 0, "High": 0}
high_alerts = []
medium_alerts = []

for alert in alerts:
    risk = alert.get("riskdesc", "").split(" ")[0] if "riskdesc" in alert else alert.get("risk", "Informational")
    if risk in counts:
        counts[risk] += 1
    if risk == "High":
        high_alerts.append(alert)
    elif risk == "Medium":
        medium_alerts.append(alert)

total = sum(counts.values())
fail_count = sum(v for k, v in counts.items() if risk_levels.get(k, 0) >= fail_threshold)
status = "PASS" if fail_count == 0 else "FAIL"

with open(summary_path, 'w') as f:
    f.write("# DAST Validation Summary — SecureRAG Hub\n\n")
    f.write(f"- Report: `{report_path}`\n")
    f.write(f"- Fail threshold: `{fail_on}`\n")
    f.write(f"- Total alerts: **{total}**\n\n")

    if status == "PASS":
        f.write("## ✅ Status: PASS\n\n")
        f.write(f"No alerts at or above `{fail_on}` severity.\n\n")
    else:
        f.write(f"## ❌ Status: FAIL ({fail_count} alert(s) ≥ {fail_on})\n\n")

    f.write("## Alert Summary\n\n")
    f.write("| Risk Level | Count |\n|---|---|\n")
    for level in ["High", "Medium", "Low", "Informational"]:
        icon = "🔴" if level == "High" else "🟠" if level == "Medium" else "🟡" if level == "Low" else "ℹ️"
        f.write(f"| {icon} {level} | {counts[level]} |\n")

    if high_alerts:
        f.write("\n## 🔴 High-Risk Alerts\n\n")
        for a in high_alerts:
            name = a.get("name", a.get("alert", "Unknown"))
            desc = a.get("desc", "No description")[:200]
            solution = a.get("solution", "No solution provided")[:200]
            f.write(f"### {name}\n\n")
            f.write(f"- **Description**: {desc}\n")
            f.write(f"- **Solution**: {solution}\n")
            f.write(f"- **Instances**: {a.get('count', len(a.get('instances', [])))}\n\n")

    if medium_alerts:
        f.write("\n## 🟠 Medium-Risk Alerts\n\n")
        for a in medium_alerts:
            name = a.get("name", a.get("alert", "Unknown"))
            f.write(f"- **{name}** ({a.get('count', len(a.get('instances', [])))} instance(s))\n")

    f.write("\n## Recommendations\n\n")
    f.write("- Fix all High-risk alerts before production deployment\n")
    f.write("- Review Medium-risk alerts and create backlog items\n")
    f.write("- Consider running `make dast-full` for comprehensive scanning\n")
    f.write("- See `docs/security/dast-roadmap.md` for integration details\n")

print(f"[{'PASS' if status == 'PASS' else 'FAIL'}] DAST: {total} total alerts ({counts['High']} High, {counts['Medium']} Medium)")
print(f"[INFO] Summary: {summary_path}")

sys.exit(0 if status == "PASS" else 1)
PYEOF

rc=$?
printf '[INFO] DAST validation report: %s\n' "${SUMMARY_FILE}"
exit "${rc}"
