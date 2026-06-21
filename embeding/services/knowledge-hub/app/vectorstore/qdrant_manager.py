"""Gestionnaire Qdrant : CRUD vectoriel + filtrage RBAC."""
from __future__ import annotations

import time
import uuid
from typing import Any, Dict, List, Optional, Sequence

import structlog
from qdrant_client import QdrantClient
from qdrant_client.http import models as qm
from qdrant_client.http.exceptions import UnexpectedResponse

from app.config import get_settings

logger = structlog.get_logger(__name__)


DISTANCE_MAP = {
    "cosine": qm.Distance.COSINE,
    "dot": qm.Distance.DOT,
    "euclid": qm.Distance.EUCLID,
}


class QdrantManager:
    """Wrapper de QdrantClient avec retries et helpers RBAC."""

    def __init__(
        self,
        host: str | None = None,
        port: int | None = None,
        api_key: str | None = None,
        timeout: float | None = None,
        retries: int | None = None,
    ) -> None:
        settings = get_settings()
        self.host = host or settings.qdrant_host
        self.port = port or settings.qdrant_port
        self.api_key = api_key if api_key is not None else settings.qdrant_api_key
        self.timeout = timeout or settings.qdrant_timeout
        self.retries = retries or settings.qdrant_retries

        self._client = QdrantClient(
            host=self.host,
            port=self.port,
            api_key=self.api_key,
            timeout=self.timeout,
        )
        logger.info("qdrant_client_initialized", host=self.host, port=self.port)

    # ---------- internal retry helper ----------

    def _with_retry(self, op_name: str, fn, *args, **kwargs):
        last_exc: Exception | None = None
        for attempt in range(1, self.retries + 1):
            try:
                return fn(*args, **kwargs)
            except (UnexpectedResponse, ConnectionError, TimeoutError) as exc:
                last_exc = exc
                logger.warning(
                    "qdrant_op_failed",
                    op=op_name,
                    attempt=attempt,
                    retries=self.retries,
                    error=str(exc),
                )
                if attempt < self.retries:
                    time.sleep(min(2 ** attempt, 5))
        assert last_exc is not None
        raise last_exc

    # ---------- collections ----------

    def collection_exists(self, name: str) -> bool:
        try:
            collections = self._client.get_collections().collections
            return any(c.name == name for c in collections)
        except Exception as exc:
            logger.error("collection_exists_failed", name=name, error=str(exc))
            return False

    def create_collection(
        self,
        name: str,
        vector_size: int,
        distance_metric: str = "cosine",
        recreate: bool = False,
    ) -> None:
        distance = DISTANCE_MAP.get(distance_metric.lower(), qm.Distance.COSINE)
        if self.collection_exists(name):
            if not recreate:
                logger.info("collection_already_exists", name=name)
                return
            logger.info("collection_recreate", name=name)
            self._client.delete_collection(collection_name=name)

        self._with_retry(
            "create_collection",
            self._client.create_collection,
            collection_name=name,
            vectors_config=qm.VectorParams(size=vector_size, distance=distance),
        )
        logger.info(
            "collection_created", name=name, size=vector_size, distance=distance_metric
        )

    def get_collection_info(self, name: str) -> Dict[str, Any]:
        info = self._with_retry("get_collection", self._client.get_collection, name)
        return {
            "name": name,
            "vectors_count": info.vectors_count or 0,
            "points_count": info.points_count or 0,
            "status": str(info.status),
        }

    def list_collections(self) -> List[Dict[str, Any]]:
        cols = self._client.get_collections().collections
        return [self.get_collection_info(c.name) for c in cols]

    # ---------- vectors ----------

    def upsert_vectors(
        self,
        collection: str,
        vectors: Sequence[Sequence[float]],
        payloads: Sequence[Dict[str, Any]],
        ids: Optional[Sequence[str]] = None,
    ) -> List[str]:
        if len(vectors) != len(payloads):
            raise ValueError("vectors and payloads must have the same length")
        if ids is None:
            ids = [str(uuid.uuid4()) for _ in vectors]
        elif len(ids) != len(vectors):
            raise ValueError("ids must match vectors length")

        points = [
            qm.PointStruct(id=pid, vector=list(vec), payload=dict(payload))
            for pid, vec, payload in zip(ids, vectors, payloads)
        ]
        self._with_retry(
            "upsert",
            self._client.upsert,
            collection_name=collection,
            points=points,
            wait=True,
        )
        logger.info("vectors_upserted", collection=collection, count=len(points))
        return list(ids)

    def search_similar(
        self,
        collection: str,
        query_vector: Sequence[float],
        limit: int = 5,
        filters: Optional[qm.Filter] = None,
        score_threshold: Optional[float] = None,
    ) -> List[qm.ScoredPoint]:
        results = self._with_retry(
            "search",
            self._client.search,
            collection_name=collection,
            query_vector=list(query_vector),
            limit=limit,
            query_filter=filters,
            score_threshold=score_threshold,
            with_payload=True,
        )
        logger.debug(
            "search_done",
            collection=collection,
            hits=len(results),
            limit=limit,
            threshold=score_threshold,
        )
        return results

    def delete_vectors(self, collection: str, ids: Sequence[str]) -> None:
        self._with_retry(
            "delete",
            self._client.delete,
            collection_name=collection,
            points_selector=qm.PointIdsList(points=list(ids)),
            wait=True,
        )
        logger.info("vectors_deleted", collection=collection, count=len(ids))

    # ---------- health ----------

    def health_check(self) -> bool:
        try:
            self._client.get_collections()
            return True
        except Exception as exc:
            logger.error("qdrant_health_failed", error=str(exc))
            return False


# ---------- RBAC filter helper ----------

def rbac_filter(user_role: str, chatbot_domain: str) -> qm.Filter:
    """Construit le filtre Qdrant qui applique le RBAC vectoriel.

    Un point n'est retourné que si :
      - son `chatbot_domain` correspond à celui demandé,
      - son `allowed_roles` contient le rôle de l'utilisateur.
    """
    return qm.Filter(
        must=[
            qm.FieldCondition(
                key="chatbot_domain",
                match=qm.MatchValue(value=chatbot_domain),
            ),
            qm.FieldCondition(
                key="allowed_roles",
                match=qm.MatchAny(any=[user_role]),
            ),
        ]
    )


_manager_singleton: QdrantManager | None = None


def get_qdrant_manager() -> QdrantManager:
    global _manager_singleton
    if _manager_singleton is None:
        _manager_singleton = QdrantManager()
    return _manager_singleton
