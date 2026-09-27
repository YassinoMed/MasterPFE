"""Guardrail OUTPUT — filtrage des sorties LLM (OWASP LLM02, LLM05).

Le modèle produit du texte ; ce texte n'est JAMAIS exécuté ni rendu tel quel
avant d'être passé ici. Deux actions :
  - BLOCK   : un secret réel fuit (clé privée, AWS key, token) — la réponse
              est remplacée par un message standardisé.
  - SANITIZE: PII / IP interne / e-mail masqués avant retour au client.

Règles :
  GO-01  Clés privées PEM (BEGIN ... PRIVATE KEY)         -> BLOCK
  GO-02  Identifiants cloud (AKIA…, ASIA…, gcp, azure)    -> BLOCK
  GO-03  Tokens structurés (JWT, Bearer, ghp_, gho_…)     -> BLOCK
  GO-04  Connexions BDD (postgres://user:pass@…)           -> BLOCK
  GO-05  PII : e-mails, IP internes                         -> SANITIZE
  GO-06  Commandes destructrices (rm -rf, curl|sh)         -> BLOCK
"""
from __future__ import annotations

import re

from secai.guardrails.schemas import GuardrailVerdict, Verdict

_BLOCK_RULES: dict[str, list[str]] = {
    "GO-01": [
        r"-----BEGIN (?:RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----",
    ],
    "GO-02": [
        r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b",
        r"\bAIza[0-9A-Za-z_-]{35}\b",
        r"\b(?:ghp|gho|ghu|ghs|github_pat)_[0-9A-Za-z]{20,}\b",
        r"\bxox[baprs]-[0-9A-Za-z-]{10,}\b",
    ],
    "GO-03": [
        r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b",
        r"\b(?:Bearer|Basic)\s+[A-Za-z0-9+/=._-]{20,}\b",
        r"\bsk-(?:ant|proj|live|test)_[A-Za-z0-9-]{20,}\b",
    ],
    "GO-04": [
        r"(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis|amqp)://[^\s@]+:[^\s@]+@[^\s]+",
    ],
    "GO-06": [
        r"\brm\s+-rf?\s+/",
        r"curl[^|]{0,80}\|\s*(?:ba)?sh",
        r"mkfs\.\w+\s+/dev/",
        r"dd\s+if=/dev/zero\s+of=/dev/[sh]d",
    ],
}

_SANITIZE_RULES: dict[str, list[str]] = {
    "GO-05": [
        r"\b[\w.+-]+@[\w-]+\.[\w.]{2,}\b",          # e-mails
        r"\b(?:10\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])|192\.168)\.\d{1,3}\.\d{1,3}\b",  # IP privées
    ],
}

_BLOCK_COMPILED = {
    r: [re.compile(p) for p in pats] for r, pats in _BLOCK_RULES.items()
}
_SANITIZE_COMPILED = {
    r: [re.compile(p) for p in pats] for r, pats in _SANITIZE_RULES.items()
}

_MASK = "[REDACTED]"


def scan_output(text: str) -> GuardrailVerdict:
    """Scanne une sortie de modèle avant consommation. Fail-closed.

    Retour :
        ALLOW    : rien détecté, texte inchangé
        SANITIZE : PII masquée, texte sinon intact
        BLOCK    : secret réel détecté — texte remplacé par un message standard
    """
    if not text or not text.strip():
        return GuardrailVerdict(verdict=Verdict.ALLOW, cleaned=text)

    for rule, patterns in _BLOCK_COMPILED.items():
        for pat in patterns:
            m = pat.search(text)
            if m:
                # Evidence tronquée : on garde la preuve sans la diffuser entière.
                return GuardrailVerdict(
                    verdict=Verdict.BLOCK,
                    rule=rule,
                    cleaned=(
                        "[SECAI-GUARDRAIL] Réponse bloquée : secret détecté ("
                        f"règle {rule}). L'incident est journalisé."
                    ),
                    evidence=(m.group(0)[:12] + "…",),
                    confidence=0.99,
                )

    cleaned = text
    sanitized = False
    for rule, patterns in _SANITIZE_COMPILED.items():
        for pat in patterns:
            if pat.search(cleaned):
                cleaned = pat.sub(_MASK, cleaned)
                sanitized = True

    if sanitized:
        return GuardrailVerdict(
            verdict=Verdict.SANITIZE,
            rule="GO-05",
            cleaned=cleaned,
            evidence=(_MASK,),
            confidence=0.85,
        )

    return GuardrailVerdict(verdict=Verdict.ALLOW, cleaned=text)
