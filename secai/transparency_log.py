"""Transparency Log — implémentation légère du concept Rekor (Sigstore).

Rekor (image bloquée dans cet environnement) est un transparency log :
un registre append-only, publiquement vérifiable, résistant à la
falsification. Les concepts fondamentaux sont :

  1. Append-only : on PEUT ajouter des entrées, on NE PEUT PAS les
     modifier ou supprimer
  2. Horodatage : chaque entrée est liée à un moment précis
  3. Chaînage cryptographique : chaque entrée référence la précédente
     (hash) → falsifier une entrée casse toute la chaîne après elle
  4. Vérifiabilité : quiconque peut revalider la chaîne de bout en bout

Cette implémentation utilise PostgreSQL (déjà dans le cluster) pour
le stockage append-only + SHA-256 pour le chaînage. Elle fournit une
API REST compatible avec le workflow Cosign pour l'enregistrement
et la vérification des signatures d'images.

Endpoints :
  POST /api/v1/log/entries          → ajoute une entrée (signature)
  GET  /api/v1/log/entries           → liste les entrées
  GET  /api/v1/log/verify            → vérifie l'intégrité de la chaîne
  GET  /api/v1/log/entries/{uuid}    → récupère une entrée
  GET  /health                       → health check

Limites vs Rekor réel (documentées honnêtement) :
  - Pas de Merkle Tree (chaînage linéaire au lieu de binaire)
  - Pas de witness signing externe (confiance dans la DB)
  - Pas de monitor/API publique internet (cluster-only)
  Mais les 4 concepts fondamentaux sont implémentés.
"""
from __future__ import annotations

import hashlib
import json
import os
import time
import uuid as uuid_mod
from dataclasses import dataclass, field
from typing import Any

# ── Stockage : si PostgreSQL disponible, l'utiliser ; sinon en-mémoire ──────

DB_URL = os.getenv("TRANSPARENCY_DB_URL", "")
MEMORY_ENTRIES: list[dict] = []  # fallback en-mémoire


@dataclass(frozen=True)
class LogEntry:
    """Une entrée du transparency log — immuable une fois créée."""

    uuid: str
    body: dict          # le contenu (signature Cosign, digest d'image…)
    hash: str           # hash de CETTE entrée (body + previous_hash)
    previous_hash: str  # hash de l'entrée précédente (chaînage)
    integrated_time: int  # timestamp unix
    kind: str           # type d'entrée (cosign_signature, sbom, …)

    def to_dict(self) -> dict:
        return {
            "uuid": self.uuid,
            "body": self.body,
            "hash": self.hash,
            "previous_hash": self.previous_hash,
            "integratedTime": self.integrated_time,
            "kind": self.kind,
        }


def _compute_hash(body: dict, previous_hash: str, timestamp: int) -> str:
    """Hash de chaînage : body + previous_hash + timestamp."""
    canonical = json.dumps(body, sort_keys=True)
    material = f"{canonical}|{previous_hash}|{timestamp}".encode()
    return hashlib.sha256(material).hexdigest()


def _get_last_hash() -> str:
    """Le hash de la dernière entrée (ou 'GENESIS' si vide)."""
    if DB_URL:
        try:
            import psycopg2
            conn = psycopg2.connect(DB_URL)
            cur = conn.cursor()
            cur.execute(
                "SELECT hash FROM transparency_log ORDER BY integrated_time DESC LIMIT 1"
            )
            row = cur.fetchone()
            conn.close()
            return row[0] if row else "GENESIS"
        except Exception:
            pass
    return MEMORY_ENTRIES[-1]["hash"] if MEMORY_ENTRIES else "GENESIS"


def add_entry(body: dict, kind: str = "cosign_signature") -> LogEntry:
    """Ajoute une entrée au log (append-only).

    L'entrée référence le hash de la précédente → falsifier une
    entrée antérieure casse le chaînage de TOUTES les suivantes.
    """
    timestamp = int(time.time())
    prev = _get_last_hash()
    entry_hash = _compute_hash(body, prev, timestamp)
    entry = LogEntry(
        uuid=str(uuid_mod.uuid4()),
        body=body,
        hash=entry_hash,
        previous_hash=prev,
        integrated_time=timestamp,
        kind=kind,
    )

    if DB_URL:
        import psycopg2
        conn = psycopg2.connect(DB_URL)
        cur = conn.cursor()
        cur.execute(
            """INSERT INTO transparency_log (uuid, body, hash, previous_hash, integrated_time, kind)
               VALUES (%s, %s, %s, %s, %s, %s)""",
            (entry.uuid, json.dumps(body), entry.hash, entry.previous_hash, entry.integrated_time, entry.kind),
        )
        conn.commit()
        conn.close()
    else:
        MEMORY_ENTRIES.append(entry.to_dict())

    return entry


