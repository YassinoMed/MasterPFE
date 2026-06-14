#!/usr/bin/env bash
set -e

echo "=== LANCEMENT DE L'AUDIT FINAL DEVSECOPS ==="
ERRORS=0

echo -n "1. Vérification ArgoCD (Automated Sync) : "
if grep -q "syncPolicy" infra/k8s/argocd/application-production.yaml && \
   grep -q "automated" infra/k8s/argocd/application-production.yaml; then
    echo "[OK]"
else
    echo "[KO] Automated Sync manquant."
    ERRORS=$((ERRORS+1))
fi

echo -n "2. Vérification kubectl apply impératif : "
if grep -qn "^[^#]*kubectl apply.*-k" scripts/deploy/deploy-kind.sh; then
    echo "[KO] Déploiement impératif détecté dans deploy-kind.sh."
    ERRORS=$((ERRORS+1))
else
    echo "[OK]"
fi

echo -n "3. Vérification CI (Triggers SCM) : "
if grep -q "githubPush()" Jenkinsfile; then
    echo "[OK]"
else
    echo "[KO] Trigger manquant."
    ERRORS=$((ERRORS+1))
fi

echo -n "4. Vérification Security Backlog : "
if grep -q "notify-security-backlog.sh" Jenkinsfile; then
    echo "[OK]"
else
    echo "[KO] Hook manquant."
    ERRORS=$((ERRORS+1))
fi

echo -n "5. Vérification Pre-flight Kyverno (Jenkins) : "
if grep -q "Pre-flight Kyverno" Jenkinsfile.cd; then
    echo "[OK]"
else
    echo "[KO] Etape manquante."
    ERRORS=$((ERRORS+1))
fi

echo -n "6. Contrainte: Zéro GitHub Actions : "
if [ -d ".github/workflows" ] && [ "$(ls -A .github/workflows)" ]; then
    echo "[KO] Dossier GitHub Actions illégitime détecté."
    ERRORS=$((ERRORS+1))
else
    echo "[OK]"
fi

echo -n "7. Contrainte: Zéro Secrets en clair Kubernetes : "
if grep -r "kind: Secret" infra/k8s/ | grep -v "ExternalSecret" >/dev/null; then
    echo "[KO] Objets kind: Secret natifs trouvés (Violation Vault CSI)."
    ERRORS=$((ERRORS+1))
else
    echo "[OK]"
fi

echo "----------------------------------------------"
if [ "$ERRORS" -eq 0 ]; then
    echo "=== AUDIT RÉUSSI (0 Écart) ==="
    exit 0
else
    echo "=== AUDIT ÉCHOUÉ ($ERRORS Écarts résiduels) ==="
    exit 1
fi
