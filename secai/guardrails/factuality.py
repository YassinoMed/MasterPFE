"""Guardrail FACTUALITY — détection d'hallucination (OWASP LLM09).

Un LLM de sécurité ne doit JAMAIS inventer de CVE, de fichier, de commande
ou d'URL. Ce module vérifie que chaque CLAIM vérifiable de la réponse est
réellement PRESENT dans le contexte source (RAG/rapports) fourni.

Types de claims vérifiés :
  - identifiants CVE (CVE-YYYY-NNNN)
  - noms de fichiers/packages
  - URLs et domaines
  - commandes (rm, curl, chmod, kubectl...)

Verdict :
  GROUNDED      : ≥80% des claims tracés dans le contexte
  PARTIAL       : 40-79% — à révision humaine
  UNGROUNDED    : <40% — hallucination probable, réponse bloquée

Déterministe, stdlib pure, sans embedding : la preuve soutenable est la
traçabilité exacte (claim → contexte), pas un score opaque.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

# ── Extraction des claims vérifiables ─────────────────────────────────────────

CVE_RE = re.compile(r"\bCVE-\d{4}-\d{4,7}\b", re.IGNORECASE)
URL_RE = re.compile(r"\bhttps?://[^\s,;\"')]+", re.IGNORECASE)
FILE_RE = re.compile(r"\b[\w.-]+\.(?:py|js|ts|yaml|yml|json|sh|go|rs|sql|env|conf|txt|md|jar|exe|so|dll)\b")
CMD_RE = re.compile(r"\b(?:rm|curl|wget|chmod|chown|kubectl|docker|git|apt(?:-get)?|pip(?:3)?|npm|sh|bash)\s+[^\s,;\"']+")

_TOKEN_SPLIT = re.compile(r"[^a-z0-9]+")


def _normalize(text: str) -> str:
    return _TOKEN_SPLIT.sub(" ", text.lower()).strip()


@dataclass(frozen=True)
class Claim:
    """Un claim vérifiable extrait de la réponse du modèle."""

    kind: str          # cve | url | file | command
    value: str         # le claim brut
    trace: str | None = None  # où il a été trouvé dans le contexte (preuve)


@dataclass(frozen=True)
class FactualityVerdict:
    verdict: str                 # GROUNDED | PARTIAL | UNGROUNDED
    grounded_ratio: float        # 0.0 - 1.0
    total_claims: int
    ungrounded_claims: list[Claim] = field(default_factory=list)
    detail: list[Claim] = field(default_factory=list)  # tous les claims, tracés


def extract_claims(response: str) -> list[Claim]:
    """Extrait les claims vérifiables d'une réponse."""
    claims: list[Claim] = []
    seen: set[tuple[str, str]] = set()

    def _add(kind: str, values: list[str]) -> None:
        for v in values:
            key = (kind, _normalize(v))
            if key not in seen:
                seen.add(key)
                claims.append(Claim(kind=kind, value=v.strip()))

    _add("cve", CVE_RE.findall(response))
    _add("url", URL_RE.findall(response))
    _add("file", FILE_RE.findall(response))
    _add("command", CMD_RE.findall(response))
    return claims


def check_factuality(response: str, context: str) -> FactualityVerdict:
    """Vérifie que chaque claim de la réponse est traçable dans le contexte.

    Args:
        response: texte produit par le LLM (déjà passé par scan_output).
        context:  le contexte source RAG/rapports qui GROUND la réponse.

    Returns:
        FactualityVerdict avec le détail claim → trace (ou ungrounded).
    """
    claims = extract_claims(response)
    ctx_norm = _normalize(context)
    ctx_cves = {c.upper() for c in CVE_RE.findall(context)}
    ctx_urls = {u.lower().rstrip(".,;)") for u in URL_RE.findall(context)}

    detail: list[Claim] = []
    ungrounded: list[Claim] = []
    grounded = 0

    for c in claims:
        trace = None
        norm = _normalize(c.value)
        if c.kind == "cve":
            if c.value.upper() in ctx_cves:
                trace = "CVE présente dans le contexte"
        elif c.kind == "url":
            if c.value.lower().rstrip(".,;)") in ctx_urls:
                trace = "URL présente dans le contexte"
        else:
            # file / command : tokens significatifs présents dans le contexte
            if norm and norm in ctx_norm:
                trace = "mention exacte dans le contexte"

        if trace:
            grounded += 1
            detail.append(Claim(c.kind, c.value, trace))
        else:
            ungrounded.append(c)
            detail.append(Claim(c.kind, c.value, None))

    ratio = grounded / len(claims) if claims else 1.0
    if not claims:
        verdict = "GROUNDED"  # aucun claim vérifiable → rien à contester
    elif ratio >= 0.8:
        verdict = "GROUNDED"
    elif ratio >= 0.4:
        verdict = "PARTIAL"
    else:
        verdict = "UNGROUNDED"

    return FactualityVerdict(
        verdict=verdict,
        grounded_ratio=round(ratio, 3),
        total_claims=len(claims),
        ungrounded_claims=ungrounded,
        detail=detail,
    )


# ── Intégration pipeline : enrichit une réponse /llm/analyze ───────────────────

def factuality_envelope(response: str, context: str) -> dict:
    """Format d'enveloppe pour l'API — traçabilité complète."""
    v = check_factuality(response, context)
    return {
        "factuality": {
            "verdict": v.verdict,
            "grounded_ratio": v.grounded_ratio,
            "total_claims": v.total_claims,
            "ungrounded": [
                {"kind": c.kind, "value": c.value, "action": "NON VÉRIFIÉ dans le contexte"}
                for c in v.ungrounded_claims
            ],
        },
        "requires_human_review": v.verdict != "GROUNDED",
    }
