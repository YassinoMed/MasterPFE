#!/usr/bin/env bash

set -euo pipefail

# Generate a factual DevSecOps readiness report for soutenance.
#
# This script is intentionally read-only. It does not install addons, trigger
# Jenkins jobs, sign images, promote images, or mutate the cluster. It only
# inspects local artefacts and reachable runtime endpoints to distinguish:
# - already evidenced;
# - ready but not yet evidenced;
# - environment-dependent.

NS="${NS:-securerag-hub}"
OUT="${OUT:-artifacts/final/devsecops-readiness-report.md}"
JENKINS_URL="${JENKINS_URL:-http://localhost:8085}"
PORTAL_HEALTH_URL="${PORTAL_HEALTH_URL:-http://localhost:8081/health}"

mkdir -p "$(dirname "${OUT}")"

status_file() {
  local file="$1"

  if [[ -s "${file}" ]]; then
    printf 'OK'
  elif [[ -f "${file}" ]]; then
    printf 'PARTIEL'
  else
    printf 'MANQUANT'
  fi
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

http_status() {
  local url="$1"

  if ! has_command curl; then
    printf 'DEPENDANT_ENV'
    return 0
  fi

  if curl -k -fsS "${url}" >/dev/null 2>&1; then
    printf 'OK'
  else
    printf 'PARTIEL'
  fi
}

kubectl_status() {
  shift 0

  if ! has_command kubectl; then
    printf 'DEPENDANT_ENV'
    return 0
  fi

  if kubectl "$@" >/dev/null 2>&1; then
    printf 'OK'
  else
    printf 'PARTIEL'
  fi
}

latest_support_pack() {
  if has_command python3; then
    python3 - <<'PY'
from pathlib import Path

root = Path("artifacts/support-pack")
packs = list(root.glob("*.tar.gz")) if root.exists() else []
if packs:
    print(max(packs, key=lambda path: path.stat().st_mtime))
PY
    return 0
  fi

  find artifacts/support-pack -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null | sort | tail -n 1 || true
}

supply_chain_execute_status() {
  local summary="artifacts/release/supply-chain-execute-summary.md"

  if [[ ! -f "${summary}" ]]; then
    printf 'PARTIEL'
    return 0
  fi

  if grep -q 'sign source images: OK' "${summary}" \
    && grep -q 'promote by digest without rebuild: OK' "${summary}" \
    && grep -q 'generate SBOMs: OK' "${summary}"; then
    printf 'OK'
  elif grep -qi 'dry-run' "${summary}"; then
    printf 'PRET_A_EXECUTER'
  else
    printf 'PARTIEL'
  fi
}

jenkins_webhook_status() {
  local report="artifacts/jenkins/github-webhook-validation.md"

  if [[ ! -f "${report}" ]]; then
    printf 'PARTIEL'
    return 0
  fi

  if grep -q '| Webhook endpoint | OK |' "${report}" \
    && grep -q '| Job DSL trigger | OK |' "${report}"; then
    printf 'OK'
  elif grep -q '| Webhook endpoint | WARN |' "${report}" \
    && grep -q '| Job DSL trigger | OK |' "${report}"; then
    printf 'PRET_A_CONFIRMER'
  else
    printf 'PARTIEL'
  fi
}

jenkins_ci_push_status() {
  local report="artifacts/jenkins/ci-push-trigger-proof.md"

  if [[ ! -f "${report}" ]]; then
    printf 'PARTIEL'
    return 0
  fi

  if grep -q '| Expected commit in Jenkins last build | OK |' "${report}"; then
    printf 'OK'
  else
    printf 'PARTIEL'
  fi
}

cluster_addons_status() {
  local report="artifacts/validation/cluster-security-addons.md"

  if [[ ! -f "${report}" ]]; then
    printf 'PARTIEL'
    return 0
  fi

  if grep -q '| metrics-server | OK |' "${report}" \
    && grep -q '| Kyverno | OK |' "${report}"; then
    printf 'OK'
  else
    printf 'PARTIEL'
  fi
}

support_pack="$(latest_support_pack)"

cat > "${OUT}" <<EOF
# DevSecOps Readiness Report - SecureRAG Hub

## 1. Contexte

- Généré le : \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Scénario officiel : \`demo\`
- Autorité CI/CD officielle : Jenkins
- Namespace Kubernetes : \`${NS}\`
- Objectif : distinguer les preuves réellement disponibles des éléments prêts à être exécutés.

## 2. État runtime rapide

| Composant | État | Preuve observée |
|---|---:|---|
| Jenkins | $(http_status "${JENKINS_URL%/}/login") | \`${JENKINS_URL%/}/login\` |
| Portal Web | $(http_status "${PORTAL_HEALTH_URL}") | \`${PORTAL_HEALTH_URL}\` |
| Namespace Kubernetes | $(kubectl_status get ns "${NS}") | \`kubectl get ns ${NS}\` |
| Pods applicatifs | $(kubectl_status get pods -n "${NS}") | \`kubectl get pods -n ${NS}\` |
| HPA | $(kubectl_status get hpa -n "${NS}") | \`kubectl get hpa -n ${NS}\` |
| Metrics API | $(kubectl_status get apiservice v1beta1.metrics.k8s.io) | \`kubectl get apiservice v1beta1.metrics.k8s.io\` |
| Kyverno CRD | $(kubectl_status get crd clusterpolicies.kyverno.io) | \`kubectl get crd clusterpolicies.kyverno.io\` |

## 3. Preuves DevSecOps

| Domaine | État | Artefact principal |
|---|---:|---|
| Jenkins webhook / CI push | $(jenkins_webhook_status) | \`artifacts/jenkins/github-webhook-validation.md\` |
| Jenkins commit consommé après push | $(jenkins_ci_push_status) | \`artifacts/jenkins/ci-push-trigger-proof.md\` |
| Supply chain execute | $(supply_chain_execute_status) | \`artifacts/release/supply-chain-execute-summary.md\` |
| Signature Cosign | $(status_file artifacts/release/sign-summary.txt) | \`artifacts/release/sign-summary.txt\` |
| Vérification Cosign | $(status_file artifacts/release/verify-summary.txt) | \`artifacts/release/verify-summary.txt\` |
| Promotion par digest | $(status_file artifacts/release/promotion-digests.txt) | \`artifacts/release/promotion-digests.txt\` |
| SBOM Syft | $(status_file artifacts/sbom/sbom-index.txt) | \`artifacts/sbom/sbom-index.txt\` |
| Evidence release | $(status_file artifacts/release/release-evidence.md) | \`artifacts/release/release-evidence.md\` |
| Evidence supply chain | $(status_file artifacts/release/supply-chain-evidence.md) | \`artifacts/release/supply-chain-evidence.md\` |
| Addons sécurité cluster | $(cluster_addons_status) | \`artifacts/validation/cluster-security-addons.md\` |
| Résumé final | $(status_file artifacts/final/final-validation-summary.md) | \`artifacts/final/final-validation-summary.md\` |
| Support pack | $([[ -n "${support_pack}" ]] && printf 'OK' || printf 'PARTIEL') | \`${support_pack:-artifacts/support-pack/*.tar.gz}\` |

## 4. Lecture soutenance

- \`OK\` : une preuve exploitable existe ou le composant répond réellement.
- \`PARTIEL\` : le script ou la ressource existe, mais la preuve complète n'est pas disponible.
- \`PRET_A_EXECUTER\` : le chemin est automatisé, mais il reste à le rejouer en conditions complètes.
- \`PRET_A_CONFIRMER\` : la configuration est prête, mais la validation réelle doit être confirmée après un push GitHub.
- \`DEPENDANT_ENV\` : l'état dépend d'un binaire local, du réseau, du cluster ou d'un secret non fourni.

## 5. Actions recommandées

1. Valider Jenkins après un \`git push\` réel et archiver \`artifacts/jenkins/github-webhook-validation.md\`.
2. Lancer \`make supply-chain-execute\` uniquement si Docker, Cosign, Syft, les clés et les images sources sont disponibles.
3. Lancer \`make metrics-install\`, \`make kyverno-install\`, puis \`make cluster-security-proof\`.
4. Régénérer \`make final-summary\`, \`make devsecops-readiness\` et \`make support-pack\`.

## 6. Conclusion

Le socle DevSecOps/Kubernetes/demo Laravel est considéré comme établi. Les blocs avancés Jenkins webhook, supply chain execute, metrics-server et Kyverno doivent être présentés comme complets uniquement lorsque les artefacts listés ci-dessus sont présents et datés.
EOF

printf 'DevSecOps readiness report written to %s\n' "${OUT}"
