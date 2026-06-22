#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap-recette-ssh.sh — Generate or prepare SSH credentials for the
# recette (staging) machine deployment. The private key is stored inside
# the Jenkins secrets directory so the Docker Compose volume mount makes it
# available to the Jenkins container.
#
# Usage:
#   bash scripts/jenkins/bootstrap-recette-ssh.sh
#
# Environment:
#   JENKINS_SECRETS_DIR  — Where to store the key  (default: infra/jenkins/secrets)
#   RECETTE_HOST         — Recette machine IP       (default: 83.229.82.46)
#   RECETTE_USER         — SSH user                 (default: root)
#   SSH_KEY_TYPE         — Key type                  (default: ed25519)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

JENKINS_SECRETS_DIR="${JENKINS_SECRETS_DIR:-infra/jenkins/secrets}"
RECETTE_HOST="${RECETTE_HOST:-83.229.82.46}"
RECETTE_USER="${RECETTE_USER:-root}"
SSH_KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"
SSH_KEY_FILE="${JENKINS_SECRETS_DIR}/recette-deploy-key"
SSH_PUB_FILE="${SSH_KEY_FILE}.pub"

info()  { printf '[INFO] %s\n' "$*"; }
warn()  { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

mkdir -p "${JENKINS_SECRETS_DIR}"
umask 077

# ── Generate SSH key pair ─────────────────────────────────────────────────
if [[ -f "${SSH_KEY_FILE}" ]]; then
  info "SSH deploy key already exists at ${SSH_KEY_FILE}"
else
  info "Generating SSH deploy key (${SSH_KEY_TYPE}) for recette deployment"
  ssh-keygen -t "${SSH_KEY_TYPE}" \
    -C "jenkins-deploy@securerag-hub" \
    -f "${SSH_KEY_FILE}" \
    -N "" \
    -q
  info "SSH key pair generated:"
  info "  Private: ${SSH_KEY_FILE}"
  info "  Public:  ${SSH_PUB_FILE}"
fi

chmod 600 "${SSH_KEY_FILE}"
[[ -f "${SSH_PUB_FILE}" ]] && chmod 644 "${SSH_PUB_FILE}"

# ── Display public key and instructions ───────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "  SSH Deploy Key — Setup Instructions"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "  1. Copy the public key below to the recette machine:"
echo ""
echo "     ssh-copy-id -i ${SSH_PUB_FILE} ${RECETTE_USER}@${RECETTE_HOST}"
echo ""
echo "     Or manually append to ${RECETTE_USER}@${RECETTE_HOST}:~/.ssh/authorized_keys :"
echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
cat "${SSH_PUB_FILE}" | sed 's/^/  │ /'
echo ""
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  2. Test connectivity:"
echo ""
echo "     ssh -i ${SSH_KEY_FILE} ${RECETTE_USER}@${RECETTE_HOST} 'echo OK'"
echo ""
echo "  3. The Jenkins container will automatically mount this key via"
echo "     docker-compose.yml volume."
echo ""
echo "═══════════════════════════════════════════════════════════════════════"

# ── Verify connectivity (optional) ───────────────────────────────────────
if [[ "${VERIFY_SSH:-false}" == "true" ]]; then
  info "Verifying SSH connectivity to ${RECETTE_USER}@${RECETTE_HOST}..."
  if ssh -i "${SSH_KEY_FILE}" \
       -o StrictHostKeyChecking=no \
       -o ConnectTimeout=10 \
       "${RECETTE_USER}@${RECETTE_HOST}" \
       'echo "SSH_VERIFY_OK"' 2>/dev/null | grep -q "SSH_VERIFY_OK"; then
    info "SSH connectivity: OK ✓"
  else
    warn "SSH connectivity: FAILED"
    warn "Please copy the public key to the recette machine first."
  fi
fi

info "SSH deploy credentials prepared in ${JENKINS_SECRETS_DIR}"
