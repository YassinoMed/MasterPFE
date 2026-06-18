#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# cis-benchmark.sh — Point d'entrée unifié pour exécuter le CIS Benchmark
# et parser les résultats en une seule commande.
# Usage: ./cis-benchmark.sh [--cron] [--output-dir <dir>]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Par défaut, exécuter le benchmark puis parser
bash "${SCRIPT_DIR}/run-cis-benchmark.sh" "$@"
