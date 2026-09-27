"""Guardrail RATE-LIMIT — token bucket par client (OWASP LLM10).

Objectif : borner la consommation de ressources (Unbounded Consumption).
Un client ne peut déclencher qu'un maximum de requêtes LLM par fenêtre,
indépendamment de la taille des prompts (ceci est le garde-fou REQUESTE ;
le garde-fou TOKEN est max_length côté ConfigMap SECAI).

Implémentation : token bucket classique, temps monotonic, thread-safe
via un simple verrou — suffisant pour un runtime mono-process uvicorn.

Déterminisme : `capacity` jetons, `refill_per_second` jetons/s.
Un burst de `capacity` requêtes passe, puis 429 logique (allowed=False).
"""
from __future__ import annotations

import threading
import time
from collections import defaultdict


class TokenBucketLimiter:
    """Rate-limiter par client — thread-safe, sans dépendance externe."""

    def __init__(self, capacity: int = 5, refill_per_second: float = 1.0) -> None:
        if capacity < 1:
            raise ValueError("capacity doit être >= 1")
        if refill_per_second <= 0:
            raise ValueError("refill_per_second doit être > 0")
        self._capacity = capacity
        self._refill = refill_per_second
        self._buckets: dict[str, tuple[float, float]] = {}  # client -> (tokens, last_ts)
        self._lock = threading.Lock()

    def _now(self) -> float:
        """Horloge injectable pour les tests (peut être monkeypatchée)."""
        return time.monotonic()

    def allow(self, client_id: str) -> bool:
        """Consomme un jeton pour ce client. True si autorisé, False sinon."""
        with self._lock:
            tokens, last = self._buckets.get(client_id, (float(self._capacity), self._now()))
            now = self._now()
            elapsed = max(0.0, now - last)
            tokens = min(float(self._capacity), tokens + elapsed * self._refill)
            if tokens >= 1.0:
                self._buckets[client_id] = (tokens - 1.0, now)
                return True
            self._buckets[client_id] = (tokens, now)
            return False

    def remaining(self, client_id: str) -> float:
        """Jetons restants (approximatif — pour observabilité/métriques)."""
        with self._lock:
            tokens, last = self._buckets.get(client_id, (float(self._capacity), self._now()))
            elapsed = max(0.0, self._now() - last)
            return min(float(self._capacity), tokens + elapsed * self._refill)

    def reset(self) -> None:
        """Réinitialise tous les buckets (tests uniquement)."""
        with self._lock:
            self._buckets = defaultdict(lambda: (float(self._capacity), 0.0))
            self._buckets.clear()


_default_limiter = TokenBucketLimiter(capacity=5, refill_per_second=1.0)


def default_limiter() -> TokenBucketLimiter:
    """Limiter partagé pour l'API SECAI (5 req burst, 1 req/s soutenu)."""
    return _default_limiter
