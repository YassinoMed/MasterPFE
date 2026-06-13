# Code de définition des métriques pour rag-service
#
# Métriques personnalisées RAG et base vectorielle.

from prometheus_client import Counter, Gauge, Histogram

# Métriques RAG
rag_embedding_duration_seconds = Histogram(
    "rag_embedding_duration_seconds",
    "Durée de génération des plongements vectoriels.",
    labelnames=["model_name"],
)

rag_retrieval_duration_seconds = Histogram(
    "rag_retrieval_duration_seconds",
    "Durée de recherche dans la base vectorielle.",
    labelnames=["collection_name"],
)

rag_llm_latency_seconds = Histogram(
    "rag_llm_latency_seconds",
    "Temps de réponse du grand modèle de langage.",
    labelnames=["model_name", "endpoint"],
    buckets=[0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 30.0, 60.0],
)

rag_tokens_total = Counter(
    "rag_tokens_total",
    "Volume total de jetons consommés par le modèle.",
    labelnames=["direction", "model_name"],
)

rag_cache_requests_total = Counter(
    "rag_cache_requests_total",
    "Statistiques de requêtes sur le cache sémantique.",
    labelnames=["result"],
)

# Métriques de base vectorielle (ChromaDB) — Gap 5
vectordb_collection_size_vectors = Gauge(
    "vectordb_collection_size_vectors",
    "Nombre total de vecteurs stockés dans la collection.",
    labelnames=["collection_name"],
)

vectordb_index_duration_seconds = Histogram(
    "vectordb_index_duration_seconds",
    "Durée d'indexation des nouveaux vecteurs.",
)
