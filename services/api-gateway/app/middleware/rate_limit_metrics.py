# Middleware de métriques pour le rate limiting (api-gateway)
#
# Incrémente un compteur lors des rejets par rate limiting.

import hashlib
from fastapi import Request, Response
from fastapi.responses import JSONResponse
from prometheus_client import Counter
from slowapi.errors import RateLimitExceeded

api_rate_limit_rejections_total = Counter(
    "api_rate_limit_rejections_total",
    "Nombre total de requetes rejetees par rate limiting.",
    labelnames=["client_ip_hash", "endpoint"]
)


def register_rate_limit_metrics_handler(app) -> None:
    """Enregistre le gestionnaire d'exception pour les quotas."""
    @app.exception_handler(RateLimitExceeded)
    async def rate_limit_handler(
        request: Request,
        exc: RateLimitExceeded
    ) -> Response:
        # Hachage SHA256 tronqué de l'IP du client
        client_ip = request.client.host if request.client else "unknown"
        ip_hash = hashlib.sha256(client_ip.encode("utf-8")).hexdigest()[:16]
        endpoint = request.url.path

        api_rate_limit_rejections_total.labels(
            client_ip_hash=ip_hash,
            endpoint=endpoint
        ).inc()

        return JSONResponse(
            status_code=429,
            content={"detail": "Rate limit exceeded"}
        )
