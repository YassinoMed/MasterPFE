#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts/security}"
OUT="${OUT:-${ARTIFACT_DIR}/k8s-resource-guards.md}"

mkdir -p "${ARTIFACT_DIR}"

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

validate_rendered_resources() {
  local rendered="$1"
  local overlay="$2"

  awk -v overlay="${overlay}" '
    function indent(line) {
      match(line, /^ */)
      return RLENGTH
    }

    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }

    function finish_container() {
      if (in_container && container_name != "") {
        if (!request_ephemeral || !limit_ephemeral) {
          printf "%s: container %s missing ephemeral-storage request or limit\n", overlay, container_name
          failed = 1
        }
      }
      in_container = 0
      container_name = ""
      request_ephemeral = 0
      limit_ephemeral = 0
      resource_section = ""
    }

    /^[[:space:]]*(containers|initContainers):[[:space:]]*$/ {
      finish_container()
      in_container_list = 1
      list_indent = indent($0)
      next
    }

    /^---[[:space:]]*$/ {
      finish_container()
      in_container_list = 0
      next
    }

    in_container_list {
      current_indent = indent($0)

      if (trim($0) == "") {
        next
      }

      if (current_indent <= list_indent) {
        finish_container()
        in_container_list = 0
        next
      }

      if (current_indent == list_indent + 2 && $0 ~ /^[[:space:]]*- name:[[:space:]]*/) {
        finish_container()
        in_container = 1
        container_name = $0
        sub(/^[[:space:]]*- name:[[:space:]]*/, "", container_name)
        container_name = trim(container_name)
        next
      }

      if (in_container && $0 ~ /^[[:space:]]*requests:[[:space:]]*$/) {
        resource_section = "requests"
        next
      }

      if (in_container && $0 ~ /^[[:space:]]*limits:[[:space:]]*$/) {
        resource_section = "limits"
        next
      }

      if (in_container && $0 ~ /^[[:space:]]*ephemeral-storage:[[:space:]]*/) {
        if (resource_section == "requests") {
          request_ephemeral = 1
        } else if (resource_section == "limits") {
          limit_ephemeral = 1
        }
      }
    }

    END {
      finish_container()
      exit failed
    }
  ' "${rendered}"
}

for overlay in "${overlays[@]}"; do
  rendered="${tmpdir}/$(basename "${overlay}").yaml"
  if ! kubectl kustomize "${overlay}" > "${rendered}"; then
    fail_report "Impossible de rendre ${overlay} avec kubectl kustomize."
    continue
  fi

  if ! validate_output="$(validate_rendered_resources "${rendered}" "${overlay}")"; then
    fail_report "Des containers de ${overlay} ne déclarent pas resources.requests.ephemeral-storage et resources.limits.ephemeral-storage: ${validate_output}"
  fi
done

if ! grep -RIn 'ephemeral-storage:' infra/k8s/base/limitrange.yaml >/dev/null; then
  fail_report "Le LimitRange de base ne définit pas de defaultRequest/default ephemeral-storage."
fi

{
  echo "# Kubernetes Resource Guards Validation — SecureRAG Hub"
  echo
  echo "| Contrôle | Résultat |"
  echo "|---|---|"
  echo "| Statut global | ${status} |"
  echo "| Overlays contrôlés | ${overlays[*]} |"
  echo "| Contrôle container | resources.requests.ephemeral-storage et resources.limits.ephemeral-storage requis |"
  echo "| Contrôle namespace | LimitRange avec defaults ephemeral-storage requis |"
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
  echo "Les workloads SecureRAG déclarent explicitement une consommation temporaire attendue, et le namespace conserve un LimitRange de secours. Cela réduit le risque d'éviction imprévisible et ferme l'alerte Sonar/Kubernetes sur les requêtes de stockage éphémère."
} > "${OUT}"

cat "${OUT}"

if [ "${status}" != "TERMINÉ" ]; then
  exit 1
fi
