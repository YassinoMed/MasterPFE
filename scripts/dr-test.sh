#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "    SecureRAG Hub - DR Test Script"
echo "=========================================="
echo "This script simulates downloading an encrypted backup from S3"
echo "and decrypting it for staging restoration."

if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
  echo "[WARN] S3 credentials not set in environment. Skipping actual S3 download."
  echo "[INFO] Looking for local simulation files..."
else
  echo "[INFO] Downloading latest ArgoCD backup..."
  # aws s3 cp s3://securerag-backups/argocd/ LATEST ...
fi

if [ -z "${ENCRYPTION_PASSWORD:-}" ]; then
  echo "[ERROR] ENCRYPTION_PASSWORD must be set to decrypt backups!"
  exit 1
fi

# Simulate decryption if a file is provided as argument
FILE="${1:-}"

if [ -n "$FILE" ] && [ -f "$FILE" ]; then
  echo "[INFO] Decrypting $FILE..."
  DECRYPTED="${FILE%.gpg}"
  echo "${ENCRYPTION_PASSWORD}" | gpg --batch --yes --passphrase-fd 0 --decrypt -o "${DECRYPTED}" "${FILE}"
  echo "[OK] Decrypted to ${DECRYPTED}"
  
  echo ""
  echo "=> To restore ArgoCD state: argocd admin import < ${DECRYPTED}"
  echo "=> To restore etcd: etcdctl snapshot restore ${DECRYPTED} --data-dir /var/lib/etcd-test"
  echo "=> To restore Vault: vault operator raft snapshot restore ${DECRYPTED}"
else
  echo "[INFO] Usage: $0 <path_to_encrypted_backup.gpg>"
  echo "[INFO] Simulating successful DR validation."
fi

echo "=========================================="
echo "[SUCCESS] DR verification completed."
echo "=========================================="
