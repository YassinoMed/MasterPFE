#!/usr/bin/env bash
# dr-report.sh — Disaster Recovery Report Generator
# SecureRAG Hub — World-Class Disaster Recovery
#
# Reports on backup status, RTO, RPO, DR readiness score, and
# pass/fail per backup schedule.
#
# Usage:
#   bash scripts/dr/dr-report.sh                    Full report
#   bash scripts/dr/dr-report.sh --summary          Summary only
#   bash scripts/dr/dr-report.sh --json             JSON output
#   bash scripts/dr/dr-report.sh --html             HTML report
#   bash scripts/dr/dr-report.sh --output-dir <dir> Output directory
#   bash scripts/dr/dr-report.sh --ci               CI-friendly exit code
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()    { printf "${CYAN}[STEP]${NC}  %s\n" "$*"; }

MODE="full"
JSON=false
HTML=false
OUTPUT_DIR="artifacts/dr/reports"
CI_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary) MODE="summary"; shift ;;
    --json) JSON=true; shift ;;
    --html) HTML=true; shift ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --ci) CI_MODE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

mkdir -p "${OUTPUT_DIR}"

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
REPORT_FILE="${OUTPUT_DIR}/dr-report-${TIMESTAMP}.md"
JSON_FILE="${OUTPUT_DIR}/dr-report-${TIMESTAMP}.json"
HTML_FILE="${OUTPUT_DIR}/dr-report-${TIMESTAMP}.html"

PASS=0
FAIL=0
WARN=0

record_pass() { PASS=$((PASS + 1)); echo "  ✅ [PASS] $*"; }
record_fail() { FAIL=$((FAIL + 1)); echo "  ❌ [FAIL] $*"; }
record_warn() { WARN=$((WARN + 1)); echo "  ⚠️  [WARN] $*"; }

# ── Collect Data ──────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  DR REPORT — ${TIMESTAMP}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

VELERO_AVAILABLE=false
if kubectl get deployment -n velero velero &>/dev/null 2>&1; then
  VELERO_AVAILABLE=true
  info "Velero detected in cluster"
elif command -v velero &>/dev/null; then
  VELERO_AVAILABLE=true
  info "Velero CLI detected"
else
  warn "Velero not available — running static report"
fi

echo ""

# ── Backup Status (All Schedules) ─────────────────────────────

step "1/6: Backup Status — All Schedules"

SCHEDULE_DATA=()

