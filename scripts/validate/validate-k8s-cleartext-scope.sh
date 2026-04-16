#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts/security}"
OUT="${OUT:-${ARTIFACT_DIR}/k8s-cleartext-scope.md}"

mkdir -p "${ARTIFACT_DIR}"

allowed_hosts="auth-users chatbot-manager conversation-service audit-security-service portal-web"
overlays=(
  "infra/k8s/overlays/dev"
  "infra/k8s/overlays/demo"
)

status="TERMINÉ"
notes=()

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

fail_report() {
  status="PARTIEL"
  notes+=("$1")
}

raw_values="$(grep -RInE 'value:[[:space:]]*"?http://' infra/k8s/base infra/k8s/overlays --include='*.yaml' --include='*.yml' 2>/dev/null || true)"
if [ -n "${raw_values}" ]; then
  fail_report "Des valeurs Kubernetes contiennent encore un schéma HTTP littéral."
fi

for overlay in "${overlays[@]}"; do
  rendered="${tmpdir}/$(basename "${overlay}").yaml"
  if ! kubectl kustomize "${overlay}" > "${rendered}"; then
    fail_report "Impossible de rendre ${overlay} avec kubectl kustomize."
    continue
  fi

  if grep -nE 'value:[[:space:]]*"?http://' "${rendered}" >/tmp/securerag-k8s-cleartext-values.txt; then
    fail_report "Le rendu ${overlay} contient encore des valeurs HTTP littérales."
  fi

  scheme_count="$(grep -c 'name: INTERNAL_SERVICE_SCHEME' "${rendered}" || true)"
  annotation_count="$(grep -c 'security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy' "${rendered}" || true)"
  if [ "${scheme_count}" -gt 0 ] && [ "${annotation_count}" -lt "${scheme_count}" ]; then
    fail_report "Le rendu ${overlay} utilise INTERNAL_SERVICE_SCHEME sans annotation de risque sur tous les pods concernés."
  fi

  while IFS= read -r line; do
    url="${line#*value: }"
    url="${url%\"}"
    url="${url#\"}"
    host="${url#*://}"
    host="${host%%[:/]*}"
    case " ${allowed_hosts} " in
      *" ${host} "*) ;;
      *) fail_report "Le rendu ${overlay} référence un hôte HTTP interne non autorisé: ${host}" ;;
    esac
  done < <(grep -nE 'value:[[:space:]]*"?\$\(INTERNAL_SERVICE_SCHEME\)://[^" ]+' "${rendered}" || true)
done

{
  echo "# Kubernetes Clear-Text Scope Validation — SecureRAG Hub"
  echo
  echo "| Contrôle | Résultat |"
  echo "|---|---|"
  echo "| Statut global | ${status} |"
  echo "| Overlays contrôlés | ${overlays[*]} |"
  echo "| Hôtes internes autorisés | ${allowed_hosts} |"
  echo
  echo "## Règle appliquée"
  echo
  echo "- Aucun manifest Kubernetes ne doit contenir de valeur directe \`http://...\` dans les variables d'environnement."
  echo "- Les communications internes HTTP doivent passer par \`\$(INTERNAL_SERVICE_SCHEME)://service:port\`."
  echo "- Les pods concernés doivent porter l'annotation \`security.securerag.dev/internal-cleartext-scope=cluster-only-networkpolicy\`."
  echo "- Les hôtes autorisés sont limités aux Services internes SecureRAG et aux composants locaux du namespace."
  echo
  echo "## Notes"
  echo
  if [ "${#notes[@]}" -eq 0 ]; then
    echo "- Aucun écart détecté."
  else
    printf -- "- %s\n" "${notes[@]}"
  fi
  echo
  echo "## Lecture sécurité"
  echo
  echo "Le trafic HTTP interne reste accepté uniquement pour le mode demo/quasi pré-production local, sous réserve des NetworkPolicies et de l'absence d'exposition publique directe. Toute exposition utilisateur finale doit être publiée en HTTPS."
} > "${OUT}"

cat "${OUT}"

if [ "${status}" != "TERMINÉ" ]; then
  exit 1
fi