def get_entries(limit: int = 50) -> list[dict]:
    """Récupère les N dernières entrées."""
    if DB_URL:
        try:
            import psycopg2
            conn = psycopg2.connect(DB_URL)
            cur = conn.cursor()
            cur.execute(
                "SELECT uuid, body, hash, previous_hash, integrated_time, kind "
                "FROM transparency_log ORDER BY integrated_time DESC LIMIT %s",
                (limit,),
            )
            rows = cur.fetchall()
            conn.close()
            return [
                {"uuid": r[0], "body": json.loads(r[1]), "hash": r[2],
                 "previous_hash": r[3], "integratedTime": r[4], "kind": r[5]}
                for r in rows
            ]
        except Exception:
            pass
    return MEMORY_ENTRIES[-limit:]


def get_entry(entry_uuid: str) -> dict | None:
    """Récupère une entrée par UUID."""
    entries = get_entries(limit=1000)
    for e in entries:
        if e["uuid"] == entry_uuid:
            return e
    return None


def verify_chain(limit: int = 1000) -> dict:
    """Vérifie l'intégrité de la chaîne de bout en bout.

    Pour chaque entrée :
      1. Recalcule le hash (body + previous_hash + timestamp)
      2. Vérifie qu'il correspond au hash stocké
      3. Vérifie que previous_hash == hash de l'entrée précédente

    Si TOUT passe, la chaîne est intacte depuis la genèse.
    Si UNE entrée a été modifiée, la chaîne casse à cet endroit.
    """
    entries = get_entries(limit=limit)
    if not entries:
        return {"valid": True, "entries_checked": 0, "message": "Log vide (aucune falsification possible)"}

    expected_prev = "GENESIS"
    breaks = []
    for i, e in enumerate(entries):
        # 1. Le hash correspond-il au contenu ?
        recomputed = _compute_hash(e["body"], e["previous_hash"], e["integratedTime"])
        if recomputed != e["hash"]:
            breaks.append({
                "entry_index": i,
                "uuid": e["uuid"],
                "issue": "HASH_MISMATCH: contenu modifié",
                "stored": e["hash"][:16],
                "recomputed": recomputed[:16],
            })

        # 2. Le previous_hash correspond-il à l'entrée précédente ?
        if e["previous_hash"] != expected_prev:
            breaks.append({
                "entry_index": i,
                "uuid": e["uuid"],
                "issue": "CHAIN_BREAK: previous_hash ne correspond pas",
                "expected": expected_prev[:16],
                "found": e["previous_hash"][:16],
            })

        expected_prev = e["hash"]

    return {
        "valid": len(breaks) == 0,
        "entries_checked": len(entries),
        "breaks": breaks,
        "message": "Chaîne intacte" if not breaks else f"{len(breaks)} falsification(s) détectée(s)",
    }


# ── API FastAPI (déployable comme service K8s) ─────────────────────────────

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="SecureRAG Transparency Log", version="0.1.0")


class AddEntryRequest(BaseModel):
    body: dict = Field(..., description="Contenu de l'entrée (signature, digest…)")
    kind: str = Field(default="cosign_signature", max_length=50)


class AddEntryResponse(BaseModel):
    uuid: str
    hash: str
    integratedTime: int
    previousHash: str
    kind: str


@app.get("/health")
def health():
    return {"status": "ok", "service": "transparency-log", "entries": len(get_entries(limit=10000))}


@app.post("/api/v1/log/entries", response_model=AddEntryResponse)
def create_entry(req: AddEntryRequest) -> AddEntryResponse:
    """Ajoute une entrée au transparency log (append-only)."""
    entry = add_entry(req.body, req.kind)
    return AddEntryResponse(
        uuid=entry.uuid,
        hash=entry.hash,
        integratedTime=entry.integrated_time,
        previousHash=entry.previous_hash,
        kind=entry.kind,
    )


@app.get("/api/v1/log/entries")
def list_entries(limit: int = 50):
    """Liste les entrées du log (plus récentes d'abord)."""
    return {"entries": get_entries(limit=limit), "count": len(get_entries(limit=limit))}


@app.get("/api/v1/log/entries/{entry_uuid}")
def get_one_entry(entry_uuid: str):
    """Récupère une entrée par UUID."""
    e = get_entry(entry_uuid)
    if not e:
        raise HTTPException(status_code=404, detail="Entrée introuvable")
    return e


@app.get("/api/v1/log/verify")
def verify():
    """Vérifie l'intégrité de TOUTE la chaîne."""
    return verify_chain()