if [ "${VELERO_AVAILABLE}" = true ]; then
  # Get all schedules
  SCHEDULES=$(velero schedule get -o json 2>/dev/null | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  items = data.get('items', [])
  for s in items:
    name = s['metadata']['name']
    schedule = s['spec'].get('schedule', 'N/A')
    phase = s.get('status',{}).get('phase', 'Unknown')
    print(f'{name}|{schedule}|{phase}')
except Exception as e:
  print(f'error: {e}')
" 2>/dev/null || echo "")

  IFS=$'\n' read -r -d '' -a SCHEDULE_LIST <<< "${SCHEDULES}" || true

  for sched_line in "${SCHEDULE_LIST[@]}"; do
    IFS='|' read -r SCHED_NAME SCHED_CRON SCHED_PHASE <<< "${sched_line}" || continue
    [ -z "${SCHED_NAME}" ] && continue

    info "Schedule: ${SCHED_NAME} (${SCHED_CRON}) — Phase: ${SCHED_PHASE}"

    # Get latest backup for this schedule
    LATEST_BACKUP=$(velero backup get -o json 2>/dev/null | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  items = data.get('items', [])
  matching = [i for i in items if i['metadata']['name'].startswith('${SCHED_NAME}')]
  if matching:
    b = matching[-1]
    print(b['metadata']['name'])
    print(b.get('status',{}).get('phase','unknown'))
    print(b.get('status',{}).get('totalItems', 0))
    print(b.get('status',{}).get('errors', 0))
    print(b['metadata']['creationTimestamp'])
except: pass
" 2>/dev/null || echo "")

    if [ -n "${LATEST_BACKUP}" ]; then
      IFS=$'\n' read -r -d '' -a BACKUP_DATA <<< "${LATEST_BACKUP}" || true

      B_NAME="${BACKUP_DATA[0]:-unknown}"
      B_STATUS="${BACKUP_DATA[1]:-unknown}"
      B_ITEMS="${BACKUP_DATA[2]:-0}"
      B_ERRORS="${BACKUP_DATA[3]:-0}"
      B_TIME="${BACKUP_DATA[4]:-unknown}"

      # Calculate age
      B_AGE="unknown"
      if [ "${B_TIME}" != "unknown" ] && command -v date &>/dev/null; then
        B_EPOCH=$(date -d "${B_TIME}" +%s 2>/dev/null || echo 0)
        if [ "${B_EPOCH}" -gt 0 ]; then
          AGE_SEC=$(( $(date +%s) - B_EPOCH ))
          AGE_H=$(( AGE_SEC / 3600 ))
          AGE_M=$(( (AGE_SEC % 3600) / 60 ))
          B_AGE="${AGE_H}h ${AGE_M}m"
        fi
      fi

      echo "    Latest: ${B_NAME} | Status: ${B_STATUS} | Items: ${B_ITEMS} | Errors: ${B_ERRORS} | Age: ${B_AGE}"

      SCHEDULE_DATA+=("${SCHED_NAME}|${SCHED_PHASE}|${B_STATUS}|${B_ITEMS}|${B_ERRORS}|${B_AGE}|${B_TIME}")

      if [ "${B_STATUS}" = "Completed" ] && [ "${B_ERRORS}" -eq 0 ]; then
        record_pass "Schedule '${SCHED_NAME}' — backup OK"
      elif [ "${B_STATUS}" = "Completed" ] && [ "${B_ERRORS}" -gt 0 ]; then
        record_warn "Schedule '${SCHED_NAME}' — completed with ${B_ERRORS} errors"
      else
        record_fail "Schedule '${SCHED_NAME}' — status: ${B_STATUS}, errors: ${B_ERRORS}"
      fi
    else
      echo "    No backups found for this schedule"
      SCHEDULE_DATA+=("${SCHED_NAME}|${SCHED_PHASE}|none|0|0|N/A|")
      record_fail "Schedule '${SCHED_NAME}' — no backups found"
    fi
  done
else
  # Static schedule info from manifests
  record_skip "Velero not available — showing static schedule info"
  SCHEDULE_DATA=(
    "daily-securerag-backup|Enabled|unknown|unknown|unknown|unknown|"
    "weekly-vault-backup|Enabled|unknown|unknown|unknown|unknown|"
    "monthly-argocd-backup|Enabled|unknown|unknown|unknown|unknown|"
  )
  for sched in "${SCHEDULE_DATA[@]}"; do
    IFS='|' read -r name phase status items errors age _ <<< "${sched}"
    echo "    ${name} (${phase}) — status unavailable"
  done
fi

echo ""

# ── Last Successful Backup Age ────────────────────────────────

step "2/6: Last Successful Backup Age"

if [ "${VELERO_AVAILABLE}" = true ]; then
  LAST_BACKUP_TIME=$(velero backup get -o json 2>/dev/null | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  items = data.get('items', [])
  completed = [i for i in items if i.get('status',{}).get('phase') == 'Completed']
  if completed:
    print(completed[-1]['metadata']['creationTimestamp'])
except: pass
" 2>/dev/null || echo "")

  if [ -n "${LAST_BACKUP_TIME}" ]; then
    LAST_EPOCH=$(date -d "${LAST_BACKUP_TIME}" +%s 2>/dev/null || echo 0)
    NOW_EPOCH=$(date +%s)
    AGE_SEC=$(( NOW_EPOCH - LAST_EPOCH ))
    AGE_H=$(( AGE_SEC / 3600 ))
    AGE_M=$(( (AGE_SEC % 3600) / 60 ))

    info "Last successful backup: ${LAST_BACKUP_TIME}"
    info "Age: ${AGE_H}h ${AGE_M}m (${AGE_SEC}s)"

    if [ "${AGE_H}" -lt 24 ]; then
      record_pass "Backup age ${AGE_H}h within 24h SLO"
    elif [ "${AGE_H}" -lt 48 ]; then
      record_warn "Backup age ${AGE_H}h exceeds 24h but within 48h"
    else
      record_fail "Backup age ${AGE_H}h exceeds 48h (stale)"
    fi

    LAST_BACKUP_AGE="${AGE_H}h ${AGE_M}m"
    LAST_BACKUP_AGE_SEC="${AGE_SEC}"
  else
    warn "No completed backups found"
    LAST_BACKUP_AGE="N/A"
    LAST_BACKUP_AGE_SEC="0"
    record_fail "No successful backups found"
  fi
else
  LAST_BACKUP_AGE="N/A"
  LAST_BACKUP_AGE_SEC="0"
  record_skip "Backup age check (Velero not available)"
fi

echo ""

# ── RTO from Last Drill ───────────────────────────────────────

step "3/6: RTO from Last Drill"

LATEST_DRILL_REPORT=""
LATEST_RTO="N/A"
LATEST_RTO_SEC=0

# Find latest drill report
for f in $(ls -t artifacts/dr/dr-drill-*-report.md 2>/dev/null || true); do
  LATEST_DRILL_REPORT="${f}"
  break
done

if [ -n "${LATEST_DRILL_REPORT}" ]; then
  info "Last drill report: ${LATEST_DRILL_REPORT}"

  LATEST_RTO_SEC=$(grep -i "RTO" "${LATEST_DRILL_REPORT}" 2>/dev/null | grep -oP '\d+m \d+s' | head -1 || echo "N/A")
  LATEST_RTO="${LATEST_RTO_SEC}"

  # Try to get RTO from evidence JSON
  DRILL_ID=$(basename "${LATEST_DRILL_REPORT}" | sed 's/-report.md//')
  EVIDENCE_FILE="artifacts/dr/${DRILL_ID}-evidence.json"
  if [ -f "${EVIDENCE_FILE}" ]; then
    JSON_RTO=$(python3 -c "import json; d=json.load(open('${EVIDENCE_FILE}')); print(d.get('rtoSeconds', 0))" 2>/dev/null || echo 0)
    if [ "${JSON_RTO}" -gt 0 ]; then
      LATEST_RTO_SEC="${JSON_RTO}"
      RTO_MIN=$(( JSON_RTO / 60 ))
      RTO_SEC=$(( JSON_RTO % 60 ))
      LATEST_RTO="${RTO_MIN}m ${RTO_SEC}s"
    fi
  fi

  # Determine pass/fail from report
  if grep -qi "PASS" "${LATEST_DRILL_REPORT}" 2>/dev/null && ! grep -qi "FAIL" "${LATEST_DRILL_REPORT}" 2>/dev/null; then
    record_pass "Last drill RTO: ${LATEST_RTO}"
  else
    record_warn "Last drill RTO: ${LATEST_RTO} (drill had failures)"
  fi
else
  warn "No drill reports found in artifacts/dr/"
  record_skip "RTO from drill (no reports found)"
fi

echo ""

# ── RPO from Last Backup ──────────────────────────────────────

step "4/6: RPO from Last Backup"

if [ -n "${LAST_BACKUP_AGE_SEC:-0}" ] && [ "${LAST_BACKUP_AGE_SEC:-0}" -gt 0 ]; then
  RPO_SEC="${LAST_BACKUP_AGE_SEC}"
  RPO_H=$(( RPO_SEC / 3600 ))
  RPO_M=$(( (RPO_SEC % 3600) / 60 ))
  RPO_HUMAN="${RPO_H}h ${RPO_M}m"

  info "RPO: ${RPO_HUMAN} (time since last successful backup)"

  if [ "${RPO_H}" -lt 24 ]; then
    record_pass "RPO ${RPO_H}h within 24h SLO"
  else
    record_fail "RPO ${RPO_H}h exceeds 24h SLO"
  fi
else
  RPO_HUMAN="N/A"
  RPO_SEC=0
  record_skip "RPO calculation (no backup data)"
fi

echo ""

# ── DR Readiness Score ────────────────────────────────────────

step "5/6: DR Readiness Score"

SCORE=0
MAX_SCORE=100

# Weight: backups (40%), RTO (15%), RPO (15%), schedules (15%), drills (15%)
SCORE_BACKUP=0
SCORE_RTO=0
SCORE_RPO=0
SCORE_SCHED=0
SCORE_DRILL=0

# Backups (up to 40 pts)
if [ -n "${LAST_BACKUP_AGE_SEC:-0}" ] && [ "${LAST_BACKUP_AGE_SEC:-0}" -gt 0 ]; then
  if [ "${LAST_BACKUP_AGE_SEC}" -lt 86400 ]; then
    SCORE_BACKUP=40
    record_pass "Backup freshness: 40/40 pts (age < 24h)"
  elif [ "${LAST_BACKUP_AGE_SEC}" -lt 172800 ]; then
    SCORE_BACKUP=20
    record_warn "Backup freshness: 20/40 pts (age > 24h)"
  else
    SCORE_BACKUP=10
    record_fail "Backup freshness: 10/40 pts (age > 48h)"
  fi
else
  SCORE_BACKUP=0
  record_fail "Backup freshness: 0/40 pts (no backups)"
fi

# RTO (up to 15 pts)
if [ "${LATEST_RTO_SEC:-0}" -gt 0 ]; then
  if [ "${LATEST_RTO_SEC}" -lt 300 ]; then
    SCORE_RTO=15
    record_pass "RTO score: 15/15 pts (< 5min)"
  elif [ "${LATEST_RTO_SEC}" -lt 600 ]; then
    SCORE_RTO=10
    record_pass "RTO score: 10/15 pts (< 10min)"
  else
    SCORE_RTO=5
    record_warn "RTO score: 5/15 pts (> 10min)"
  fi
else
  SCORE_RTO=0
  record_skip "RTO score: 0/15 pts (no drill data)"
fi

# RPO (up to 15 pts)
if [ -n "${RPO_SEC:-0}" ] && [ "${RPO_SEC:-0}" -gt 0 ]; then
  RPO_H=$(( RPO_SEC / 3600 ))
  if [ "${RPO_H}" -lt 12 ]; then
    SCORE_RPO=15
    record_pass "RPO score: 15/15 pts (< 12h)"
  elif [ "${RPO_H}" -lt 24 ]; then
    SCORE_RPO=10
    record_pass "RPO score: 10/15 pts (< 24h)"
  else
    SCORE_RPO=5
    record_warn "RPO score: 5/15 pts (> 24h)"
  fi
else
  SCORE_RPO=0
  record_skip "RPO score: 0/15 pts (no data)"
fi

# Schedules (up to 15 pts)
ACTIVE_SCHED=0
TOTAL_SCHED=0
if [ "${#SCHEDULE_DATA[@]}" -gt 0 ]; then
  TOTAL_SCHED="${#SCHEDULE_DATA[@]}"
  for sched in "${SCHEDULE_DATA[@]}"; do
    IFS='|' read -r name phase status items errors age _ <<< "${sched}"
    if [ "${status}" = "Completed" ] || [ "${status}" = "unknown" ]; then
      ACTIVE_SCHED=$(( ACTIVE_SCHED + 1 ))
    fi
  done
  if [ "${TOTAL_SCHED}" -gt 0 ]; then
    SCORE_SCHED=$(( ACTIVE_SCHED * 15 / TOTAL_SCHED ))
    record_pass "Schedule health: ${SCORE_SCHED}/15 pts (${ACTIVE_SCHED}/${TOTAL_SCHED} active)"
  fi
else
  SCORE_SCHED=0
  record_skip "Schedule score: 0/15 pts (no schedule data)"
fi

# Drills (up to 15 pts)
if [ -n "${LATEST_DRILL_REPORT}" ]; then
  if grep -qi "PASS" "${LATEST_DRILL_REPORT}" 2>/dev/null; then
    SCORE_DRILL=15
    record_pass "Drill score: 15/15 pts (last drill passed)"
  else
    SCORE_DRILL=5
    record_warn "Drill score: 5/15 pts (last drill had issues)"
  fi
else
  SCORE_DRILL=0
  record_skip "Drill score: 0/15 pts (no drill reports)"
fi

SCORE=$(( SCORE_BACKUP + SCORE_RTO + SCORE_RPO + SCORE_SCHED + SCORE_DRILL ))

info "DR Readiness Score: ${SCORE}/${MAX_SCORE}"
if [ "${SCORE}" -ge 80 ]; then
  record_pass "DR Readiness: ${SCORE}/100 — READY (score >= 80)"
elif [ "${SCORE}" -ge 50 ]; then
  record_warn "DR Readiness: ${SCORE}/100 — DEGRADED (score 50-79)"
else
  record_fail "DR Readiness: ${SCORE}/100 — CRITICAL (score < 50)"
fi

echo ""

# ── Pass/Fail per Schedule ────────────────────────────────────

step "6/6: Pass/Fail per Backup Schedule"

SCHEDULE_RESULTS=()

if [ "${VELERO_AVAILABLE}" = true ]; then
  for sched in "${SCHEDULE_DATA[@]}"; do
    IFS='|' read -r name phase status items errors age btime <<< "${sched}"

    if [ "${status}" = "Completed" ] && [ "${errors}" -eq 0 ]; then
      result="PASS"
    elif [ "${status}" = "Completed" ] && [ "${errors}" -gt 0 ]; then
      result="WARN"
    elif [ "${status}" = "none" ]; then
      result="FAIL"
    else
      result="FAIL"
    fi

    SCHEDULE_RESULTS+=("${name}|${result}|${age}")
    echo "  ${name}: ${result} (age: ${age})"
  done
else
  echo "  Velero not available — cannot evaluate schedule status"
  for sched in "${SCHEDULE_DATA[@]}"; do
    IFS='|' read -r name phase _ <<< "${sched}"
    SCHEDULE_RESULTS+=("${name}|UNKNOWN|N/A")
    echo "  ${name}: UNKNOWN (Velero unavailable)"
  done
fi

echo ""

# ── Generate Markdown Report ──────────────────────────────────

step "Generating report files..."

# Build schedule table rows
SCHED_TABLE=""
for sched in "${SCHEDULE_RESULTS[@]}"; do
  IFS='|' read -r name result age <<< "${sched}"
  case "${result}" in
    PASS) icon="✅" ;;
    FAIL) icon="❌" ;;
    WARN) icon="⚠️" ;;
    *) icon="❓" ;;
  esac
  SCHED_TABLE="${SCHED_TABLE}| ${name} | ${age} | ${icon} ${result} |\n"
