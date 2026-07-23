#!/usr/bin/env bash
# collect-coverage.sh — SecureRAG Hub
# Fusionne les rapports Clover des 5 applications Laravel en un seul
# coverage.xml exploitable par SonarQube. Applique le seuil minimum.
#
# Prérequis : run-tests.sh a été exécuté avec succès.
# Sorties :
#   .coverage-artifacts/coverage.xml        (fusionné — pour SonarQube)
#   .coverage-artifacts/coverage-summary.txt (statut + pourcentage)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARTIFACT_DIR="${REPO_ROOT}/.coverage-artifacts"
COVERAGE_XML="${ARTIFACT_DIR}/coverage.xml"
SUMMARY_FILE="${ARTIFACT_DIR}/coverage-summary.txt"
MIN_COVERAGE="${COVERAGE_MIN:-80}"

mkdir -p "${ARTIFACT_DIR}"

# ── 1. Vérifier que les fichiers source existent ────────────────────────

source_files=("${ARTIFACT_DIR}"/coverage-*.xml)
shopt -s nullglob
existing_files=("${ARTIFACT_DIR}"/coverage-*.xml)
shopt -u nullglob

if [[ ${#existing_files[@]} -eq 0 ]]; then
  {
    echo "coverage_percent=0"
    echo "coverage_minimum=${MIN_COVERAGE}"
    echo "status=failed-no-coverage-files"
  } > "${SUMMARY_FILE}"
  echo "[FATAL] No per-app coverage files found in ${ARTIFACT_DIR}" >&2
  echo "[FATAL] Run 'bash scripts/ci/run-tests.sh' first." >&2
  exit 1
fi

echo "[INFO] Found ${#existing_files[@]} per-app coverage file(s):"
for f in "${existing_files[@]}"; do
  echo "  - $(basename "${f}")"
done

# ── 2. Fusion des fichiers Clover en un seul coverage.xml ───────────────
# Utilise un script Python qui parse le XML et fusionne les métriques.
# Le format Clover utilisé par SonarQube : <coverage generated="..." clover="...">
#   <project><metrics .../><package name="app">...</package></project>

python3 - "${ARTIFACT_DIR}" "${COVERAGE_XML}" <<'PYEOF'
import sys
import os
import glob
import xml.etree.ElementTree as ET
from datetime import datetime

artifact_dir = sys.argv[1]
output_file = sys.argv[2]

# Collect all per-app coverage files
pattern = os.path.join(artifact_dir, "coverage-*.xml")
files = sorted(glob.glob(pattern))

if not files:
    print("FATAL: No coverage files to merge", file=sys.stderr)
    sys.exit(1)

# Search for a base file containing a <project> element (Clover XML format)
base_tree = None
base_root = None
base_project = None

for f in files:
    try:
        t = ET.parse(f)
        r = t.getroot()
        p = r.find(".//project")
        if p is not None:
            base_tree = t
            base_root = r
            base_project = p
            break
    except Exception:
        pass

if base_root is None:
    base_tree = ET.parse(files[0])
    base_root = base_tree.getroot()

# Collect all <package> elements from all files
all_packages = []
all_metrics = {
    "files": 0, "loc": 0, "ncloc": 0,
    "classes": 0, "methods": 0, "coveredmethods": 0,
    "conditionals": 0, "coveredconditionals": 0,
    "statements": 0, "coveredstatements": 0,
    "elements": 0, "coveredelements": 0
}

# Get timestamp from base
generated = base_root.get("generated", str(int(datetime.now().timestamp())))

# Find <metrics> in base project for structure if available
base_metrics_el = base_project.find("metrics") if base_project is not None else None

for f in files:
    try:
        tree = ET.parse(f)
        root = tree.getroot()
        project = root.find(".//project")
        if project is not None:
            # Collect packages from Clover format
            for pkg in project.findall("package"):
                all_packages.append(pkg)

            # Aggregate metrics
            metrics_el = project.find("metrics")
            if metrics_el is not None:
                for key in all_metrics:
                    val = metrics_el.get(key, "0")
                    try:
                        all_metrics[key] += int(val)
                    except (ValueError, TypeError):
                        pass
        else:
            # Collect packages from Cobertura format (e.g., Python pytest-cov)
            for pkg in root.findall(".//package"):
                all_packages.append(pkg)
            lines_valid = root.get("lines-valid")
            lines_covered = root.get("lines-covered")
            if lines_valid and lines_covered:
                try:
                    all_metrics["statements"] += int(lines_valid)
                    all_metrics["coveredstatements"] += int(lines_covered)
                except (ValueError, TypeError):
                    pass
    except ET.ParseError as e:
        print(f"WARN: Failed to parse {f}: {e}", file=sys.stderr)

# Calculate combined line rate
if all_metrics["statements"] > 0:
    line_rate = all_metrics["coveredstatements"] / all_metrics["statements"]
else:
    # Fallback: use elements
    if all_metrics["elements"] > 0:
        line_rate = all_metrics["coveredelements"] / all_metrics["elements"]
    else:
        line_rate = 0.0

line_rate = round(line_rate, 4)

# Build merged XML
ns = "https://schema.atlassian.com/clover/report/1.1" if base_root.tag.startswith("coverage") else ""
coverage = ET.Element("coverage", {
    "generated": generated,
    "clover": "3.2.0"
})

project_el = ET.SubElement(coverage, "project", {
    "name": "SecureRAG Hub (merged)",
    "timestamp": str(int(datetime.now().timestamp()))
})

metrics_el = ET.SubElement(project_el, "metrics", {
    "files": str(all_metrics["files"]),
    "loc": str(all_metrics["loc"]),
    "ncloc": str(all_metrics["ncloc"]),
    "classes": str(all_metrics["classes"]),
    "methods": str(all_metrics["methods"]),
    "coveredmethods": str(all_metrics["coveredmethods"]),
    "conditionals": str(all_metrics["conditionals"]),
    "coveredconditionals": str(all_metrics["coveredconditionals"]),
    "statements": str(all_metrics["statements"]),
    "coveredstatements": str(all_metrics["coveredstatements"]),
    "elements": str(all_metrics["elements"]),
    "coveredelements": str(all_metrics["coveredelements"])
})

for pkg in all_packages:
    project_el.append(pkg)

tree = ET.ElementTree(coverage)
ET.indent(tree, space="  ")
tree.write(output_file, encoding="utf-8", xml_declaration=True)

coverage_percent = line_rate * 100
print(f"[INFO] Merged {len(files)} coverage files -> {output_file}")
print(f"[INFO] Combined: {all_metrics['files']} files, {all_metrics['statements']} statements, {all_metrics['coveredstatements']} covered")
print(f"[INFO] Global line-rate: {line_rate} ({coverage_percent:.2f}%)")
PYEOF

merge_exit=$?
if [[ "${merge_exit}" -ne 0 ]]; then
  echo "[FATAL] Coverage merge failed (exit code ${merge_exit})" >&2
  exit 1
fi

# ── 3. Calculer la couverture et appliquer le seuil ─────────────────────

# Extraire line-rate du fichier fusionné
line_rate=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('${COVERAGE_XML}')
project = tree.getroot().find('.//project')
if project is not None:
    metrics = project.find('metrics')
    if metrics is not None:
        stmts = int(metrics.get('statements', 0))
        covered = int(metrics.get('coveredstatements', 0))
        if stmts > 0:
            print(covered / stmts)
        else:
            print('0')
    else:
        print('0')
else:
    print('0')
" 2>/dev/null || echo "0")

coverage_percent=$(python3 -c "print(round(float(${line_rate:-0}) * 100, 2))" 2>/dev/null || echo "0")

# ── 4. Écrire le résumé ─────────────────────────────────────────────────

{
  echo "coverage_percent=${coverage_percent}"
  echo "coverage_minimum=${MIN_COVERAGE}"
  if python3 -c "exit(0 if float(${coverage_percent}) >= float(${MIN_COVERAGE}) else 1)" 2>/dev/null; then
    echo "status=passed"
  else
    echo "status=failed-below-threshold"
  fi
} > "${SUMMARY_FILE}"

echo "[INFO] Coverage summary written to ${SUMMARY_FILE}"

# ── 5. Vérifier le seuil ────────────────────────────────────────────────

echo ""
echo "═════════════════════════════════════════════════"
echo "  Coverage Gate"
echo "═════════════════════════════════════════════════"
printf "  Global coverage : %s%%\n" "${coverage_percent}"
printf "  Minimum required: %s%%\n" "${MIN_COVERAGE}"
echo "═════════════════════════════════════════════════"

if python3 -c "exit(0 if float(${coverage_percent}) >= float(${MIN_COVERAGE}) else 1)" 2>/dev/null; then
  echo "[PASS] Coverage threshold satisfied."
  exit 0
fi

echo "[FAIL] Coverage ${coverage_percent}% is below the required ${MIN_COVERAGE}%."
exit 1
