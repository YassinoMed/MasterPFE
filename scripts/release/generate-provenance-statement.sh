#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/release}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
ATTESTATION_FILE="${ATTESTATION_FILE:-${REPORT_DIR}/release-attestation.json}"
OUT_JSON="${OUT_JSON:-${REPORT_DIR}/provenance.slsa.json}"
OUT_MD="${OUT_MD:-${REPORT_DIR}/provenance.slsa.md}"
STRICT_PROVENANCE="${STRICT_PROVENANCE:-false}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

mkdir -p "${REPORT_DIR}"

python3 - "${DIGEST_RECORD_FILE}" "${ATTESTATION_FILE}" "${OUT_JSON}" "${OUT_MD}" <<'PY'
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

digest_record, attestation_file, out_json, out_md = map(Path, sys.argv[1:5])

def sha256(path: Path) -> str:
    if not path.exists():
        return "missing"
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def git_value(*args: str) -> str:
    try:
        return subprocess.check_output(["git", *args], text=True).strip()
    except Exception:
        return "unknown"

subjects = []
if digest_record.exists():
    for raw in digest_record.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) != 4:
            continue
        service, _source_ref, target_ref, digest = parts
        if digest.startswith("sha256:"):
            subjects.append({
                "name": target_ref,
                "digest": {"sha256": digest.split(":", 1)[1]},
                "service": service,
            })

attestation_status = "MISSING"
if attestation_file.exists():
    try:
        payload = json.loads(attestation_file.read_text(encoding="utf-8"))
        attestation_status = payload.get("status", "PRESENT")
    except Exception:
        attestation_status = "PRESENT_UNREADABLE"

complete = bool(subjects) and attestation_status == "COMPLETE_PROVEN"
status = "TERMINÉ" if complete else "PRÊT_NON_EXÉCUTÉ"

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
commit = git_value("rev-parse", "HEAD")
branch = git_value("rev-parse", "--abbrev-ref", "HEAD")
remote = git_value("config", "--get", "remote.origin.url")

statement = {
    "_type": "https://in-toto.io/Statement/v1",
    "subject": subjects,
    "predicateType": "https://slsa.dev/provenance/v1",
    "predicate": {
        "buildDefinition": {
            "buildType": "https://securerag.local/buildtypes/jenkins-cd-digest-release/v1",
            "externalParameters": {
                "repository": remote,
                "branch": branch,
                "commit": commit,
            },
            "resolvedDependencies": [
                {
                    "uri": remote,
                    "digest": {"gitCommit": commit},
                }
            ],
        },
        "runDetails": {
            "builder": {"id": "jenkins://securerag-hub-cd"},
            "metadata": {
                "invocationId": os.environ.get("BUILD_TAG", "local"),
                "startedOn": os.environ.get("BUILD_STARTED_AT", now),
                "finishedOn": now,
            },
            "byproducts": [
                {"uri": str(attestation_file), "digest": {"sha256": sha256(attestation_file)}},
                {"uri": str(digest_record), "digest": {"sha256": sha256(digest_record)}},
            ],
        },
        "securerag": {
            "status": status,
            "release_attestation_status": attestation_status,
            "subject_count": len(subjects),
            "note": "This is a repository-generated SLSA-style provenance statement. It is complete only when release-attestation.json is COMPLETE_PROVEN and promoted image digests are present.",
        },
    },
}

out_json.write_text(json.dumps(statement, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with out_md.open("w", encoding="utf-8") as handle:
    handle.write("# SLSA-style Provenance Statement - SecureRAG Hub\n\n")
    handle.write(f"- Generated at UTC: `{now}`\n")
    handle.write(f"- Status: `{status}`\n")
    handle.write(f"- Release attestation: `{attestation_status}`\n")
    handle.write(f"- Subject count: `{len(subjects)}`\n")
    handle.write(f"- JSON: `{out_json}`\n\n")
    handle.write("| Subject | Digest |\n")
    handle.write("|---|---|\n")
    if subjects:
        for subject in subjects:
            handle.write(f"| `{subject['name']}` | `sha256:{subject['digest']['sha256']}` |\n")
    else:
        handle.write("| n/a | no promoted digests available |\n")
    handle.write("\n## Honest interpretation\n\n")
    if status == "TERMINÉ":
        handle.write("The statement references promoted immutable digests and a COMPLETE_PROVEN release attestation.\n")
    else:
        handle.write("The statement is ready but not complete. Run the full supply chain with image scan, SBOM, Cosign sign/verify, digest promotion and release attestation first.\n")

PY

status="$(python3 - "${OUT_JSON}" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
print(payload["predicate"]["securerag"]["status"])
PY
)"

if [[ "${status}" != "TERMINÉ" ]] && is_true "${STRICT_PROVENANCE}"; then
  error "Provenance is not complete. See ${OUT_MD}"
  exit 1
fi

info "Provenance statement written to ${OUT_JSON} and ${OUT_MD}"
