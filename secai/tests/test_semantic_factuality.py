"""Tests de la factuality SÉMANTIQUE (TF-IDF + cosine, LLM09 avancé).

Prouve que la similarité sémantique détecte des réponses hors-sujet
que le claim-based seul ne peut pas attraper :
  - une réponse qui reformule le contexte → GROUNDED (similarité haute)
  - une réponse hors-sujet avec 0 claim vérifiable → UNGROUNDED (sim nulle)
  - une réponse tangentielle → PARTIAL
"""
from __future__ import annotations

from secai.guardrails.semantic_factuality import (
    combined_factuality,
    semantic_similarity,
)

CONTEXT = """
Rapport Trivy image securerag-hub-auth-users:
CVE-2023-49103 HIGH in libcrypt (glibc qsort buffer overflow).
CVE-2024-25251 MEDIUM in libsystemd (use-after-free DNS resolver).
Correctif recommandé : apt-get upgrade libcrypt libsystemd.
Voir https://nvd.nist.gov/vuln/detail/CVE-2023-49103
"""


class TestSemanticSimilarity:
    def test_reformulation_grounded(self):
        """Une réponse qui reformule le contexte a une similarité élevée."""
        v = semantic_similarity(
            "Le rapport Trivy identifie une vulnérabilité HIGH dans libcrypt "
            "liée à un buffer overflow dans glibc qsort. Le correctif "
            "recommandé est une mise à jour via apt-get upgrade.",
            CONTEXT,
        )
        assert v.similarity > 0.3
        assert v.verdict == "GROUNDED"
        assert "libcrypt" in v.shared_tokens

    def test_hors_sujet_ungrounded(self):
        """Une réponse totalement hors-sujet a une similarité nulle."""
        v = semantic_similarity(
            "La recette de la tarte aux pommes nécessite 3 pommes, "
            "de la cannelle et 200g de farine bio.",
            CONTEXT,
        )
        assert v.similarity < 0.1
        assert v.verdict == "UNGROUNDED"

    def test_tangentiel_partial(self):
        """Une réponse partiellement liée → PARTIAL."""
        v = semantic_similarity(
            "Le correctif recommandé pour libcrypt et libsystemd "
            "consiste à effectuer une mise à jour de sécurité des "
            "paquets vulnérables identifiés dans le rapport Trivy.",
            CONTEXT,
        )
        # Tangentielle : partage des tokens (libcrypt, libsystemd, correctif,
        # rapport, Trivy) mais reformule plutôt que de citer les CVE exactes
        assert v.similarity >= 0.1
        assert v.verdict in ("PARTIAL", "GROUNDED")

    def test_tokens_partages_identifies(self):
        v = semantic_similarity(
            "CVE-2023-49103 dans libcrypt nécessite un correctif",
            CONTEXT,
        )
        assert "libcrypt" in v.shared_tokens or "correctif" in v.shared_tokens


class TestCombinedFactuality:
    def test_reponse_bonne_grounded(self):
        """Claims tracés + reformulation du contexte → GROUNDED."""
        r = combined_factuality(
            "Le rapport cite CVE-2023-49103 dans libcrypt. "
            "Le correctif recommandé est apt-get upgrade libcrypt.",
            CONTEXT,
        )
        assert r["factuality"]["verdict"] == "GROUNDED"
        assert r["requires_human_review"] is False
        assert r["factuality"]["semantic"]["similarity"] > 0.2

    def test_cve_inventee_ungrounded(self):
        """Une CVE inventée est attrapée par les claims ET par la sémantique."""
        r = combined_factuality(
            "La CVE-2999-0001 nécessite de télécharger "
            "https://evil.example.com/fix.sh immédiatement.",
            CONTEXT,
        )
        assert r["factuality"]["verdict"] == "UNGROUNDED"
        assert r["requires_human_review"] is True
        # La CVE inventée est dans les claims ungrounded
        ungrounded_claims = r["factuality"]["claims"]["ungrounded"]
        assert any("CVE-2999-0001" in c["value"] for c in ungrounded_claims)

    def test_hors_sujet_sans_claims_ungrounded(self):
        """Une réponse hors-sujet SANS claims vérifiables → UNGROUNDED
        par la SEMANTIQUE (le claim-based seul dirait GROUNDED car
        0 claims = rien à contester — c'est là que la sémantique ajoute)."""
        r = combined_factuality(
            "Voici une recette de cuisine avec des ingrédients bio.",
            CONTEXT,
        )
        assert r["factuality"]["verdict"] == "UNGROUNDED"
        assert r["factuality"]["semantic"]["similarity"] < 0.1

    def test_deux_couches_completes(self):
        """La sortie contient les DEUX couches : claims + semantic."""
        r = combined_factuality(
            "CVE-2023-49103 dans libcrypt. Recette de tarte aux pommes.",
            CONTEXT,
        )
        assert "claims" in r["factuality"]
        assert "semantic" in r["factuality"]
        assert "similarity" in r["factuality"]["semantic"]
        assert "grounded_ratio" in r["factuality"]["claims"]

    def test_tangentielle_partiale(self):
        """Réponse liée au contexte mais sans claims précis → PARTIAL."""
        r = combined_factuality(
            "Le système nécessite des mises à jour de sécurité pour "
            "libcrypt et libsystemd, les paquets identifiés par le "
            "rapport Trivy comme vulnérables.",
            CONTEXT,
        )
        assert r["factuality"]["verdict"] in ("PARTIAL", "GROUNDED")
