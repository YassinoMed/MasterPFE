#!/usr/bin/env bash

set -euo pipefail

OUT="${OUT:-artifacts/final/ci-authority-report.md}"

mkdir -p "$(dirname "${OUT}")"

status="TERMINÉ"
workflow_summary="$(mktemp)"
trap 'rm -f "${workflow_summary}"' EXIT

if [[ -d .github/workflows ]]; then
  while IFS= read -r workflow; do
    automatic_trigger="$(awk '
      /^on:/ { in_on=1; next }
      in_on && /^[^[:space:]]/ { in_on=0 }
      in_on && /^[[:space:]]+(push|pull_request):/ { print; found=1 }
      END { exit found ? 0 : 1 }
    ' "${workflow}" || true)"
    manual_trigger="$(awk '
      /^on:/ { in_on=1; next }
      in_on && /^[^[:space:]]/ { in_on=0 }
      in_on && /^[[:space:]]+workflow_dispatch:/ { print; found=1 }
      END { exit found ? 0 : 1 }
    ' "${workflow}" || true)"
    if [[ -n "${automatic_trigger}" ]]; then
      printf '| `%s` | PARTIEL | automatic push/pull_request trigger present |\n' "${workflow}" >> "${workflow_summary}"
      status="PARTIEL"
    elif [[ -n "${manual_trigger}" ]]; then
      printf '| `%s` | TERMINÉ | manual `workflow_dispatch` only |\n' "${workflow}" >> "${workflow_summary}"
    else
      printf '| `%s` | PRÊT_NON_EXÉCUTÉ | no active automatic trigger detected |\n' "${workflow}" >> "${workflow_summary}"
    fi
  done < <(find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
else
  printf '| `.github/workflows` | TERMINÉ | no GitHub Actions workflows present |\n' >> "${workflow_summary}"
fi

if [[ ! -s Jenkinsfile || ! -d infra/jenkins ]]; then
  status="PARTIEL"
fi

{
  printf '# CI Authority Report - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n\n' "${status}"
  printf '## Decision\n\n'
  printf 'Jenkins is the official CI/CD authority. GitHub Actions workflows are retained only as manual legacy mirrors and must not be used as final evidence when Jenkins or shell artifacts exist.\n\n'
  printf '| Workflow | Status | Detail |\n'
  printf '|---|---:|---|\n'
  cat "${workflow_summary}"
  printf '\n## Jenkins authority evidence\n\n'
  printf -- '- `Jenkinsfile`\n'
  printf -- '- `Jenkinsfile.cd`\n'
  printf -- '- `infra/jenkins/casc/jenkins.yaml`\n'
  printf -- '- `infra/jenkins/jobs/`\n'
  printf -- '- `docs/runbooks/jenkins.md`\n'
} > "${OUT}"

printf '[INFO] CI authority report written to %s\n' "${OUT}"
