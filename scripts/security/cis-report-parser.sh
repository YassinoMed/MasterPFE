#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# cis-report-parser.sh — Analyse les résultats JSON de kube-bench
# et génère un rapport Markdown avec catégorisation, scores et alertes.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

INPUT_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

if [ -z "${INPUT_FILE}" ] || [ -z "${OUTPUT_FILE}" ]; then
  echo "Usage: $0 <kube-bench-json-input> <markdown-output>"
  exit 1
fi

if [ ! -f "${INPUT_FILE}" ]; then
  echo "ERROR: Input file not found: ${INPUT_FILE}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── Parser le JSON et générer le rapport via Python ─────────────────────────
python3 << PYEOF
import json, sys, os
from datetime import datetime

with open("${INPUT_FILE}") as f:
    data = json.load(f)

if isinstance(data, dict):
    data = data.get("checks", data.get("Controls", [data]))

controls_category = {
    "1": "Master Node Security Configuration",
    "1.1": "Master Node Configuration Files",
    "1.2": "API Server",
    "1.3": "Controller Manager",
    "1.4": "Scheduler",
    "2": "etcd Node Configuration",
    "3": "Control Plane Configuration",
    "4": "Worker Node Security Configuration",
    "4.1": "Worker Node Configuration Files",
    "4.2": "Kubelet",
    "5": "Kubernetes Policies",
    "5.1": "RBAC and Service Accounts",
    "5.2": "Pod Security Standards",
    "5.3": "Network Policies and CNI",
    "5.4": "Secrets Management",
}

def categorize(control_id):
    for prefix, name in sorted(controls_category.items(), key=lambda x: -len(x[0])):
        if control_id.startswith(prefix):
            return name
    return "Other"

categories = {}
total_pass = 0
total_fail = 0
total_warn = 0
total_info = 0
critical_fails = []

for control in data if isinstance(data, list) else []:
    control_id = str(control.get("id", control.get("number", "")))
    control_text = control.get("text", control.get("description", ""))
    cat_name = categorize(control_id)

    if cat_name not in categories:
        categories[cat_name] = {"pass": 0, "fail": 0, "warn": 0, "info": 0, "tests": []}

    checks = control.get("checks", control.get("results", []))
    for test in checks:
        test_id = test.get("id", test.get("number", ""))
        test_desc = test.get("text", test.get("description", ""))
        status = test.get("status", "INFO").upper()
        scored = test.get("scored", test.get("flag", True))
        remediation = test.get("remediation", "")
        impact = test.get("impact", "")

        categories[cat_name]["tests"].append({
            "id": test_id,
            "desc": test_desc,
            "status": status,
            "scored": scored,
            "remediation": remediation,
            "impact": impact,
        })

        if status == "PASS":
            total_pass += 1
            categories[cat_name]["pass"] += 1
        elif status == "FAIL":
            total_fail += 1
            categories[cat_name]["fail"] += 1
            if scored:
                critical_fails.append(test_id)
        elif status == "WARN":
            total_warn += 1
            categories[cat_name]["warn"] += 1
        elif status == "INFO":
            total_info += 1
            categories[cat_name]["info"] += 1

total_checks = total_pass + total_fail + total_warn + total_info
compliance_pct = round((total_pass / total_checks * 100), 2) if total_checks > 0 else 0

# ── Génération Markdown ───────────────────────────────────────────────────
md = []
md.append(f"# CIS Kubernetes Benchmark Report — SecureRAG Hub")
md.append(f"")
md.append(f"**Date :** {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}")
md.append(f"")
md.append(f"## Résumé Global")
md.append(f"")
md.append(f"| Métrique | Valeur |")
md.append(f"|----------|--------|")
md.append(f"| Total Checks | {total_checks} |")
md.append(f"| ✅ PASS | {total_pass} |")
md.append(f"| ❌ FAIL | {total_fail} |")
md.append(f"| ⚠️ WARN | {total_warn} |")
md.append(f"| ℹ️ INFO | {total_info} |")
md.append(f"| **Conformité** | **{compliance_pct}%** |")
md.append(f"")

