#!/usr/bin/env bash
# restore-jenkins.sh — Restore Jenkins configuration from backup
# SecureRAG Hub — Jenkins Disaster Recovery
#
# Usage:
#   bash scripts/jenkins/restore-jenkins.sh <backup-file>
#
# Example:
#   bash scripts/jenkins/restore-jenkins.sh /tmp/jenkins-backup/jenkins-backup-20250101-120000.tar.gz
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <backup-file>"
  echo "Example: $0 /tmp/jenkins-backup/jenkins-backup-20250101-120000.tar.gz"
  exit 1
fi

BACKUP_FILE="$1"
JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

echo ""
echo "═══ Jenkins Restore ═══"
echo "Backup: ${BACKUP_FILE}"
echo "Target: ${JENKINS_HOME}"
echo ""

# Validate backup file
if [ ! -f "${BACKUP_FILE}" ]; then
  error "Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

if ! tar tzf "${BACKUP_FILE}" >/dev/null 2>&1; then
  error "Backup file is corrupted or invalid"
  exit 1
fi

FILE_COUNT=$(tar tzf "${BACKUP_FILE}" 2>/dev/null | wc -l)
info "Backup validated: ${FILE_COUNT} files"

# Check if Jenkins is running
if command -v kubectl &>/dev/null; then
  JENKINS_POD=$(kubectl get pod -n jenkins-agents -l app.kubernetes.io/name=jenkins -o name 2>/dev/null || echo "")
  if [ -n "${JENKINS_POD}" ]; then
    warn "Jenkins pod is running. Recommend stopping it before restore."
    warn "  kubectl scale deployment jenkins -n jenkins-agents --replicas=0"
    read -rp "Continue anyway? (y/N): " CONFIRM
    if [ "${CONFIRM}" != "y" ] && [ "${CONFIRM}" != "Y" ]; then
      echo "Aborted."
      exit 0
    fi
  fi
fi

# Create backup of current state (just in case)
CURRENT_BACKUP="/tmp/jenkins-pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
if [ -d "${JENKINS_HOME}" ] && [ -n "$(ls -A "${JENKINS_HOME}" 2>/dev/null)" ]; then
  info "Backing up current Jenkins state to ${CURRENT_BACKUP}..."
  tar czf "${CURRENT_BACKUP}" -C "${JENKINS_HOME}" . 2>/dev/null || warn "Could not backup current state"
fi

# Restore
info "Restoring from backup..."
if [ -d "${JENKINS_HOME}" ]; then
  rm -rf "${JENKINS_HOME:?}"/*
fi
mkdir -p "${JENKINS_HOME}"
tar xzf "${BACKUP_FILE}" -C "${JENKINS_HOME}" 2>/dev/null

# Verify
RESTORED_COUNT=$(find "${JENKINS_HOME}" -maxdepth 3 -type f 2>/dev/null | wc -l)
info "Restored ${RESTORED_COUNT} files to ${JENKINS_HOME}"

# Set permissions
chown -R 1000:1000 "${JENKINS_HOME}" 2>/dev/null || true

echo ""
echo "═══ Restore Summary ═══"
echo "✅ Restore completed"
echo "Backup: ${BACKUP_FILE}"
echo "Files restored: ${RESTORED_COUNT}"
echo ""
echo "Next steps:"
echo "  1. Restart Jenkins"
echo "  2. kubectl scale deployment jenkins -n jenkins-agents --replicas=1"
echo "  3. Wait for Jenkins to start"
echo "  4. Verify: kubectl logs -n jenkins-agents deployment/jenkins"
echo ""
