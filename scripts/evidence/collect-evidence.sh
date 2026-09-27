#!/bin/bash
# collect-evidence.sh — Collecte automatisée des preuves de sécurité
# Phase 17 : exporte toutes les données dans un format auditable.
set -euo pipefail

DIR="evidence/$(date +%Y-%m-%d)"
mkdir -p "$DIR"

info() { printf "[EVIDENCE] %s\n" "$*"; }

info "=== COLLECTE DES PREUVES ==="

# 1. État ArgoCD
info "1. ArgoCD applications..."
kubectl get applications -n argocd -o wide > "$DIR/argocd-apps.txt"

# 2. Pods (tous namespaces)
info "2. Pods..."
kubectl get pods -A -o wide > "$DIR/pods-all.txt"

# 3. Kyverno policies
info "3. Kyverno policies..."
kubectl get clusterpolicies -o wide > "$DIR/kyverno-policies.txt"

# 4. NetworkPolicies
info "4. NetworkPolicies..."
kubectl get netpol -A > "$DIR/networkpolicies.txt"

# 5. Trivy VulnerabilityReports
info "5. VulnerabilityReports..."
kubectl get vulnerabilityreports -A -o wide > "$DIR/trivy-vulnreports.txt"

# 6. Trivy ConfigAuditReports
info "6. ConfigAuditReports..."
kubectl get configauditreports -A -o wide > "$DIR/trivy-configaudits.txt"

# 7. Falco events (dernières 24h)
info "7. Falco events..."
kubectl logs -n falco -l app.kubernetes.io/name=falco --since=24h > "$DIR/falco-events-24h.log" 2>/dev/null || true

# 8. État Vault
info "8. Vault..."
kubectl exec -n vault securerag-vault-0 -- vault status > "$DIR/vault-status.txt" 2>/dev/null || true

# 9. Audit log kube-apiserver (compteur)
info "9. Audit log..."
docker exec securerag-dev-control-plane wc -l /var/log/kubernetes/audit.log > "$DIR/audit-log-count.txt" 2>/dev/null || true

# 10. DORA metrics (extraction rapide)
info "10. DORA metrics..."
{
  echo "Deployment Frequency: $(kubectl get applications -n argocd --no-headers | wc -l) apps"
  echo "Synced: $(kubectl get applications -n argocd --no-headers -o custom-columns=':.status.sync.status' | grep -c Synced || echo 0)"
  echo "Failed: $(kubectl get applications -n argocd --no-headers -o custom-columns=':.status.sync.status' | grep -c OutOfSync || echo 0)"
  echo "Git commits 24h: $(git log --since='24 hours ago' --oneline | wc -l)"
} > "$DIR/dora-snapshot.txt"

# 11. Backup status
info "11. Velero backups..."
kubectl get backups -n velero > "$DIR/velero-backups.txt" 2>/dev/null || echo "no backups" > "$DIR/velero-backups.txt"

# 12. Git log (derniers commits)
info "12. Git history..."
git log --oneline -30 > "$DIR/git-log-recent.txt"

# Index
info "Génération de l'index..."
cat > "$DIR/INDEX.md" << INDEX
# Evidence Index — $(date -u +"%Y-%m-%d")

| Fichier | Contenu | Taille |
|---|---|---|
INDEX
for f in "$DIR"/*; do
  fname=$(basename "$f")
  [ "$fname" = "INDEX.md" ] && continue
  fsize=$(wc -c < "$f")
  echo "| $fname | $(echo $fname | sed 's/\.txt\|\.log\|\.md//;s/-/ /g;s/\b\(.\)/\U\1/g') | ${fsize}B |" >> "$DIR/INDEX.md"
done

info "=== $(ls "$DIR" | wc -l) fichiers collectés dans $DIR/ ==="
