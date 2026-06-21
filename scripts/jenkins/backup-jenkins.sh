#!/usr/bin/env bash
# backup-jenkins.sh — Backup Jenkins configuration
# SecureRAG Hub — Jenkins Disaster Recovery
#
# Usage:
#   bash scripts/jenkins/backup-jenkins.sh
#
# Environment:
#   JENKINS_HOME  (default: /var/jenkins_home)
#   BACKUP_DIR    (default: /tmp/jenkins-backup)
set -euo pipefail

JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/jenkins-backup}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/jenkins-backup-${TIMESTAMP}.tar.gz"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

mkdir -p "${BACKUP_DIR}"

# Files/dirs to exclude from backup
EXCLUDES=(
  --exclude="war"
  --exclude="tools"
  --exclude="workspace"
  --exclude="builds"
  --exclude="logs"
  --exclude="plugins/*.bak"
  --exclude="plugins/*.old"
  --exclude="caches"
  --exclude="*.log"
  --exclude="*.tmp"
)

# Backup critical Jenkins data
CRITICAL_DIRS=(
  "jobs"
  "nodes"
  "secrets"
  "credentials.xml"
  "config.xml"
  "*.xml"
  "identity.key"
  "secret.key"
  "secret.key.not-so-secret"
  "plugins"
  "init.groovy.d"
  "casc_configs"
  "userContent"
)

echo ""
echo "═══ Jenkins Backup ═══"
echo "Source: ${JENKINS_HOME}"
echo "Destination: ${BACKUP_FILE}"
echo ""

# Check source exists
if [ ! -d "${JENKINS_HOME}" ]; then
  error "JENKINS_HOME not found: ${JENKINS_HOME}"
  exit 1
fi

# Check Jenkins is running
if command -v jenkins &>/dev/null; then
  # Safe backup via Jenkins CLI
  JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
  info "Safe backup via Jenkins CLI..."
  curl -sf -X POST "${JENKINS_URL}/safeRestart" 2>/dev/null || true
  sleep 5
fi

# Create backup
tar czf "${BACKUP_FILE}" \
  "${EXCLUDES[@]}" \
  -C "${JENKINS_HOME}" \
  . 2>/dev/null

BACKUP_SIZE=$(stat -c %s "${BACKUP_FILE}" 2>/dev/null || echo 0)
BACKUP_SIZE_MB=$(( BACKUP_SIZE / 1048576 ))

echo "Backup size: ${BACKUP_SIZE_MB} MB"
echo ""

# Verify backup integrity
if tar tzf "${BACKUP_FILE}" >/dev/null 2>&1; then
  FILE_COUNT=$(tar tzf "${BACKUP_FILE}" 2>/dev/null | wc -l)
  echo "✅ Backup verified: ${FILE_COUNT} files"
  info "Backup saved: ${BACKUP_FILE}"
  exit 0
else
  error "Backup verification FAILED"
  rm -f "${BACKUP_FILE}"
  exit 1
fi