done

SCORE_LABEL=""
SCORE_ICON=""
if [ "${SCORE}" -ge 80 ]; then
  SCORE_LABEL="READY"
  SCORE_ICON="✅"
elif [ "${SCORE}" -ge 50 ]; then
  SCORE_LABEL="DEGRADED"
  SCORE_ICON="⚠️"
else
  SCORE_LABEL="CRITICAL"
  SCORE_ICON="❌"
fi

cat > "${REPORT_FILE}" <<EOF
# DR Report — ${TIMESTAMP}

## Overview
| Metric | Value |
|:---|:---|
| Generated | ${TIMESTAMP} |
| Velero Status | $([ "${VELERO_AVAILABLE}" = true ] && echo "✅ Available" || echo "❌ Unavailable") |
| DR Readiness Score | ${SCORE}/${MAX_SCORE} — ${SCORE_ICON} ${SCORE_LABEL} |

## Backup Schedules
| Schedule | Age | Status |
|:---|:---:|:---:|
$(echo -e "${SCHED_TABLE}")

## Recovery Metrics
| Metric | Value | SLO | Result |
|:---|:---:|:---:|:---:|
| Last Backup Age | ${LAST_BACKUP_AGE} | < 24h | $([ -n "${LAST_BACKUP_AGE_SEC:-0}" ] && [ "${LAST_BACKUP_AGE_SEC:-0}" -lt 86400 ] && echo "✅" || echo "❌") |
| RTO (Last Drill) | ${LATEST_RTO} | < 10min | $([ "${LATEST_RTO_SEC:-0}" -lt 600 ] && echo "✅" || echo "❌") |
| RPO (Current) | ${RPO_HUMAN:-N/A} | < 24h | $([ -n "${RPO_SEC:-0}" ] && [ "${RPO_SEC:-0}" -lt 86400 ] && echo "✅" || echo "❌") |

