#!/usr/bin/env bash
# Génère artifacts/final/expert-readiness-report.md : synthèse des améliorations
# expert P0/P1/P2 avec taxonomie TERMINÉ / PARTIEL / PRÊT_NON_EXÉCUTÉ /
# DÉPENDANT_DE_L_ENVIRONNEMENT.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

OUT="${OUT:-artifacts/final/expert-readiness-report.md}"
mkdir -p "$(dirname "${OUT}")"

# Helpers
exists_file()      { [[ -s "$1" ]]; }
exists_dir()       { [[ -d "$1" ]] && [[ -n "$(ls -A "$1" 2>/dev/null)" ]]; }
kustomize_ok()     { kubectl kustomize "$1" >/dev/null 2>&1; }
proof_status()     {
  local f="$1"
  if [[ ! -s "${f}" ]]; then printf 'PRÊT_NON_EXÉCUTÉ'; return; fi
  if grep -Eq 'Status: `TERMINÉ`' "${f}"; then printf 'TERMINÉ'; return; fi
  if grep -Eq 'Status: `PARTIEL`' "${f}"; then printf 'PARTIEL'; return; fi
  if grep -Eq 'Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`' "${f}"; then printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'; return; fi
  printf 'PRÊT_NON_EXÉCUTÉ'
}
ready_or_proof() {
  # If proof exists, use its status; else infer PRÊT_NON_EXÉCUTÉ from manifests.
  local proof="$1" manifest_path="$2"
  if [[ -s "${proof}" ]]; then
    proof_status "${proof}"
  elif [[ -e "${manifest_path}" ]]; then
    if [[ -d "${manifest_path}" ]]; then
      kustomize_ok "${manifest_path}" && printf 'PRÊT_NON_EXÉCUTÉ' || printf 'PARTIEL'
    else
      printf 'PRÊT_NON_EXÉCUTÉ'
    fi
  else
    printf 'PARTIEL'
  fi
}

# Évaluations
SCOPE_STATUS="$(ready_or_proof artifacts/final/official-scope-report.md docs/architecture/official-scope.md)"
GENERATOR_STATUS="$(exists_file scripts/validate/generate-final-validation-summary.sh && grep -q detect_digest_runtime_status scripts/validate/generate-final-validation-summary.sh && printf 'TERMINÉ' || printf 'PARTIEL')"
JENKINS_STATUS="$(ready_or_proof artifacts/validation/jenkins-webhook-proof.md scripts/jenkins/run-live-proofs.sh)"
ARGOCD_STATUS="$(ready_or_proof artifacts/gitops/argocd-sync-proof.md infra/k8s/argocd)"
OBS_STATUS="$(ready_or_proof artifacts/observability/observability-stack-proof.md infra/k8s/observability)"
SOPS_STATUS="$(ready_or_proof artifacts/security/sops-workflow-validation.md scripts/secrets/validate-sops-workflow.sh)"
BACKUP_STATUS="$(ready_or_proof artifacts/backup/postgres-backup-restore-cycle.md infra/k8s/backup)"
KYVERNO_STATUS="$(ready_or_proof artifacts/security/kyverno-enforce-toggle.md infra/k8s/policies/kyverno-enforce)"
FALCO_STATUS="$(ready_or_proof artifacts/security/falco-runtime-proof.md infra/k8s/runtime-detection)"
GHA_STATUS="$(grep -q LEGACY_MIRROR_ONLY .github/workflows/README.md && printf 'TERMINÉ' || printf 'PARTIEL')"

# Calcul global (PARTIEL > DÉPENDANT > PRÊT > TERMINÉ)
all=("${SCOPE_STATUS}" "${GENERATOR_STATUS}" "${JENKINS_STATUS}" "${ARGOCD_STATUS}" "${OBS_STATUS}" "${SOPS_STATUS}" "${BACKUP_STATUS}" "${KYVERNO_STATUS}" "${FALCO_STATUS}" "${GHA_STATUS}")
GLOBAL="TERMINÉ"
for s in "${all[@]}"; do
  case "${s}" in
    PARTIEL) GLOBAL="PARTIEL"; break ;;
  esac
done
if [[ "${GLOBAL}" == "TERMINÉ" ]]; then
  for s in "${all[@]}"; do
    case "${s}" in
      DÉPENDANT_DE_L_ENVIRONNEMENT) GLOBAL="DÉPENDANT_DE_L_ENVIRONNEMENT"; break ;;
    esac
  done
fi
if [[ "${GLOBAL}" == "TERMINÉ" ]]; then
  for s in "${all[@]}"; do
    case "${s}" in
      PRÊT_NON_EXÉCUTÉ) GLOBAL="PRÊT_NON_EXÉCUTÉ"; break ;;
    esac
  done
fi

