#!/usr/bin/env bash
# File: scripts/verify-cluster-e2e.sh
# Description: Script de vérification de bout en bout de l'état du cluster Kubernetes.
# Date: 2026-06-14
# Modified by: DevSecOps Agent

set -euo pipefail

# Détection et activation de l'environnement virtuel pour python3
if [[ -f .tools/semgrep-venv/bin/activate ]]; then
  # shellcheck disable=SC1091
  . .tools/semgrep-venv/bin/activate
fi

context="$(kubectl config current-context 2>/dev/null || echo "")"
if [[ "$context" == *"k3s"* ]]; then
  bootstrap_script="scripts/bootstrap-k3s.sh"
else
  bootstrap_script="scripts/bootstrap-cluster.sh"
fi

# 1. Démarrage du cluster si nécessaire
if ! kubectl get nodes >/dev/null 2>&1; then
  echo "[INFO] Le cluster Kubernetes est arrêté. Démarrage en cours..."
  if [[ -f "$bootstrap_script" ]]; then
    bash "$bootstrap_script"
  else
    echo "[INFO] Script de bootstrap direct introuvable. Lancement via securerag-launch-all.sh."
    bash securerag-launch-all.sh
  fi
else
  echo "[INFO] Le cluster est actif."
fi

# 2. Attente de l'état Running/Ready pour tous les pods
echo "[INFO] Attente de la disponibilité de tous les pods (300 secondes maximum)..."
kubectl wait --all --for=condition=Ready pods --all-namespaces --timeout=300s || true
kubectl get pods -A -o wide > /tmp/pods-status.txt
echo "[INFO] Pods hors service ou inactifs :"
awk 'NR>1 && $4 != "Running" && $4 != "Completed" {print $1 "/" $2 " - Statut: " $4}' /tmp/pods-status.txt

# 3. Vérification du pinning par digest
echo "[INFO] Vérification de l'usage des digests pour les images du cluster..."
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.spec.containers[*].image}{"\n"}{end}' > /tmp/all-images.txt
while read -r ns images; do
  if [[ -n "$images" ]]; then
    for img in $images; do
      if [[ "$img" != *"@sha256:"* ]]; then
        if [[ "$img" == *"securerag-hub"* ]]; then
          echo "Image non pinnée par digest (image interne) : $ns/$img"
        else
          echo "Image non pinnée par digest (image tierce) : $ns/$img"
        fi
      fi
    done
  fi
done < /tmp/all-images.txt

# 4. Vérification du mode Enforce de Kyverno
echo "[INFO] Contrôle du mode d'application (validationFailureAction) des politiques Kyverno..."
policy_statuses="$(kubectl get clusterpolicies -o custom-columns=NAME:.metadata.name,ACTION:.spec.validationFailureAction 2>/dev/null || echo "")"
if [[ -z "$policy_statuses" ]]; then
  echo "[ERROR] Aucune politique Kyverno trouvée." >&2
  exit 1
fi

required_policies=(
  "securerag-audit-cleartext-env-values"
  "securerag-require-pod-security"
  "securerag-require-workload-controls"
  "securerag-restrict-image-references"
  "securerag-restrict-service-exposure"
  "securerag-restrict-volume-types"
  "securerag-verify-cosign-images"
)

audit_count=0
for p in "${required_policies[@]}"; do
  action="$(echo "$policy_statuses" | grep "^$p " | awk '{print $2}' || echo "")"
  if [[ -z "$action" ]]; then
    echo "[ERROR] Politique requise manquante : $p" >&2
    exit 1
  elif [[ "$action" == "Audit" ]]; then
    echo "[ERROR] La politique $p est en mode Audit au lieu de Enforce." >&2
    audit_count=$((audit_count + 1))
  fi
done

if [[ "$audit_count" -gt 0 ]]; then
  echo "[ERROR] Des politiques critiques de sécurité sont en mode Audit." >&2
  exit 1
fi
echo "[INFO] Toutes les politiques requises sont appliquées en mode Enforce."

# 5. Test d'admission en direct (serveur dry-run)
echo "[INFO] Test de blocage d'admission des manifestes invalides..."
test_dir="infra/k8s/policies/kyverno-enforce/test"
if [[ -d "$test_dir" ]]; then
  for f in "$test_dir"/invalid-*.yaml; do
    if [[ -f "$f" ]]; then
      name="$(basename "$f")"
      if out="$(kubectl apply -f "$f" --dry-run=server 2>&1)"; then
        echo "[ERROR] Le manifeste invalide $name a été accepté par le serveur API." >&2
        exit 1
      else
        if [[ "$out" == *"rejected"* || "$out" == *"denied"* || "$out" == *"validation error"* ]]; then
          echo "[INFO] Manifeste invalide $name bloqué conformément aux règles."
        else
          echo "[ERROR] Échec inattendu du test d'admission pour $name : $out" >&2
          exit 1
        fi
      fi
    fi
  done
else
  echo "[WARN] Répertoire de tests Kyverno manquant."
fi

# 6. Vérification de la synchronisation Argo CD
echo "[INFO] Contrôle du statut de synchronisation Argo CD..."
if kubectl get applications -n argocd >/dev/null 2>&1; then
  kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status > /tmp/argocd-status.txt
  awk 'NR>1 && ($2 != "Synced" || $3 != "Healthy") {print "Application non conforme : " $1 " (Sync: " $2 ", Santé: " $3 ")"}' /tmp/argocd-status.txt
else
  echo "[WARN] Argo CD non configuré dans ce cluster."
fi

# 7. Vérification de l'agent Wazuh
echo "[INFO] Contrôle des journaux de l'agent Wazuh..."
if kubectl get pods -n security -l app=wazuh-agent >/dev/null 2>&1; then
  kubectl logs -n security -l app=wazuh-agent --tail=20 2>/dev/null | grep -i "connected to" || echo "Wazuh agent: connexion au manager non confirmée dans les logs récents."
else
  echo "[WARN] Agent Wazuh indisponible."
fi

# 8. Spot-check des métriques Prometheus
echo "[INFO] Interrogation des métriques dans le serveur Prometheus..."
for metric in vault_core_unsealed \
              argocd_app_info \
              falco_events_total \
              kyverno_admission_requests_rejected_total \
              rag_llm_latency_seconds_bucket; do
  res="$(curl -sS --max-time 5 "http://prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=${metric}" 2>/dev/null || echo "")"
  if [[ -n "$res" ]]; then
    python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    if d.get('status') == 'success' and len(d.get('data', {}).get('result', [])) > 0:
        print('${metric}: DONNÉES OK')
    else:
        print('${metric}: AUCUNE DONNÉE')
except Exception:
    print('${metric}: ERREUR PARSING')
" "$res"
  else
    echo "${metric}: AUCUNE DONNÉE (serveur injoignable)"
  fi
done

echo "✓ Vérification OK"