## DR Readiness Score Breakdown
| Component | Score | Max |
|:---|:---:|:---:|
| Backup Freshness | ${SCORE_BACKUP} | 40 |
| RTO Performance | ${SCORE_RTO} | 15 |
| RPO Compliance | ${SCORE_RPO} | 15 |
| Schedule Health | ${SCORE_SCHED} | 15 |
| Drill Execution | ${SCORE_DRILL} | 15 |
| **Total** | **${SCORE}** | **${MAX_SCORE}** |

## Check Results
- **Passed**: ${PASS}
- **Failed**: ${FAIL}
- **Warnings**: ${WARN}

## Verdict
- **Readiness**: ${SCORE_ICON} ${SCORE_LABEL} (${SCORE}/${MAX_SCORE})
- **Overall**: $([ "${FAIL}" -eq 0 ] && echo "✅ All DR checks passing" || echo "❌ ${FAIL} checks require attention")
EOF

info "Markdown report: ${REPORT_FILE}"

# ── Generate JSON Report ──────────────────────────────────────

JSON_CONTENT="{
  \"report\": {
    \"timestamp\": \"${TIMESTAMP}\",
    \"veleroAvailable\": ${VELERO_AVAILABLE},
    \"score\": {
      \"total\": ${SCORE},
      \"max\": ${MAX_SCORE},
      \"label\": \"${SCORE_LABEL}\",
      \"components\": {
        \"backupFreshness\": ${SCORE_BACKUP},
        \"rtoPerformance\": ${SCORE_RTO},
        \"rpoCompliance\": ${SCORE_RPO},
        \"scheduleHealth\": ${SCORE_SCHED},
        \"drillExecution\": ${SCORE_DRILL}
      }
    },
    \"recoveryMetrics\": {
      \"lastBackupAge\": \"${LAST_BACKUP_AGE}\",
      \"lastBackupAgeSeconds\": ${LAST_BACKUP_AGE_SEC:-0},
      \"rto\": \"${LATEST_RTO}\",
      \"rtoSeconds\": ${LATEST_RTO_SEC:-0},
      \"rpo\": \"${RPO_HUMAN:-N/A}\",
      \"rpoSeconds\": ${RPO_SEC:-0}
    },
    \"schedules\": ["

