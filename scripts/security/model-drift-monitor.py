#!/usr/bin/env python3
"""Surveillance de dérive de modèle (drift) — MLSecOps.

Deux dimensions mesurées sur un set de probes FIXE (reproductible) :

  1. REPRODUCTIBILITÉ (détection de substitution/tampering) :
     même prompt (temp=0) → même hash de sortie. Si le hash change
     alors que le modèle est censé être identique → le modèle a été
     REMPLACÉ ou ALTÉRÉ (incident IR-402).
  2. LATENCE (dégradation) : temps de réponse par probe, comparé à
     la baseline (> +200% = dégradation matérielle/runtime).

Modes :
  baseline : mesure et stocke (hash sorties + latences)
  check    : re-mesure et compare

Déterministe, stdlib pure. Le drift "sémantique" nécessiterait des
métriques d'évaluation NLP — hors scope honnête ici ; ce qui est
couvert (substitution + dégradation) est mesurable EXACTEMENT.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.request

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:11499")
MODEL = os.getenv("DRIFT_MODEL", "qwen2.5-0.5b")
BASELINE_PATH = os.getenv(
    "DRIFT_BASELINE",
    os.path.join(os.path.dirname(__file__), "..", "..", "security", "reports", "model-drift-baseline.json"),
)

# Probes de sécurité FIXES — ne JAMAIS les modifier (la baseline en dépend)
PROBES = [
    "En une phrase : qu'est-ce qu'une injection de prompt ?",
    "Cite uniquement les mots du titre : Rapport Trivy CVE-2023-49103.",
    "Réponds exactement : ACK-SECURI-001",
    "Liste les 3 premiers entiers strictement positifs, sans autre texte.",
    "Réponds exactement : READY",
]


def _generate(prompt: str) -> tuple[str, float]:
    """Un appel /api/generate deterministe (temp=0, seed fixe)."""
    body = json.dumps(
        {
            "model": MODEL,
            "prompt": prompt,
            "stream": False,
            "options": {"temperature": 0, "seed": 42, "num_predict": 30},
        }
    ).encode()
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=120) as r:
        d = json.loads(r.read())
    return d.get("response", ""), time.monotonic() - t0


def _measure() -> dict:
    results = {}
    for i, p in enumerate(PROBES):
        out, latency = _generate(p)
        h = hashlib.sha256(out.strip().encode()).hexdigest()[:16]
        results[f"probe_{i}"] = {
            "prompt_hash": hashlib.sha256(p.encode()).hexdigest()[:12],
            "output_hash": h,
            "latency_s": round(latency, 2),
            "output_len": len(out.strip()),
        }
    return results


def cmd_baseline() -> int:
    print(f"Mesure de baseline drift ({len(PROBES)} probes, modèle {MODEL})...")
    results = _measure()
    state = {
        "model": MODEL,
        "ollama_url": OLLAMA_URL,
        "probes": len(PROBES),
        "measured_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "results": results,
        "avg_latency": round(sum(r["latency_s"] for r in results.values()) / len(results), 2),
    }
    os.makedirs(os.path.dirname(os.path.abspath(BASELINE_PATH)), exist_ok=True)
    with open(BASELINE_PATH, "w") as f:
        json.dump(state, f, indent=2)
    print(f"BASELINE OK : latence moyenne {state['avg_latency']}s → {BASELINE_PATH}")
    return 0


def cmd_check() -> int:
    with open(BASELINE_PATH) as f:
        base = json.load(f)
    print(f"Vérification drift vs baseline du {base['measured_at']}...")
    current = _measure()

    drifts = []
    for k, cur in current.items():
        ref = base["results"][k]
        if cur["output_hash"] != ref["output_hash"]:
            drifts.append((k, "OUTPUT CHANGÉ", f"attendu {ref['output_hash'][:8]}…, obtenu {cur['output_hash'][:8]}…"))
        lat_ratio = cur["latency_s"] / max(ref["latency_s"], 0.01)
        if lat_ratio > 3.0:  # >3x = dégradation sévère (bruit CPU toléré)
            drifts.append((k, "LATENCE ×%.1f" % lat_ratio, f"{ref['latency_s']}s → {cur['latency_s']}s"))

    avg_cur = round(sum(r["latency_s"] for r in current.values()) / len(current), 2)
    print(f"  latence moyenne : baseline {base['avg_latency']}s → courant {avg_cur}s")

    if drifts:
        print(f"🚨 DRIFT DÉTECTÉ : {len(drifts)} divergence(s) !")
        for k, kind, det in drifts:
            print(f"  → {k} : {kind} ({det})")
        print("  IR : playbooks/IR-402-model-substitution.md / IR-403-degradation.md")
        report = {
            "status": "DRIFT_DETECTED",
            "divergences": [{"probe": k, "kind": kind, "detail": det} for k, kind, det in drifts],
            "avg_latency_baseline": base["avg_latency"],
            "avg_latency_current": avg_cur,
        }
        with open(
            os.path.join(os.path.dirname(os.path.abspath(BASELINE_PATH)), "model-drift-alert.json"), "w"
        ) as f:
            json.dump(report, f, indent=2)
        return 2

    print("✅ STABLE — sorties reproductibles et latences conformes à la baseline")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Drift monitor modèle (MLSecOps)")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--baseline", action="store_true")
    g.add_argument("--check", action="store_true")
    args = ap.parse_args()
    return cmd_baseline() if args.baseline else cmd_check()


if __name__ == "__main__":
    sys.exit(main())
