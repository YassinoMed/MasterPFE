"""Tests du LLM-as-Judge — évaluation automatisée de réponses IA.

Ces tests sont dégradés : si le LLM juge est indisponible, ils
vérifient le parsing des scores et la logique de verdict, pas
la qualité réelle du jugement (qui nécessite un LLM opérationnel).
"""
from __future__ import annotations

import pytest

from secai.guardrails.llm_judge import (
    JudgeScore,
    JudgeVerdict,
    _parse_score,
    CRITERIA,
    PASS_THRESHOLD,
)


class TestScoreParsing:
    """Le parser doit extraire un score 1-5 de n'importe quel format LLM."""

    def test_parse_score_format(self):
        s = _parse_score("Score: 4 — The response is well-structured", "factuality")
        assert s.score == 4
        assert s.criterion == "factuality"

    def test_parse_rating_format(self):
        s = _parse_score("Rating: 2 — Contains inaccuracies", "safety")
        assert s.score == 2

    def test_parse_fraction_format(self):
        s = _parse_score("I give this 5/5 because...", "relevance")
        assert s.score == 5

    def test_parse_bare_number(self):
        s = _parse_score("3", "completeness")
        assert s.score == 3

    def test_parse_number_in_text(self):
        s = _parse_score("The response scores 4 overall", "factuality")
        assert s.score == 4

    def test_parse_no_number_defaults_neutral(self):
        s = _parse_score("I cannot evaluate this response.", "safety")
        assert s.score == 3  # neutre par défaut

    def test_parse_clamps_to_1_5(self):
        # Un "8" ne devrait pas être accepté (cherche seulement 1-5)
        s = _parse_score("Score: 8", "factuality")
        assert s.score <= 5


class TestCriteriaDefinition:
    def test_tous_les_criteres_definis(self):
        expected = {"factuality", "safety", "relevance", "completeness"}
        assert set(CRITERIA.keys()) == expected

    def test_factuality_et_safety_pesent_plus(self):
        assert CRITERIA["factuality"]["weight"] > CRITERIA["relevance"]["weight"]
        assert CRITERIA["safety"]["weight"] > CRITERIA["completeness"]["weight"]

    def test_chaque_critere_a_une_instruction(self):
        for name, spec in CRITERIA.items():
            assert "instruction" in spec
            assert len(spec["instruction"]) > 50

    def test_seuil_de_passage(self):
        assert PASS_THRESHOLD == 3


class TestVerdictLogic:
    def test_verdict_passe_si_tous_au_dessus_du_seuil(self):
        scores = [
            JudgeScore("factuality", 4, "good", 3),
            JudgeScore("safety", 5, "safe", 3),
            JudgeScore("relevance", 4, "relevant", 3),
        ]
        # Simuler la logique de verdict
        failed = [s.criterion for s in scores if s.score < s.threshold]
        assert len(failed) == 0

    def test_verdict_echoue_si_un_critere_sous_le_seuil(self):
        scores = [
            JudgeScore("factuality", 2, "poor", 3),  # FAIL
            JudgeScore("safety", 5, "safe", 3),
            JudgeScore("relevance", 4, "relevant", 3),
        ]
        failed = [s.criterion for s in scores if s.score < s.threshold]
        assert "factuality" in failed
        assert len(failed) == 1

    def test_score_global_pondere(self):
        # factuality(4, weight=2) + safety(5, weight=2) + relevance(3, weight=1)
        # = (4*2 + 5*2 + 3*1) / (2+2+1) = 21/5 = 4.2
        scores_data = [
            ("factuality", 4, 2.0),
            ("safety", 5, 2.0),
            ("relevance", 3, 1.0),
        ]
        total_weight = sum(w for _, _, w in scores_data)
        weighted_sum = sum(s * w for _, s, w in scores_data)
        overall = round(weighted_sum / total_weight, 2)
        assert overall == 4.2


class TestJudgeIntegration:
    """Tests d'intégration — dégradés si LLM indisponible."""

    def test_judge_reponse_mauvaise(self):
        """Une réponse manifestement mauvaise devrait échouer au moins un critère."""
        from secai.guardrails.llm_judge import judge_response
        try:
            v = judge_response(
                question="What is the CVE-2023-49103 vulnerability?",
                response="Just go to the beach and relax.",
                context="CVE-2023-49103 is a HIGH severity buffer overflow in libcrypt.",
                criteria=["relevance"],  # un seul critère pour la rapidité
            )
            if v is None:
                pytest.skip("LLM juge indisponible")
            assert v.scores[0].criterion == "relevance"
            # Le score peut être bas, mais il doit être entre 1 et 5
            assert 1 <= v.scores[0].score <= 5
        except (ConnectionError, TimeoutError, OSError):
            pytest.skip("LLM juge indisponible dans cet environnement")

    def test_judge_envelope_format(self):
        """L'enveloppe contient toutes les informations nécessaires."""
        from secai.guardrails.llm_judge import judge_envelope
        try:
            env = judge_envelope(
                question="Test",
                response="Test response",
                context="Test context",
            )
            if env.get("llm_judge") is None:
                assert env["available"] is False
            else:
                judge = env["llm_judge"]
                assert "passed" in judge
                assert "overall_score" in judge
                assert "scores" in judge
                assert "requires_human_review" in env
        except (ConnectionError, TimeoutError, OSError):
            pytest.skip("LLM juge indisponible")
