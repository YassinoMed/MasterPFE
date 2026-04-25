#!/usr/bin/env bash

set -euo pipefail

ARTIFACT_ROOT="${ARTIFACT_ROOT:-artifacts}"
REPORT_FILE="${REPORT_FILE:-artifacts/validation/artifact-normalization-report.md}"

mkdir -p "$(dirname "${REPORT_FILE}")"

if [[ ! -d "${ARTIFACT_ROOT}" ]]; then
  {
    printf '# Artifact Normalization Report - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `PRÊT_NON_EXÉCUTÉ`\n'
    printf -- '- Artifact root: `%s`\n\n' "${ARTIFACT_ROOT}"
    printf 'Artifact root does not exist yet.\n'
  } > "${REPORT_FILE}"
  exit 0
fi

tmp_list="$(mktemp)"
trap 'rm -f "${tmp_list}"' EXIT

find "${ARTIFACT_ROOT}" -type f \
  \( -name '*.md' -o -name '*.txt' -o -name '*.json' -o -name '*.jsonl' -o -name '*.yaml' -o -name '*.yml' -o -name '*.env' -o -name '*.log' \) \
  -print > "${tmp_list}"

changed=0
while IFS= read -r file; do
  before_hash="$(cksum "${file}" | awk '{print $1 ":" $2}')"
  perl -0pi -e 's/\r\n/\n/g; s/\r/\n/g; s/[ \t]+$//mg; s/\n*\z/\n/' "${file}"
  after_hash="$(cksum "${file}" | awk '{print $1 ":" $2}')"
  if [[ "${before_hash}" != "${after_hash}" ]]; then
    changed=$((changed + 1))
  fi
done < "${tmp_list}"

{
  printf '# Artifact Normalization Report - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `TERMINÉ`\n'
  printf -- '- Artifact root: `%s`\n' "${ARTIFACT_ROOT}"
  printf -- '- Files scanned: `%s`\n' "$(wc -l < "${tmp_list}" | tr -d ' ')"
  printf -- '- Files normalized: `%s`\n\n' "${changed}"
  printf 'Normalized CRLF/CR line endings, trailing whitespace and final newlines for text evidence files.\n'
} > "${REPORT_FILE}"

printf '[INFO] Artifact normalization report written to %s\n' "${REPORT_FILE}"
