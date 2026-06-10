"""Fixtures partagées : embedder, fake QdrantManager, FastAPI test client."""
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence

import pytest
from qdrant_client.http import models as qm

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))


# ---------- Fake Qdrant ----------

class FakeScoredPoint:
    def __init__(self, id_: str, score: float, payload: Dict[str, Any]):
        self.id = id_
        self.score = score
        self.payload = payload


class FakeQdrantManager:
    """Implémentation en mémoire compatible avec QdrantManager (sous-ensemble utile)."""

    def __init__(self) -> None:
        self.collections: Dict[str, Dict[str, Any]] = {}

    def collection_exists(self, name: str) -> bool:
        return name in self.collections

    def create_collection(self, name: str, vector_size: int, distance_metric: str = "cosine", recreate: bool = False) -> None:
        if name in self.collections and not recreate:
            return
        self.collections[name] = {"size": vector_size, "distance": distance_metric, "points": {}}

    def get_collection_info(self, name: str) -> Dict[str, Any]:
        col = self.collections[name]
        return {
            "name": name,
            "vectors_count": len(col["points"]),
            "points_count": len(col["points"]),
            "status": "green",
        }

    def list_collections(self) -> List[Dict[str, Any]]:
        return [self.get_collection_info(n) for n in self.collections]

    def upsert_vectors(self, collection: str, vectors, payloads, ids=None) -> List[str]:
        if ids is None:
            ids = [str(i) for i in range(len(self.collections[collection]["points"]),
                                          len(self.collections[collection]["points"]) + len(vectors))]
        for pid, vec, payload in zip(ids, vectors, payloads):
            self.collections[collection]["points"][pid] = {"vector": list(vec), "payload": dict(payload)}
        return list(ids)

    @staticmethod
    def _cosine(a: Sequence[float], b: Sequence[float]) -> float:
        import math
        dot = sum(x * y for x, y in zip(a, b))
        na = math.sqrt(sum(x * x for x in a))
        nb = math.sqrt(sum(y * y for y in b))
        if na == 0 or nb == 0:
            return 0.0
        return dot / (na * nb)

    @staticmethod
    def _payload_matches(payload: Dict[str, Any], flt: Optional[qm.Filter]) -> bool:
        if flt is None:
            return True
        for cond in flt.must or []:
            key = cond.key
            value = payload.get(key)
            match = cond.match
            if isinstance(match, qm.MatchValue):
                if value != match.value:
                    return False
            elif isinstance(match, qm.MatchAny):
                allowed = match.any
                if isinstance(value, list):
                    if not any(v in allowed for v in value):
                        return False
                else:
                    if value not in allowed:
                        return False
        return True

    def search_similar(
        self,
        collection: str,
        query_vector,
        limit: int = 5,
        filters: Optional[qm.Filter] = None,
        score_threshold: Optional[float] = None,
    ):
        col = self.collections.get(collection)
        if not col:
            return []
        results: List[FakeScoredPoint] = []
        for pid, point in col["points"].items():
            if not self._payload_matches(point["payload"], filters):
                continue
            score = self._cosine(query_vector, point["vector"])
            if score_threshold is not None and score < score_threshold:
                continue
            results.append(FakeScoredPoint(pid, score, point["payload"]))
        results.sort(key=lambda r: r.score, reverse=True)
        return results[:limit]

    def delete_vectors(self, collection: str, ids):
        for pid in ids:
            self.collections[collection]["points"].pop(pid, None)

    def health_check(self) -> bool:
        return True


# ---------- Fake Embedder (deterministic, no model download) ----------

class FakeEmbedder:
    """Embedder déterministe basé sur le hash des tokens — pas de téléchargement modèle."""

    def __init__(self, dim: int = 16) -> None:
        self.expected_dimension = dim
        self.model_name = "fake-embedder"
        self.batch_size = 8

    def _vec(self, text: str) -> List[float]:
        import math
        v = [0.0] * self.expected_dimension
        for tok in text.lower().split():
            h = hash(tok)
            v[h % self.expected_dimension] += 1.0
        norm = math.sqrt(sum(x * x for x in v)) or 1.0
        return [x / norm for x in v]

    def embed_single(self, text: str) -> List[float]:
        if not text or not text.strip():
            raise ValueError("Cannot embed empty text")
        return self._vec(text)

    def embed_batch(self, texts):
        if not texts:
            return []
        cleaned = [t for t in texts if t and t.strip()]
        if not cleaned:
            raise ValueError("All input texts are empty")
        return [self._vec(t) for t in cleaned]

    def get_model_info(self):
        return {"model_name": self.model_name, "dimension": self.expected_dimension,
                "batch_size": self.batch_size, "normalized": True}


# ---------- Fixtures ----------

@pytest.fixture
def fake_embedder() -> FakeEmbedder:
    return FakeEmbedder()


@pytest.fixture
def fake_qdrant() -> FakeQdrantManager:
    return FakeQdrantManager()


@pytest.fixture
def patched_app(monkeypatch, fake_embedder, fake_qdrant):
    """Patche les singletons utilisés par FastAPI puis renvoie un TestClient."""
    import app.main as main_module
    from app import embedding, retrieval, vectorstore

    monkeypatch.setattr(embedding.embedder, "get_embedding_engine", lambda: fake_embedder)
    monkeypatch.setattr(vectorstore.qdrant_manager, "get_qdrant_manager", lambda: fake_qdrant)

    from app.retrieval.retrieval_engine import RetrievalEngine
    retrieval_engine = RetrievalEngine(embedder=fake_embedder, qdrant=fake_qdrant)
    monkeypatch.setattr(
        retrieval.retrieval_engine, "get_retrieval_engine", lambda: retrieval_engine
    )
    monkeypatch.setattr(main_module, "get_embedding_engine", lambda: fake_embedder)
    monkeypatch.setattr(main_module, "get_qdrant_manager", lambda: fake_qdrant)
    monkeypatch.setattr(main_module, "get_retrieval_engine", lambda: retrieval_engine)

    from fastapi.testclient import TestClient
    with TestClient(main_module.app) as client:
        yield client
