"""Guardrail INPUT — détection d'injections de prompt (OWASP LLM01, LLM07).

Ce module scanne TOUT texte destiné à un LLM avant envoi. Les patterns sont
délibérément simples, déterministes et lisibles : chaque règle doit pouvoir
être expliquée en soutenance sans magie noire.

Règles (toutes testées) :
  GI-01  Détournement d'instructions ("ignore les instructions précédentes…")
  GI-02  Extraction de prompt système ("révèle ton prompt", "system prompt")
  GI-03  Usurpation de rôle ("tu es maintenant…", "acte as…")
  GI-04  Contournement de politiques ("DAN", "jailbreak", "do anything now")
  GI-05  Smuggling par délimiteurs (fake tags système : <|system|>, ###)
  GI-06  Invocation d'outils/commands ("exécute", "rm -rf", "curl | sh")

Principe : fail-closed. Un seul déclenchement GI-01..GI-04 => BLOCK.
GI-05/GI-06 => SANITIZE (nettoyage) si isolé, BLOCK si cumulé.
"""
from __future__ import annotations

import re

from secai.guardrails.schemas import GuardrailVerdict, Verdict

# Patterns en minuscules — le scan est case-insensitive.
_RULES: dict[str, list[str]] = {
    "GI-01": [
        r"ignore (?:all |any |the |les |toutes? )?(?:previous|précédent|above|prior)\s",
        r"(?:disregard|ignore) (?:all |any |the |les )?(?:instructions|consignes|directives)",
        r"oublie (?:tout|les instructions|ce qui précède)",
        r"forget (?:everything|all|your instructions)",
        r"new instructions?:",
        r"nouvelles? (?:instructions|consignes)\s*:",
    ],
    "GI-02": [
        r"reveal (?:your|the) (?:system )?prompt",
        r"révèle(?:r)? (?:ton|votre|le) (?:prompt|prompt système)",
        r"(?:show|display|print|affiche)(?:-)?(?:moi| me)?(?: ton| your)? (?:system )?prompt",
        r"initial (?:prompt|instructions)",
        r"prompt (?:système|system)\s*:",
        r"what (?:are|is) your (?:system |hidden |secret |internal )?(?:instructions|rules|prompt)",
        r"quelles? sont (?:tes|vos) (?:instructions|règles|consignes)",
        r"(?:hidden|secret|internal) (?:instructions|prompt|rules)",
    ],
    "GI-03": [
        r"you are now (?:a|an|the)\b",
        r"tu es maintenant (?:un|une|le|la)\b",
        r"act (?:as|like) (?:a|an|an? )?(?:dan|developer|admin|hacker)",
        r"joue(?:r)? le rôle (?:de|d'un|d')",
        r"pretend (?:to be|you are)",
        r"à partir de maintenant,? tu (?:es|deviens)",
    ],
    "GI-04": [
        r"\bdan\b.{0,20}jailbreak",
        r"jailbreak",
        r"do anything now",
        r"developer mode",
        r"mode développeur",
        r"no (?:restrictions|restrictions applied|filters)",
        r"sans (?:restrictions|filtres|aucune règle)",
        r"bypass (?:your|all|the) (?:rules|policies|filters|safety)",
        r"contourne(?:r)? (?:tes|vos|les) (?:règles|politiques|filtres)",
    ],
    "GI-05": [
        r"<\|(?:system|im_start|im_end|endoftext)\|>",
        r"###\s*(?:system|instruction)",
        r"\[SYSTEM\]",
        r"\[INST\]",
        r"<<SYS>>",
    ],
    "GI-06": [
        # Patterns d'EXÉCUTION uniquement — les simples mentions de chemins
        # (/etc/shadow) sont légitimes dans les logs sécurité que SECAI analyse.
        r"\brm\s+-rf?\s+/",
        r"curl[^|]{0,80}\|\s*(?:ba)?sh",
        r"wget[^|]{0,80}\|\s*(?:ba)?sh",
        r"(?:chmod|chown)\s+777",
    ],
}

_COMPILED = {
    rule: [re.compile(p, re.IGNORECASE) for p in pats]
    for rule, pats in _RULES.items()
}

# Règles "dures" => BLOCK immédiat ; règles "douces" => sanitize si isolées.
_HARD = {"GI-01", "GI-02", "GI-03", "GI-04"}
_SOFT = {"GI-05", "GI-06"}


def scan_prompt_injection(text: str) -> GuardrailVerdict:
    """Scanne un prompt avant envoi au LLM. Fail-closed : doute => BLOCK.

    Retour :
        ALLOW     : aucun pattern détecté, texte inchangé
        BLOCK     : au moins une règle dure OU >=2 règles douces
        SANITIZE  : une seule règle douce => délimiteurs neutralisés
    """
    if not text or not text.strip():
        return GuardrailVerdict(verdict=Verdict.ALLOW, cleaned=text)

    triggered: dict[str, list[str]] = {}
    lowered = text.lower()
    for rule, patterns in _COMPILED.items():
        hits = [m.group(0) for p in patterns for m in p.finditer(lowered)]
        if hits:
            triggered[rule] = hits

    if not triggered:
        return GuardrailVerdict(verdict=Verdict.ALLOW, cleaned=text)

    hard_hits = {r: h for r, h in triggered.items() if r in _HARD}
    soft_hits = {r: h for r, h in triggered.items() if r in _SOFT}

    # Fail-closed : règle dure => BLOCK sans exception
    if hard_hits:
        rule = sorted(hard_hits)[0]
        return GuardrailVerdict(
            verdict=Verdict.BLOCK,
            rule=rule,
            cleaned="",
            evidence=tuple(h for h in hard_hits[rule]),
            confidence=0.95,
        )

    # Règles douces cumulées => BLOCK aussi (probable smuggle combiné)
    if len(soft_hits) >= 2:
        rules = sorted(soft_hits)
        return GuardrailVerdict(
            verdict=Verdict.BLOCK,
            rule="+".join(rules),
            cleaned="",
            evidence=tuple(h for r in rules for h in soft_hits[r]),
            confidence=0.8,
        )

    # Une seule douce => neutralisation des délimiteurs
    rule, hits = next(iter(soft_hits.items()))
    cleaned = text
    for pat in _COMPILED["GI-05"]:
        cleaned = pat.sub("[neutralized]", cleaned)
    return GuardrailVerdict(
        verdict=Verdict.SANITIZE,
        rule=rule,
        cleaned=cleaned,
        evidence=tuple(hits),
        confidence=0.7,
    )
