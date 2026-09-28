"""Endpoint /llm/analyze — chemin LLM production avec guardrails OBLIGATOIRES.

C'est le câblage réel des guardrails dans le trafic : AUCUNE requête n'atteint
le LLM sans passer par scan_prompt_injection, AUCUNE réponse ne sort sans
passer par scan_output, et chaque client est soumis au token bucket.

Chaîne (toutes les étapes sont exécutées dans cet ordre, sans exception) :
  1. Rate-limit  (LLM10) — TokenBucketLimiter, 429 si épuisé
  2. Guardrail IN  (LLM01/07) — scan_prompt_injection → 422 si BLOCK
  3. Appel LLM via AI Gateway LiteLLM (auth Bearer master key)
  4. Guardrail OUT (LLM02/05) — scan_output → message standardisé si BLOCK
  5. Réponse assainie + verdicts (traçabilité complète)

Fail-closed partout : en cas d'erreur LLM/gateway, on renvoie une erreur
explicite — on ne renvoie JAMAIS de texte non scanné.
"""
from __future__ import annotations

import json
import logging
import os
import urllib.request
import urllib.error

from fastapi import HTTPException
from pydantic import BaseModel, Field

from secai.guardrails import (
    TokenBucketLimiter,
    Verdict,
    scan_output,
    scan_prompt_injection,
)

logger = logging.getLogger("secai.api.llm")

GATEWAY_URL = os.getenv(
    "SECAI_LLM_GATEWAY_URL",
    "http://ai-gateway-litellm.securerag-hub.svc.cluster.local:4000/v1/chat/completions",
)
GATEWAY_MODEL = os.getenv("SECAI_LLM_MODEL", "securerag-llm")
GATEWAY_TIMEOUT = int(os.getenv("SECAI_LLM_TIMEOUT", "150"))

# LLM10 — 5 requêtes en burst, 1 requête/s soutenue, par client.
_llm_limiter = TokenBucketLimiter(capacity=5, refill_per_second=1.0)


class LLMAnalyzeRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=4000)
    client_id: str = Field(default="anonymous", max_length=64)
    max_tokens: int = Field(default=64, ge=8, le=512)


class LLMAnalyzeResponse(BaseModel):
    prompt_verdict: str          # allow / sanitize / block (guardrail IN)
    output_verdict: str | None   # allow / sanitize / block (guardrail OUT)
    rule_triggered: str          # règle guardrail (GI-xx / GO-xx) ou "none"
    response: str | None         # réponse assainie (jamais brute si secret)
    blocked_reason: str | None
    duration_ms: int


def _call_gateway(prompt: str, max_tokens: int) -> str:
    """Appelle le AI Gateway (LiteLLM). Retourne le texte brut du modèle.

    Fail-closed : toute erreur lève une exception explicite — jamais de
    texte non scanné renvoyé au client.
    """
    master_key = os.getenv("LITELLM_MASTER_KEY", "")
    if not master_key:
        raise RuntimeError("LITELLM_MASTER_KEY absent de l'environnement")

    body = json.dumps(
        {
            "model": GATEWAY_MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
        }
    ).encode()

    req = urllib.request.Request(
        GATEWAY_URL,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {master_key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=GATEWAY_TIMEOUT) as r:
            data = json.loads(r.read())
            return data["choices"][0]["message"]["content"] or ""
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"gateway HTTP {exc.code}") from exc
    except (KeyError, json.JSONDecodeError) as exc:
        raise RuntimeError("réponse gateway invalide") from exc


def llm_analyze(payload: LLMAnalyzeRequest) -> LLMAnalyzeResponse:
    """Point d'entrée POST /llm/analyze — garde la logique testable pure."""
    import time

    t0 = time.monotonic()

    # ── 1. Rate-limit (LLM10) — AVANT tout travail coûteux ──────────────
    if not _llm_limiter.allow(payload.client_id):
        raise HTTPException(
            status_code=429,
            detail=f"quota dépassé pour client '{payload.client_id}' — réessayez plus tard",
        )

    # ── 2. Guardrail INPUT (LLM01/07) — le prompt est scanné AVANT le LLM ─
    in_scan = scan_prompt_injection(payload.prompt)
    if in_scan.verdict == Verdict.BLOCK:
        # Le prompt n'ATTEINT JAMAIS le LLM : journal + refus explicite.
        logger.warning(
            "guardrail IN blocked client=%s rule=%s evidence=%s",
            payload.client_id, in_scan.rule, in_scan.evidence,
        )
        return LLMAnalyzeResponse(
            prompt_verdict=Verdict.BLOCK.value,
            output_verdict=None,
            rule_triggered=in_scan.rule,
            response=None,
            blocked_reason="prompt rejeté par le guardrail d'entrée (injection détectée)",
            duration_ms=int((time.monotonic() - t0) * 1000),
        )

    safe_prompt = in_scan.cleaned  # identique si ALLOW, nettoyé si SANITIZE

    # ── 3. Appel LLM via le Gateway (auth + budgets côté LiteLLM) ──────
    try:
        raw_output = _call_gateway(safe_prompt, payload.max_tokens)
    except RuntimeError as exc:
        logger.error("gateway error for client=%s: %s", payload.client_id, exc)
        raise HTTPException(status_code=502, detail=f"LLM indisponible: {exc}") from exc

    # ── 4. Guardrail OUTPUT (LLM02/05) — la réponse est scannée AVANT sortie ─
    out_scan = scan_output(raw_output)
    if out_scan.verdict == Verdict.BLOCK:
        # Un secret a fui dans la réponse du modèle : elle ne sort JAMAIS
        # telle quelle — message standardisé à la place (LLM02).
        logger.warning(
            "guardrail OUT blocked client=%s rule=%s", payload.client_id, out_scan.rule
        )
        return LLMAnalyzeResponse(
            prompt_verdict=in_scan.verdict.value,
            output_verdict=Verdict.BLOCK.value,
            rule_triggered=out_scan.rule,
            response=out_scan.cleaned,  # message standardisé (pas la fuite)
            blocked_reason="réponse neutralisée : secret détecté dans la sortie du modèle",
            duration_ms=int((time.monotonic() - t0) * 1000),
        )

    # ── 5. Réponse assainie + traçabilité ───────────────────────────────
    return LLMAnalyzeResponse(
        prompt_verdict=in_scan.verdict.value,
        output_verdict=out_scan.verdict.value,
        rule_triggered=in_scan.rule if in_scan.rule != "none" else out_scan.rule,
        response=out_scan.cleaned,
        blocked_reason=None,
        duration_ms=int((time.monotonic() - t0) * 1000),
    )