if critical_fails:
    md.append(f"## 🚨 Échecs Critiques ({len(critical_fails)})")
    md.append(f"")
    for cf in critical_fails:
        md.append(f"- ❌ **{cf}** — voir détails ci-dessous")
    md.append(f"")

# ── Score de conformité visuel ────────────────────────────────────────────
bar_len = 40
filled = int(bar_len * compliance_pct / 100)
empty = bar_len - filled
bar = "█" * filled + "░" * empty
md.append(f"**Score de conformité :** {compliance_pct}%")
md.append(f"")
md.append(f"`{bar}`")
md.append(f"")

# ── Détails par catégorie ──────────────────────────────────────────────────
md.append(f"## Détails par Catégorie")
md.append(f"")

for cat_name in sorted(categories.keys()):
    cat = categories[cat_name]
    total_cat = cat["pass"] + cat["fail"] + cat["warn"] + cat["info"]
    cat_pct = round((cat["pass"] / total_cat * 100), 1) if total_cat > 0 else 0

    md.append(f"### {cat_name}")
    md.append(f"")
    md.append(f"| Statut | Nombre |")
    md.append(f"|--------|--------|")
    md.append(f"| ✅ PASS | {cat['pass']} |")
    md.append(f"| ❌ FAIL | {cat['fail']} |")
    md.append(f"| ⚠️ WARN | {cat['warn']} |")
    md.append(f"| ℹ️ INFO | {cat['info']} |")
    md.append(f"| **Total** | **{total_cat}** |")
    md.append(f"| **Score** | **{cat_pct}%** |")
    md.append(f"")

    # Détail des tests FAIL
    failures = [t for t in cat["tests"] if t["status"] == "FAIL"]
    if failures:
        md.append(f"#### Tests en échec")
        md.append(f"")
        md.append(f"| ID | Description | Remédiation |")
        md.append(f"|----|-------------|-------------|")
        for t in failures:
            desc = t["desc"][:100] + "..." if len(t["desc"]) > 100 else t["desc"]
            remediation = t["remediation"][:150] + "..." if len(t["remediation"]) > 150 else t["remediation"]
            md.append(f"| {t['id']} | {desc} | {remediation} |")
        md.append(f"")

    # Détail des tests WARN
    warns = [t for t in cat["tests"] if t["status"] == "WARN"]
    if warns:
        md.append(f"#### Tests avec avertissement")
        md.append(f"")
        md.append(f"| ID | Description |")
        md.append(f"|----|-------------|")
        for t in warns:
            desc = t["desc"][:100] + "..." if len(t["desc"]) > 100 else t["desc"]
            md.append(f"| {t['id']} | {desc} |")
        md.append(f"")

# ── Recommendations ──────────────────────────────────────────────────────
md.append(f"## Recommandations")
md.append(f"")
md.append(f"1. **Priorité haute** : Corriger les {len(critical_fails)} échecs critiques identifiés ci-dessus.")
md.append(f"2. **RBAC** : Vérifier que les roles et clusterroles suivent le principe du moindre privilège.")
md.append(f"3. **Pods Security** : Appliquer les Pod Security Standards au niveau `restricted` sur tous les namespaces.")
md.append(f"4. **Network Policies** : Vérifier qu'un réseau policy par défaut bloque tout le trafic entrant non autorisé.")
md.append(f"5. **etcd** : S'assurer que etcd est chiffré et que l'authentification TLS mutuelle est activée.")
md.append(f"6. **Audit Logs** : Configurer l'audit logging de l'API Server avec une politique complète.")
md.append(f"7. **Automatisation** : Ce benchmark est exécuté automatiquement chaque lundi à 6h via le CronJob `cis-benchmark`.")
md.append(f"")
md.append(f"---")
md.append(f"")
md.append(f"*Rapport généré automatiquement par `run-cis-benchmark.sh` le {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC*")

with open("${OUTPUT_FILE}", "w") as f:
    f.write("\n".join(md) + "\n")

print(f"Report written to ${OUTPUT_FILE}")
print(f"Compliance: {compliance_pct}%")
print(f"Pass: {total_pass}, Fail: {total_fail}, Warn: {total_warn}, Info: {total_info}")
PYEOF