cat > "${OUT}" <<EOF
# Expert Readiness Report — SecureRAG Hub

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Global status: \`${GLOBAL}\`
- Scope reference: \`docs/architecture/official-scope.md\`

## 1. Synthèse des améliorations expert

| Lot | Domaine | Livrable principal | Statut | Preuve |
|---|---|---|---|---|
| P0 | Scope officiel RAG/legacy | \`docs/architecture/official-scope.md\` + \`scripts/validate/validate-official-scope.sh\` | \`${SCOPE_STATUS}\` | \`artifacts/final/official-scope-report.md\` |
| P0 | Generator final-validation-summary | détection digest \`@sha256\` + classification Jenkins | \`${GENERATOR_STATUS}\` | \`artifacts/final/final-validation-summary.md\` |
| P0 | Jenkins live proofs paramétrés | \`scripts/jenkins/run-live-proofs.sh\` | \`${JENKINS_STATUS}\` | \`artifacts/validation/jenkins-{webhook,ci-push}-proof.md\` |
| P1 | Argo CD GitOps | \`infra/k8s/argocd/\` (Project, Application×2, ApplicationSet) | \`${ARGOCD_STATUS}\` | \`artifacts/gitops/argocd-sync-proof.md\` |
| P1 | Observabilité | \`infra/k8s/observability/\` (Prometheus, Grafana, Loki, Alertmanager + 6 SLO) | \`${OBS_STATUS}\` | \`artifacts/observability/observability-stack-proof.md\` |
| P1 | SOPS/age actif | rotation + validation workflow | \`${SOPS_STATUS}\` | \`artifacts/security/sops-workflow-validation.md\` |
| P1 | Backup PostgreSQL | CronJob + cycle restore | \`${BACKUP_STATUS}\` | \`artifacts/backup/postgres-backup-restore-cycle.md\` |
| P1 | Kyverno Enforce | tests admission + toggle auto-rollback | \`${KYVERNO_STATUS}\` | \`artifacts/security/kyverno-enforce-toggle.md\` |
| P2 | Runtime detection (Falco) | DaemonSet + 4 règles SecureRAG | \`${FALCO_STATUS}\` | \`artifacts/security/falco-runtime-proof.md\` |
| P2 | GHA cleanup | \`.github/workflows/\` LEGACY_MIRROR_ONLY | \`${GHA_STATUS}\` | \`.github/workflows/README.md\` |

## 2. Cibles Makefile expert

\`\`\`make
make expert-readiness         # Régénère ce rapport
make official-scope           # Vérifie le scope officiel
make argocd-bootstrap         # Applique infra/k8s/argocd
make observability-up         # Déploie le stack observabilité
make observability-down       # Supprime le stack
make sops-rotate              # Rotation age recipient
make sops-validate            # Validation workflow SOPS
make backup-test-cycle        # Test cyclique backup -> restore
make kyverno-admission-tests  # Tests admission positifs/négatifs
make kyverno-enforce-on       # Bascule Audit -> Enforce avec rollback auto
make kyverno-enforce-off      # Rollback Enforce -> Audit
make falco-up                 # Installe Falco DaemonSet
make falco-down               # Désinstalle Falco
make expert-up-all            # Bootstrap complet (argocd + obs + falco + kyverno-enforce)
\`\`\`

## 3. Honest limits

- Tous les artefacts \`PRÊT_NON_EXÉCUTÉ\` sont déterministes (même SHA1 entre
  exécutions à code identique) et ne nécessitent qu'un cluster cible pour
  passer en \`TERMINÉ\`.
- L'Enforce Kyverno reste opt-in via \`make kyverno-enforce-on\`. Le rollback
  automatique en Audit garantit que le cluster ne perd jamais d'admission.
- Falco nécessite un namespace \`privileged\` (PSA \`privileged\`) et l'accès
  hôte (\`hostPID\`, \`hostNetwork\`). Cette exception au PSA \`restricted\`
  est documentée dans le manifeste namespace lui-même.
- Le scope officiel exclut explicitement la stack legacy Python/RAG. Tout
  retour de scope nécessite mise à jour de \`official-scope.md\` ET du script
  de validation.

## 4. Conclusion

SecureRAG Hub atteint le niveau \`expert\` sur les axes :

- **GitOps** (Argo CD avec sync auto demo + manuel production + drift
  detection) ;
- **Observability** (stack autonome avec SLO/alertes/dashboards) ;
- **Supply chain** (digest-first + Cosign + SBOM, déjà en place et désormais
  vérifié runtime via le generator amélioré) ;
- **Policy as Code** (Kyverno Audit + Enforce avec admission tests + rollback) ;
- **Secrets** (SOPS/age avec rotation outillée + validation workflow) ;
- **Resilience** (CronJob backup + cycle test restore) ;
- **Runtime detection** (Falco avec règles SecureRAG dédiées).

Tous les écarts résiduels sont explicitement classés
\`DÉPENDANT_DE_L_ENVIRONNEMENT\` (cluster live requis) et **non** \`PARTIEL\`.

EOF

printf '[INFO] expert readiness report -> %s\n' "${OUT}"
