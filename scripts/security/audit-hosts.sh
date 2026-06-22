#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# audit-hosts.sh — Déploie et exécute un audit de sécurité sur l'hôte (Jenkins/Docker)
# Utilise Lynis pour un audit ponctuel. Wazuh SCA est géré via l'agent Wazuh.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

log()  { printf '[INFO]  %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

REPORT_DIR="security/reports/host-audit"
mkdir -p "${REPORT_DIR}"

log "Starting Host Security Audit using Lynis..."

# Installation de Lynis (si non présent)
if ! command -v lynis >/dev/null 2>&1; then
    log "Lynis not found. Attempting to install locally for audit..."
    if [ -d "/tmp/lynis" ]; then
        rm -rf /tmp/lynis
    fi
    git clone https://github.com/CISOfy/lynis /tmp/lynis >/dev/null 2>&1
    LYNIS_CMD="/tmp/lynis/lynis"
else
    LYNIS_CMD="lynis"
fi

log "Running Lynis system audit..."
# --pentester évite les délais d'attente (mode non interactif)
sudo ${LYNIS_CMD} audit system --quick --pentester --report-file "${REPORT_DIR}/lynis-report.dat" > "${REPORT_DIR}/lynis-console.log" || true

log "Extracting Lynis warnings and suggestions..."
grep -E '(Warning|Suggestion)' "${REPORT_DIR}/lynis-report.dat" > "${REPORT_DIR}/lynis-findings.txt" || true

# L'agent Wazuh (wazuh-agent) doit être installé sur la machine hôte pour le scan SCA continu.
# L'agent lit la configuration de /var/ossec/etc/ossec.conf pour exécuter "sca".
log "Wazuh SCA is performed continuously by the Wazuh Agent if installed on the host."

log "Host audit completed. Results saved to ${REPORT_DIR}/"
