#!/usr/bin/env bash

set -euo pipefail

# Generate a local, non-destructive release attestation.
#
# This is not a replacement for Cosign keyless/key-based attestations. It is a
# factual evidence document that binds together git metadata, promoted digests,
# SBOM files and release proof artefacts. It can be archived in the support pack
# and, when Cosign is available, used as payload for a real attestation later.

REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
OUT_JSON="${OUT_JSON:-${REPORT_DIR}/release-attestation.json}"
OUT_MD="${OUT_MD:-${REPORT_DIR}/release-attestation.md}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-dev}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"

mkdir -p "${REPORT_DIR}"

python3 - "$OUT_JSON" "$OUT_MD" "$REPORT_DIR" "$SBOM_DIR" "$DIGEST_RECORD_FILE" "$REGISTRY_HOST" "$IMAGE_PREFIX" "$SOURCE_IMAGE_TAG" "$TARGET_IMAGE_TAG" <<'PY'
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

out_json, out_md, report_dir, sbom_dir, digest_file, registry, prefix, source_tag, target_tag = sys.argv[1:]
report_path = Path(report_dir)
sbom_path = Path(sbom_dir)
digest_path = Path(digest_file)

def run(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "unavailable"

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def file_state(path):
    p = Path(path)
    if not p.exists():
        return {"path": str(p), "status": "ABSENT"}
    return {
        "path": str(p),
        "status": "OK",
        "sha256": sha256_file(p),
        "size_bytes": p.stat().st_size,
    }

digests = []
if digest_path.exists():
    for line in digest_path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            digests.append(line.strip())

sboms = []
if sbom_path.exists():
    for path in sorted(sbom_path.rglob("*")):
        if path.is_file():
            sboms.append(file_state(path))

evidence_files = [
    report_path / "sign-summary.txt",
    report_path / "verify-summary.txt",
    report_path / "promotion-by-digest-summary.txt",
    report_path / "promotion-digests.txt",
    report_path / "sbom-summary.txt",
    report_path / "release-evidence.md",
    report_path / "supply-chain-evidence.md",
]

attestation = {
    "schema": "securerag.devsecops.release-attestation.v1",
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "project": "SecureRAG Hub",
    "official_scenario": "demo",
    "git": {
        "commit": run(["git", "rev-parse", "HEAD"]),
        "branch": run(["git", "rev-parse", "--abbrev-ref", "HEAD"]),
        "dirty": run(["git", "status", "--short"]) != "",
    },
    "release": {
        "registry": registry,
        "image_prefix": prefix,
        "source_tag": source_tag,
        "target_tag": target_tag,
        "promotion_strategy": "digest-first",
        "deploy_without_rebuild": True,
    },
    "digests": digests,
    "sboms": sboms,
    "evidence": [file_state(path) for path in evidence_files],
    "interpretation": {
        "OK": "Artefact present and hashable in this workspace.",
        "ABSENT": "Artefact not produced yet; execute the relevant gated step.",
        "dirty_git": "True means the attestation captures a local working tree state, not a clean commit."
    },
}

Path(out_json).write_text(json.dumps(attestation, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

ok_evidence = sum(1 for item in attestation["evidence"] if item["status"] == "OK")
md = [
    "# Release Attestation - SecureRAG Hub",
    "",
    f"- Generated at: `{attestation['generated_at']}`",
    f"- Git commit: `{attestation['git']['commit']}`",
    f"- Git branch: `{attestation['git']['branch']}`",
    f"- Working tree dirty: `{str(attestation['git']['dirty']).lower()}`",
    f"- Registry: `{registry}`",
    f"- Source tag: `{source_tag}`",
    f"- Target tag: `{target_tag}`",
    "",
    "## Chain of custody status",
    "",
    f"- Digest records: `{len(digests)}`",
    f"- SBOM artefacts: `{len(sboms)}`",
    f"- Evidence files present: `{ok_evidence}/{len(evidence_files)}`",
    "",
    "## Evidence files",
    "",
]

for item in attestation["evidence"]:
    if item["status"] == "OK":
        md.append(f"- OK `{item['path']}` sha256=`{item['sha256']}`")
    else:
        md.append(f"- ABSENT `{item['path']}`")

md.extend([
    "",
    "## Soutenance interpretation",
    "",
    "- This attestation is generated locally and is safe to archive.",
    "- A complete expert-level release also requires real SBOM, Cosign sign/verify and digest promotion artefacts.",
    "- If the working tree is dirty, present this as local evidence, not as an immutable released commit.",
])

Path(out_md).write_text("\n".join(md) + "\n", encoding="utf-8")
PY

printf 'Release attestation written to %s and %s\n' "${OUT_JSON}" "${OUT_MD}"
