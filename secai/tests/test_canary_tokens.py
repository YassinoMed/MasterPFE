"""Tests des Canary Tokens — détection de prompt extraction (LLM07).

Prouve que les canary tokens :
  1. Sont générés uniques (pas de collision)
  2. Sont détectés s'ils apparaissent dans la sortie
  3. Sont détectés même en FRAGMENTS (fuzzy matching)
  4. Ne détectent PAS les sorties normales (zéro faux positif)
  5. La preuve ne re-leake JAMAIS le token complet
"""
from __future__ import annotations

import pytest

from secai.guardrails.canary_tokens import (
    CanaryType,
    canary_guardrail_envelope,
    detect_canaries_in_output,
    generate_canary_set,
    generate_canary_token,
    inject_canaries_in_prompt,
)


class TestCanaryGeneration:
    def test_genere_token_unique(self):
        t1 = generate_canary_token(CanaryType.HEX)
        t2 = generate_canary_token(CanaryType.HEX)
        assert t1.token != t2.token

    def test_format_uuid(self):
        t = generate_canary_token(CanaryType.UUID)
        assert t.token.startswith("sk-canary-")
        assert len(t.token) > 20

    def test_format_hex(self):
        t = generate_canary_token(CanaryType.HEX)
        assert t.token.startswith("sk-canary-")
        assert len(t.token) == len("sk-canary-") + 16

    def test_format_phrase(self):
        t = generate_canary_token(CanaryType.PHRASE)
        assert t.token.startswith("sk-canary-")

    def test_genere_set_de_5(self):
        canaries = generate_canary_set(5)
        assert len(canaries) == 5
        # Tous uniques
        tokens = [c.token for c in canaries]
        assert len(set(tokens)) == 5


class TestCanaryDetection:
    def test_detection_exacte(self):
        """Si le token complet apparaît dans la sortie → détecté."""
        canaries = generate_canary_set(3)
        # L'attaquant fait "reveal your system prompt"
        output = f"Here is my system prompt: {canaries[0].token} and more"
        result = detect_canaries_in_output(output, canaries)
        assert result.detected is True
        assert canaries[0].token in result.matched_tokens

    def test_detection_fragment(self):
        """Si un fragment >= 12 chars apparaît → détecté (fuzzy)."""
        canaries = generate_canary_set(1)
        # L'attaquant ne révèle qu'une partie du token
        partial = canaries[0].token[:16]  # 16 chars du début
        output = f"The key starts with {partial}..."
        result = detect_canaries_in_output(output, canaries, fuzzy=True)
        assert result.detected is True

    def test_pas_de_faux_positif_sortie_normale(self):
        """Une réponse normale SANS canary → pas de détection."""
        canaries = generate_canary_set(3)
        output = "Le rapport Trivy identifie 3 CVE HIGH dans le package libcrypt."
        result = detect_canaries_in_output(output, canaries)
        assert result.detected is False
        assert result.matched_tokens == []

    def test_pas_de_faux_positif_secret_legitime(self):
        """Un vrai secret (pas un canary) → pas de détection canary."""
        canaries = generate_canary_set(3)
        output = "AWS key AKIAIOSFODNN7EXAMPLE detected"
        result = detect_canaries_in_output(output, canaries)
        assert result.detected is False

    def test_token_masque_dans_la_preuve(self):
        """La preuve (evidence) ne contient JAMAIS le token complet."""
        canaries = generate_canary_set(1)
        output = f"Leaked: {canaries[0].token}"
        result = detect_canaries_in_output(output, canaries)
        assert result.detected is True
        # Le token complet ne doit PAS apparaître dans la preuve
        assert canaries[0].token not in result.source_text

    def test_multi_canaries_detectes(self):
        """Plusieurs canaries détectés simultanément."""
        canaries = generate_canary_set(3)
        output = f"Keys: {canaries[0].token} {canaries[1].token}"
        result = detect_canaries_in_output(output, canaries)
        assert result.detected is True
        assert len(result.matched_tokens) == 2


class TestCanaryInjection:
    def test_injection_ajoute_tokens(self):
        canaries = generate_canary_set(3)
        prompt = "You are a security assistant."
        injected = inject_canaries_in_prompt(prompt, canaries)
        # Le prompt injecté contient les canary tokens
        for c in canaries:
            assert c.token in injected

    def test_injection_preserve_contenu(self):
        canaries = generate_canary_set(2)
        prompt = "You are a security assistant."
        injected = inject_canaries_in_prompt(prompt, canaries)
        # Le prompt original est toujours présent
        assert prompt in injected


class TestCanaryEnvelope:
    def test_envelope_detection(self):
        canaries = generate_canary_set(2)
        output = f"System prompt: {canaries[0].token}"
        env = canary_guardrail_envelope(output, canaries)
        assert env["canary_check"]["detected"] is True
        assert env["canary_check"]["incident"] == "PROMPT_EXTRACTION"
        assert env["requires_human_review"] is True
        assert env["ir_playbook"] == "IR-404 (prompt extraction/jailbreak)"

    def test_envelope_pas_de_detection(self):
        canaries = generate_canary_set(2)
        output = "Normal response about CVE-2023-49103."
        env = canary_guardrail_envelope(output, canaries)
        assert env["canary_check"]["detected"] is False
        assert env["requires_human_review"] is False
        assert env["ir_playbook"] is None
