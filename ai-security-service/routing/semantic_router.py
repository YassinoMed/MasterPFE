"""
Layer 3 — Semantic Router.

Analyses user prompts and routes them to the appropriate expert AI model
(CyberSecurityAgent or DevOpsAgent) based on semantic similarity using
TF-IDF vectorisation against predefined category keyword corpora.

Easily extensible: add new categories in config/config.py.
"""

import logging
from typing import Dict, Any, List, Tuple

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from config.config import ROUTING_CATEGORIES, CATEGORY_MODEL_MAP, get_settings

logger = logging.getLogger("ai-security-pipeline.semantic-router")


class SemanticRouter:
    """
    TF-IDF-based Semantic Router for intelligent model selection.

    On initialisation, builds a TF-IDF corpus from all category keywords.
    At routing time, vectorises the user prompt and finds the best-matching
    category via cosine similarity, then maps it to the appropriate model.
    """

    def __init__(
        self,
        categories: Dict[str, List[str]] = None,
        model_map: Dict[str, str] = None,
        default_model: str = None,
        confidence_threshold: float = None,
    ):
        settings = get_settings()
        self.categories = categories or ROUTING_CATEGORIES
        self.model_map = model_map or CATEGORY_MODEL_MAP
        self.default_model = default_model or settings.ROUTER_DEFAULT_MODEL
        self.confidence_threshold = confidence_threshold or settings.ROUTER_CONFIDENCE_THRESHOLD

        # Build TF-IDF model from category keyword corpora
        self._category_names: List[str] = []
        self._corpus: List[str] = []

        for cat_name, keywords in self.categories.items():
            self._category_names.append(cat_name)
            # Join all keywords into a single document per category
            self._corpus.append(" ".join(keywords))

        self._vectorizer = TfidfVectorizer(
            lowercase=True,
            stop_words="english",
            ngram_range=(1, 2),
        )
        self._tfidf_matrix = self._vectorizer.fit_transform(self._corpus)

        logger.info(
            "SemanticRouter initialised with %d categories",
            len(self._category_names),
        )

    # ── Public API ─────────────────────────────────────────────

    def route(self, prompt: str) -> str:
        """
        Route a user prompt to the appropriate expert model.

        Args:
            prompt: The user's natural-language query.

        Returns:
            Model name: "CyberSecurityAgent" or "DevOpsAgent"
        """
        result = self.route_detailed(prompt)
        return result["model"]

    def route_detailed(self, prompt: str) -> Dict[str, Any]:
        """
        Route with full detail — returns category, model, confidence, and
        all category scores.

        Returns:
            dict with keys:
                model: str — the chosen model name
                category: str — the matched category
                confidence: float — cosine similarity score (0-1)
                scores: dict — all category scores
        """
        # Vectorise the user prompt
        prompt_vec = self._vectorizer.transform([prompt.lower()])

        # Compute cosine similarity against all categories
        similarities = cosine_similarity(prompt_vec, self._tfidf_matrix)[0]

        # Build scores dict
        scores = {
            cat: round(float(sim), 4)
            for cat, sim in zip(self._category_names, similarities)
        }

        # Find best match
        best_idx = similarities.argmax()
        best_score = float(similarities[best_idx])
        best_category = self._category_names[best_idx]

        # Apply confidence threshold
        if best_score < self.confidence_threshold:
            logger.info(
                "Low confidence routing (%.4f < %.4f) — defaulting to %s",
                best_score,
                self.confidence_threshold,
                self.default_model,
            )
            return {
                "model": self.default_model,
                "category": "default",
                "confidence": round(best_score, 4),
                "scores": scores,
            }

        chosen_model = self.model_map.get(best_category, self.default_model)
        logger.info(
            "Routing to %s (category=%s, confidence=%.4f)",
            chosen_model,
            best_category,
            best_score,
        )

        return {
            "model": chosen_model,
            "category": best_category,
            "confidence": round(best_score, 4),
            "scores": scores,
        }

    def get_categories(self) -> List[str]:
        """List all registered routing categories."""
        return list(self.categories.keys())

    def add_category(
        self,
        name: str,
        keywords: List[str],
        model: str,
    ) -> None:
        """
        Dynamically add a new routing category.

        Args:
            name: Category name (lowercase, underscore-separated)
            keywords: List of keywords for this category
            model: Model name to route to (CyberSecurityAgent or DevOpsAgent)
        """
        self.categories[name] = keywords
        self.model_map[name] = model

        # Rebuild TF-IDF model
        self._category_names.append(name)
        self._corpus.append(" ".join(keywords))
        self._tfidf_matrix = self._vectorizer.fit_transform(self._corpus)

        logger.info(
            "Added category '%s' → %s (%d keywords)",
            name,
            model,
            len(keywords),
        )
