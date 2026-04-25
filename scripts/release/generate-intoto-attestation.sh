#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/release}"
ATTESTATION_FILE="${ATTESTATION_FILE:-${REPORT_DIR}/release-attestation.json}"
PROVENANCE_FILE="${PROVENANCE_FILE:-${REPORT_DIR}/provenance.slsa.json}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
OUTPUT_JSON="${OUTPUT_JSON:-${REPORT_DIR}/intoto-attestation.json}"
OUTPUT_MD="${OUTPUT_MD:-${REPORT_DIR}/intoto-attestation.md}"

mkdir -p "${REPORT_DIR}"

python3 - "${ATTESTATION_FILE}" "${PROVENANCE_FILE}" "${DIGEST_RECORD_FILE}" "${OUTPUT_JSON}" "${OUTPUT_MD}" <<'PY'
import datetime as dt
import json
import pathlib
import sys

attestation_path, provenance_path, digest_path, output_json, output_md = map(pathlib.Path, sys.argv[1:])

status = "PRÊT_NON_EXÉCUTÉ"
detail = []
subjects = []

if attestation_path.exists() and provenance_path.exists() and digest_path.exists():
    status = "TERMINÉ"
    detail.append("release attestation, SLSA-style provenance and digest manifest are present")
    for line in digest_path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) >= 4:
            service, _source, target, digest = parts[:4]
            subjects.append({"name": service, "uri": target, "digest": {"sha256": digest.replace("sha256:", "")}})
else:
    missing = [str(p) for p in (attestation_path, provenance_path, digest_path) if not p.exists()]
    detail.append("missing evidence: " + ", ".join(missing))

payload = {
    "_type": "https://in-toto.io/Statement/v1",
    "subject": subjects,
    "predicateType": "https://securerag.dev/predicate/release-supply-chain/v1",
    "predicate": {
        "status": status,
        "generatedAt": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "releaseAttestation": str(attestation_path),
        "provenance": str(provenance_path),
        "digestRecord": str(digest_path),
        "detail": detail,
    },
}

output_json.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
output_md.write_text(
    "# in-toto Release Attestation - SecureRAG Hub\n\n"
    f"- Generated at UTC: `{payload['predicate']['generatedAt']}`\n"
    f"- Status: `{status}`\n"
    f"- JSON statement: `{output_json}`\n"
    f"- Subjects: `{len(subjects)}`\n\n"
    "## Detail\n\n" + "\n".join(f"- {item}" for item in detail) + "\n",
    encoding="utf-8",
)
PY

printf '[INFO] in-toto attestation written to %s and %s\n' "${OUTPUT_JSON}" "${OUTPUT_MD}"
