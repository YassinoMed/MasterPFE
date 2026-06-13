# Middleware de métriques pour FastAPI
#
# Collecte les métriques HTTP et les statistiques de pools de connexion.

from fastapi import FastAPI
from prometheus_client import Gauge
from prometheus_fastapi_instrumentator import Instrumentator

# Définition des gauges personnalisées
db_connections_active = Gauge(
    "db_connections_active",
    "Nombre de connexions SQL actives dans le pool."
)

redis_connections_active = Gauge(
    "redis_connections_active",
    "Nombre de connexions Redis actives dans le pool."
)

# Process memory est déjà exposé nativement par le process collector de prometheus_client.
# Cette gauge sert à s'assurer de sa présence ou à la peupler si nécessaire.
process_memory_bytes = Gauge(
    "process_memory_bytes",
    "Consommation mémoire du processus (bytes)."
)


def setup_metrics(app: FastAPI, engine=None, redis_client=None) -> None:
    """Configure l'instrumentateur FastAPI et enregistre les collecteurs."""
    instrumentator = Instrumentator(
        should_group_status_codes=True,
        should_ignore_untemplated=True,
    )

    @instrumentator.add_custom_metrics
    def collect_pool_metrics():
        # Extraction sécurisée des statistiques SQLAlchemy
        if engine and hasattr(engine, "pool"):
            db_connections_active.set(engine.pool.checkedout())
        else:
            db_connections_active.set(0)

        # Extraction sécurisée des statistiques Redis
        if redis_client and hasattr(redis_client, "connection_pool"):
            pool = redis_client.connection_pool
            if hasattr(pool, "_created_connections"):
                # Compatibilité avec le pool d'origine
                redis_connections_active.set(len(pool._created_connections))
            else:
                redis_connections_active.set(0)
        else:
            redis_connections_active.set(0)

        # Lecture de la mémoire du processus si possible
        try:
            import os
            import psutil
            process = psutil.Process(os.getpid())
            process_memory_bytes.set(process.memory_info().rss)
        except Exception:
            # Remplacement silencieux si indisponible
            process_memory_bytes.set(0)

    # Instrumente l'application et expose la route /metrics
    instrumentator.instrument(app).expose(app)
