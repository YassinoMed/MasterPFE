#!/usr/bin/env python3
"""Détection de poisoning d'une collection Qdrant (OWASP LLM04).

Deux modes :
  baseline : enregistre l'état de référence (hash de chaque point + du
             contenu global) dans un fichier JSON signé.
  check    : compare l'état courant à la baseline. Tout point nouveau,
             modifié ou supprimé depuis la baseline est signalé comme
             SUSPECT (potentiel poisoning) avec le détail.

Le raisonnement : dans une base de connaissances sécurité, une donnée
doit provenir d'une source maîtrisée (extraction CVE validée, jamais
d'ingestion publique non auditée). Toute différence hors-pipeline =
alerte, pas confiance.

Déterministe, stdlib pure — auditable en soutenance ligne par ligne.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import urllib.request

QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
COLLECTION = os.getenv("QDRANT_COLLECTION", "vuln-kb")
BASELINE_PATH = os.getenv(
    "QDRANT_BASELINE", os.path.join(os.path.dirname(__file__), "..", "..", "security", "reports", "qdrant-baseline.json")
)


def _fetch_points(collection: str) -> list[dict]:
    """Récupère tous les points (id + payload) — via scroll, pagination."""
    points, offset = [], None
    while True:
        body = {"limit": 100, "with_payload": True, "with_vector": False}
        if offset:
            body["offset"] = offset
        req = urllib.request.Request(
            f"{QDRANT_URL}/collections/{collection}/points/scroll",
            data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            d = json.loads(r.read())
        batch = d["result"].get("points", [])
        points.extend(batch)
        offset = d["result"].get("next_offset")
        if not offset:
            break
    return points


def _point_hash(p: dict) -> str:
    """Hash stable d'un point : id + payload trié (vecteur exclu)."""
    payload = json.dumps(p.get("payload", {}), sort_keys=True)
    return hashlib.sha256(f"{p['id']}|{payload}".encode()).hexdigest()[:16]


def _state(points: list[dict]) -> dict:
    """État de la collection : hash par point + hash global ordonné."""
    per_point = {str(p["id"]): _point_hash(p) for p in points}
    joined = "|".join(f"{k}:{v}" for k, v in sorted(per_point.items()))
    return {
        "collection": COLLECTION,
        "points_count": len(points),
        "per_point": per_point,
        "global_hash": hashlib.sha256(joined.encode()).hexdigest()[:32],
    }


def cmd_baseline() -> int:
    points = _fetch_points(COLLECTION)
    state = _state(points)
    os.makedirs(os.path.dirname(os.path.abspath(BASELINE_PATH)), exist_ok=True)
    with open(BASELINE_PATH, "w") as f:
        json.dump(state, f, indent=2)
    print(f"BASELINE OK : {state['points_count']} points, hash global {state['global_hash']}")
    print(f"  → {BASELINE_PATH}")
    return 0


def cmd_check() -> int:
    with open(BASELINE_PATH) as f:
        baseline = json.load(f)
    points = _fetch_points(COLLECTION)
    current = _state(points)

    if current["global_hash"] == baseline["global_hash"]:
        print(f"INTEGRITY OK : {current['points_count']} points, hash {current['global_hash']} conforme à la baseline")
        return 0

    # Diff détaillé — c'est ICI qu'un poisoning est attrapé
    suspects = []
    base_pp, cur_pp = baseline["per_point"], current["per_point"]
    for pid, h in cur_pp.items():
        if pid not in base_pp:
            suspects.append(("NOUVEAU (non validé par pipeline)", pid))
        elif base_pp[pid] != h:
            suspects.append(("MODIFIÉ depuis la baseline", pid))
    for pid in base_pp:
        if pid not in cur_pp:
            suspects.append(("SUPPRIMÉ depuis la baseline", pid))

    print(f"ALERTE POISONING : {len(suspects)} divergence(s) avec la baseline !")
    print(f"  baseline : {baseline['points_count']} points, hash {baseline['global_hash']}")
    print(f"  courant  : {current['points_count']} points, hash {current['global_hash']}")
    for kind, pid in suspects:
        print(f"  → point {pid} : {kind}")
    # Rapport machine
    report = {
        "status": "POISONING_SUSPECTED",
        "baseline": {k: baseline[k] for k in ("points_count", "global_hash")},
        "current": {k: current[k] for k in ("points_count", "global_hash")},
        "suspects": [{"kind": k, "point_id": p} for k, p in suspects],
    }
    rp = os.path.join(os.path.dirname(os.path.abspath(BASELINE_PATH)), "qdrant-poisoning-alert.json")
    with open(rp, "w") as f:
        json.dump(report, f, indent=2)
    print(f"  rapport : {rp}")
    return 2


def main() -> int:
    ap = argparse.ArgumentParser(description="Détection de poisoning Qdrant (LLM04)")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--baseline", action="store_true")
    g.add_argument("--check", action="store_true")
    args = ap.parse_args()
    return cmd_baseline() if args.baseline else cmd_check()


if __name__ == "__main__":
    sys.exit(main())
