#!/usr/bin/env bash

set -euo pipefail

OUT_DIR="${OUT_DIR:-artifacts/final}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/devsecops-closure-matrix.md}"

mkdir -p "${OUT_DIR}"

status_from_file() {
  local file="$1"
  if [[ ! -s "${file}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi

  local status
  status="$(grep -E '^- Status: `|^Statut global: `' "${file}" | head -n 1 | sed -E 's/.*Status: `([^`]+)`.*/\1/; s/.*Statut global: `([^`]+)`.*/\1/' || true)"

  case "${status}" in
    TERMINÉ|PARTIEL|PRÊT_NON_EXÉCUTÉ|DÉPENDANT_DE_L_ENVIRONNEMENT)
      printf '%s' "${status}"
      return 0
      ;;
    COMPLETE_PROVEN)
      printf 'TERMINÉ'
      return 0
      ;;
    PARTIAL_READY_TO_PROVE)
      printf 'PARTIEL'
      return 0
      ;;
  esac

  if grep -Fq 'DÉPENDANT_DE_L_ENVIRONNEMENT' "${file}"; then
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
  elif grep -Fq 'PARTIEL' "${file}" || grep -Fq 'FAIL' "${file}" || grep -Fq 'WARN' "${file}"; then
    printf 'PARTIEL'
  elif grep -Fq 'PRÊT_NON_EXÉCUTÉ' "${file}" || grep -Fq 'SKIPPED' "${file}"; then
    printf 'PRÊT_NON_EXÉCUTÉ'
  else
    printf 'TERMINÉ'
  fi
}

jenkins_status_from_file() {
  local file="$1"
  if [[ ! -s "${file}" ]]; then
    printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
    return 0
  fi

  if grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*FAIL[[:space:]]*[|]' "${file}"; then
    printf 'PARTIEL'
  elif grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*WARN[[:space:]]*[|]' "${file}"; then
    printf 'PARTIEL'
  elif grep -Eq '[|][[:space:]]*[^|]+[[:space:]]*[|][[:space:]]*OK[[:space:]]*[|]' "${file}"; then
    printf 'TERMINÉ'
  else
    printf 'PARTIEL'
  fi
}

merge_status() {
  local statuses=("$@")
  local status

  for status in "${statuses[@]}"; do
    if [[ "${status}" == "PARTIEL" ]]; then
      printf 'PARTIEL'
      return 0
    fi
  done

  for status in "${statuses[@]}"; do
    if [[ "${status}" == "DÉPENDANT_DE_L_ENVIRONNEMENT" ]]; then
      printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
      return 0
    fi
  done

  for status in "${statuses[@]}"; do
    if [[ "${status}" == "PRÊT_NON_EXÉCUTÉ" ]]; then
      printf 'PRÊT_NON_EXÉCUTÉ'
      return 0
    fi
  done

  printf 'TERMINÉ'
}

support_pack_status() {
  if find artifacts/support-pack -maxdepth 1 -type f -name '*.tar.gz' | grep -q . 2>/dev/null; then
    printf 'TERMINÉ'
  else
    printf 'PRÊT_NON_EXÉCUTÉ'
  fi
}