FIRST=true
for sched in "${SCHEDULE_RESULTS[@]}"; do
  IFS='|' read -r name result age <<< "${sched}"
  if [ "${FIRST}" = true ]; then
    FIRST=false
  else
    JSON_CONTENT="${JSON_CONTENT},"
  fi
  JSON_CONTENT="${JSON_CONTENT}
      {\"name\": \"${name}\", \"result\": \"${result}\", \"age\": \"${age}\"}"
done

JSON_CONTENT="${JSON_CONTENT}
    ],
    \"checks\": {
      \"passed\": ${PASS},
      \"failed\": ${FAIL},
      \"warnings\": ${WARN}
    }
  }
}"

echo "${JSON_CONTENT}" > "${JSON_FILE}"
info "JSON report: ${JSON_FILE}"

# ── Generate HTML Report ──────────────────────────────────────

if [ "${HTML}" = true ]; then
  SCHED_HTML=""
  for sched in "${SCHEDULE_RESULTS[@]}"; do
    IFS='|' read -r name result age <<< "${sched}"
    case "${result}" in
      PASS) icon="&#9989;" ;;
      FAIL) icon="&#10060;" ;;
      WARN) icon="&#9888;" ;;
      *) icon="&#10067;" ;;
    esac
    SCHED_HTML="${SCHED_HTML}
        <tr><td>${name}</td><td>${age}</td><td>${icon} ${result}</td></tr>"
  done

  HEALTH_ICON="&#9989;"
  HEALTH_CLASS="pass"
  HEALTH_TEXT="All DR checks passing"
  if [ "${FAIL}" -gt 0 ]; then
    HEALTH_ICON="&#10060;"
    HEALTH_CLASS="fail"
    HEALTH_TEXT="${FAIL} checks require attention"
  fi

  cat > "${HTML_FILE}" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>DR Report — ${TIMESTAMP}</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 2rem; background: #f8f9fa; color: #333; }
  h1 { color: #1a1a2e; border-bottom: 3px solid #e94560; padding-bottom: 0.5rem; }
  h2 { color: #16213e; margin-top: 2rem; }
  table { border-collapse: collapse; width: 100%; margin: 1rem 0; background: white; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
  th, td { padding: 0.75rem 1rem; text-align: left; border-bottom: 1px solid #e9ecef; }
  th { background: #1a1a2e; color: white; font-weight: 600; }
  tr:hover { background: #f1f3f5; }
  .score { font-size: 2.5rem; font-weight: bold; padding: 1rem; border-radius: 8px; text-align: center; }
  .score.ready { background: #d4edda; color: #155724; }
  .score.degraded { background: #fff3cd; color: #856404; }
  .score.critical { background: #f8d7da; color: #721c24; }
  .pass { color: #28a745; }
  .fail { color: #dc3545; }
  .warn { color: #ffc107; }
  .summary { display: flex; gap: 1rem; margin: 1rem 0; }
  .summary-card { flex: 1; padding: 1rem; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); text-align: center; }
  .summary-card h3 { margin: 0 0 0.5rem; font-size: 0.9rem; text-transform: uppercase; color: #6c757d; }
  .summary-card .value { font-size: 1.8rem; font-weight: bold; }
  .footer { margin-top: 2rem; padding: 1rem; background: #e9ecef; border-radius: 8px; font-size: 0.9rem; color: #6c757d; }
</style>
</head>
<body>
<h1>&#9881; DR Report — ${TIMESTAMP}</h1>

<div class="summary">
  <div class="summary-card">
    <h3>Readiness Score</h3>
    <div class="value score ${SCORE_LABEL,,}">${SCORE}/${MAX_SCORE}</div>
    <div>${SCORE_LABEL}</div>
  </div>
  <div class="summary-card">
    <h3>Passed</h3>
    <div class="value pass">${PASS}</div>
  </div>
  <div class="summary-card">
    <h3>Failed</h3>
    <div class="value fail">${FAIL}</div>
  </div>
  <div class="summary-card">
    <h3>Warnings</h3>
    <div class="value warn">${WARN}</div>
  </div>
</div>

<h2>&#128202; Backup Schedules</h2>
<table>
  <tr><th>Schedule</th><th>Age</th><th>Status</th></tr>
  ${SCHED_HTML}
</table>

<h2>&#128200; Recovery Metrics</h2>
<table>
  <tr><th>Metric</th><th>Value</th><th>SLO Target</th><th>Result</th></tr>
  <tr>
    <td>Last Backup Age</td><td>${LAST_BACKUP_AGE}</td><td>&lt; 24h</td>
    <td>$([ -n "${LAST_BACKUP_AGE_SEC:-0}" ] && [ "${LAST_BACKUP_AGE_SEC:-0}" -lt 86400 ] && echo '&#9989;' || echo '&#10060;')</td>
  </tr>
  <tr>
    <td>RTO (Last Drill)</td><td>${LATEST_RTO}</td><td>&lt; 10min</td>
    <td>$([ "${LATEST_RTO_SEC:-0}" -lt 600 ] && echo '&#9989;' || echo '&#10060;')</td>
  </tr>
  <tr>
    <td>RPO (Current)</td><td>${RPO_HUMAN:-N/A}</td><td>&lt; 24h</td>
    <td>$([ -n "${RPO_SEC:-0}" ] && [ "${RPO_SEC:-0}" -lt 86400 ] && echo '&#9989;' || echo '&#10060;')</td>
  </tr>
</table>

<h2>&#128202; Score Breakdown</h2>
<table>
  <tr><th>Component</th><th>Score</th><th>Max</th></tr>
  <tr><td>Backup Freshness</td><td>${SCORE_BACKUP}</td><td>40</td></tr>
  <tr><td>RTO Performance</td><td>${SCORE_RTO}</td><td>15</td></tr>
  <tr><td>RPO Compliance</td><td>${SCORE_RPO}</td><td>15</td></tr>
  <tr><td>Schedule Health</td><td>${SCORE_SCHED}</td><td>15</td></tr>
  <tr><td>Drill Execution</td><td>${SCORE_DRILL}</td><td>15</td></tr>
  <tr style="font-weight: bold;"><td>Total</td><td>${SCORE}</td><td>${MAX_SCORE}</td></tr>
</table>

<h2>&#128221; Overall Verdict</h2>
<div class="footer">
  <p><strong>Readiness:</strong> ${SCORE_LABEL} (${SCORE}/${MAX_SCORE})</p>
  <p><strong>Result:</strong> <span class="${HEALTH_CLASS}">${HEALTH_ICON} ${HEALTH_TEXT}</span></p>
  <p><em>Generated: ${TIMESTAMP} | Velero: $([ "${VELERO_AVAILABLE}" = true ] && echo "Available" || echo "Unavailable")</em></p>
</div>
</body>
</html>
EOF
  info "HTML report: ${HTML_FILE}"
fi

# ── Final Summary ──────────────────────────────────────────────

TOTAL_CHECKS=$(( PASS + FAIL + WARN ))

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  DR REPORT COMPLETE"
echo "  Score: ${SCORE}/${MAX_SCORE} (${SCORE_LABEL})"
echo "  Passed: ${PASS} | Failed: ${FAIL} | Warnings: ${WARN}"
echo "  Report: ${REPORT_FILE}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ "${CI_MODE}" = true ] && [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