first_existing_file() {
  local candidate
  for candidate in "$@"; do
    if [[ -s "${candidate}" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done
  return 1
}

portal_health_status() {
  local health_file

  if health_file="$(first_existing_file artifacts/validation/runtime-portal-health.txt artifacts/validation/portal-health.txt)"; then
    if grep -Eq '(^|[^0-9])200([^0-9]|$)' "${health_file}"; then
      printf 'TERMINÉ'
    else
      printf 'PARTIEL'
    fi
    return 0
  fi

  status_from_file artifacts/application/portal-service-connectivity.md
}

hpa_runtime_status() {
  local report_status
  local hpa_file
  local top_nodes_file
  local top_pods_file

  report_status="$(status_from_file artifacts/validation/hpa-runtime-report.md)"
  if [[ "${report_status}" == "TERMINÉ" || "${report_status}" == "PARTIEL" ]]; then
    printf '%s' "${report_status}"
    return 0
  fi

  hpa_file="$(first_existing_file artifacts/validation/runtime-hpa.txt artifacts/validation/k8s-hpa.txt || true)"
  top_nodes_file="$(first_existing_file artifacts/validation/runtime-top-nodes.txt artifacts/validation/k8s-top-nodes.txt || true)"
  top_pods_file="$(first_existing_file artifacts/validation/runtime-top-pods.txt artifacts/validation/k8s-top-pods.txt || true)"

  if [[ -n "${hpa_file}" && -n "${top_nodes_file}" && -n "${top_pods_file}" ]]; then
    if grep -Eq '<unknown>|unable to get metrics|error|not available' "${hpa_file}" "${top_nodes_file}" "${top_pods_file}"; then
      printf 'PARTIEL'
    else
      printf 'TERMINÉ'
    fi
    return 0
  fi

  printf '%s' "${report_status}"
}

row() {
  local block="$1"
  local task="$2"
  local status="$3"
  local priority="$4"
  local action="$5"

  printf '| %s | %s | %s | %s | %s |\n' "${block}" "${task}" "${status}" "${priority}" "${action}" >> "${OUT_FILE}"
}

runtime_rollout_status="$(status_from_file artifacts/validation/runtime-image-rollout-proof.md)"
runtime_evidence_status="$(status_from_file artifacts/validation/production-runtime-evidence.md)"
portal_health_status="$(portal_health_status)"
hpa_status="$(hpa_runtime_status)"
runtime_security_status="$(status_from_file artifacts/security/runtime-security-postdeploy.md)"
k8s_hardening_status="$(merge_status "$(status_from_file artifacts/security/k8s-ultra-hardening.md)" "$(status_from_file artifacts/security/k8s-resource-guards.md)")"
release_attestation_status="$(status_from_file artifacts/release/release-attestation.md)"
digest_deploy_status="$(status_from_file artifacts/release/no-rebuild-deploy-summary.md)"
provenance_status="$(status_from_file artifacts/release/provenance.slsa.md)"
kyverno_runtime_status="$(status_from_file artifacts/validation/kyverno-runtime-report.md)"
kyverno_enforce_status="$(status_from_file artifacts/validation/kyverno-enforce-readiness.md)"
external_db_status="$(status_from_file artifacts/security/production-external-db-readiness.md)"
data_resilience_status="$(status_from_file artifacts/security/production-data-resilience.md)"
backup_restore_status="$(status_from_file artifacts/backup/data-resilience-proof.md)"
secrets_status="$(status_from_file artifacts/security/secrets-management.md)"
jenkins_webhook_status="$(jenkins_status_from_file artifacts/jenkins/github-webhook-validation.md)"
jenkins_ci_push_status="$(jenkins_status_from_file artifacts/jenkins/ci-push-trigger-proof.md)"
support_pack_status_value="$(support_pack_status)"
source_of_truth_status="$(merge_status "$(status_from_file artifacts/final/security-final-status.md)" "$(status_from_file artifacts/final/production-final-status.md)" "$(status_from_file artifacts/final/release-final-status.md)" "$(status_from_file artifacts/final/final-validation-summary.md)")"

{
  printf '# DevSecOps Closure Matrix - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '| Bloc | Tâche | État | Priorité | Action restante |\n'
  printf '|---|---|---:|---:|---|\n'
} > "${OUT_FILE}"

row "Bloc A" "Preuve runtime imageID / digest" "${runtime_rollout_status}" "P0" "Rejouer \`make runtime-image-proof\` ou \`make final-runtime-proof\` sur le cluster cible."
row "Bloc A" "Pods récents, logs, events et healthchecks" "$(merge_status "${runtime_evidence_status}" "${portal_health_status}")" "P0" "Rejouer \`make production-runtime-evidence\` et \`make portal-service-proof\` après le dernier déploiement."
row "Bloc A" "HPA runtime sans \`<unknown>\`" "${hpa_status}" "P1" "Rejouer \`make hpa-runtime-proof\` après installation ou réparation de metrics-server."

row "Bloc B" "Sécurité post-déploiement runtime" "${runtime_security_status}" "P1" "Rejouer \`make runtime-security-postdeploy\` sur les pods actifs du namespace cible."
row "Bloc B" "Hardening workloads / guards statiques" "${k8s_hardening_status}" "P1" "Corriger les lignes \`FAIL\` éventuelles puis rejouer \`make k8s-ultra-hardening\` et \`make k8s-resource-guards\`."

row "Bloc C" "Supply chain complète / attestation release" "${release_attestation_status}" "P0" "Rejouer \`make supply-chain-execute\` puis \`make release-proof-strict\` avec Docker, registry, Trivy, Syft et Cosign."
row "Bloc C" "Déploiement digest immuable no-rebuild" "${digest_deploy_status}" "P0" "Rejouer le déploiement avec \`REQUIRE_DIGEST_DEPLOY=true\` et des digests promus présents."
row "Bloc C" "Provenance SLSA-style" "${provenance_status}" "P0" "Régénérer après attestation release complète via \`make release-provenance\`."

row "Bloc D" "Kyverno Audit / PolicyReports runtime" "${kyverno_runtime_status}" "P1" "Rejouer \`make kyverno-runtime-proof\` avec cluster, CRDs, contrôleurs et PolicyReports joignables."
row "Bloc D" "Kyverno Enforce readiness" "${kyverno_enforce_status}" "P2" "Garder Audit tant que \`kyverno-enforce-readiness\` n’est pas \`TERMINÉ\`."

row "Bloc E" "PostgreSQL externe / overlay / secret DB" "${external_db_status}" "P1" "Utiliser \`infra/k8s/overlays/production-external-db\` et prouver un chemin secret direct, SOPS ou External Secrets."
row "Bloc E" "Backup / restore prouvés" "${backup_restore_status}" "P1" "Renseigner les variables DB et rejouer \`make data-resilience-proof\` sur une base de restauration isolée."

row "Bloc F" "Secrets management moderne" "${secrets_status}" "P1" "Appliquer le Secret DB externe réel; garder SOPS/age et ESO/Vault en \`PRÊT_NON_EXÉCUTÉ\` tant qu’ils ne tournent pas."
row "Bloc F" "Jenkins webhook / SCM proof" "$(merge_status "${jenkins_webhook_status}" "${jenkins_ci_push_status}")" "P1" "Rejouer \`make jenkins-webhook-proof\` et \`make jenkins-ci-push-proof\` sur le Jenkins cible."
row "Bloc F" "Support pack final" "${support_pack_status_value}" "P0" "Régénérer après les preuves finales réelles via \`make support-pack\`."
row "Bloc F" "Source de vérité finale" "${source_of_truth_status}" "P0" "Régénérer \`make final-source-of-truth\` et \`make final-summary\` après la dernière campagne."

python3 - "${OUT_FILE}" <<'PY'
from collections import Counter
from pathlib import Path
import sys

path = Path(sys.argv[1])
rows = []
for line in path.read_text(encoding="utf-8").splitlines():
    if not line.startswith("| Bloc "):
        continue
    parts = [part.strip() for part in line.strip("|").split("|")]
    if len(parts) >= 3:
        rows.append(parts[2])

counts = Counter(rows)
with path.open("a", encoding="utf-8") as handle:
    handle.write("\n## Synthèse par état\n\n")
    for status in ("TERMINÉ", "PARTIEL", "PRÊT_NON_EXÉCUTÉ", "DÉPENDANT_DE_L_ENVIRONNEMENT"):
        handle.write(f"- `{status}`: {counts.get(status, 0)}\n")
    handle.write("\n## Lecture honnête\n\n")
    handle.write("- `TERMINÉ` signifie prouvé avec un artefact présent et cohérent.\n")
    handle.write("- `PARTIEL` signifie que la preuve existe mais reste incomplète, échouée ou incohérente.\n")
    handle.write("- `PRÊT_NON_EXÉCUTÉ` signifie que le dépôt est prêt mais que la campagne réelle n’a pas été rejouée.\n")
    handle.write("- `DÉPENDANT_DE_L_ENVIRONNEMENT` signifie qu’un cluster, Jenkins, une registry ou une base externe manque pour la preuve live.\n")
PY

printf '[INFO] DevSecOps closure matrix written to %s\n' "${OUT_FILE}"
