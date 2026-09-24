"""Génération d'explications XAI — SECAI.

Règles clés :
- Jamais d'assertion naïve (on ne sait pas si la vulnérabilité est dans la
  schéma supporté, donc on dit 'analyse déterministe' et non 'AI est nécessaire')
- Toujours une phrase "vérifié par" lorsque AI-enabled.
"""
from __future__ import annotations

import html

from secai.api.schemas import Finding, Severity

EXPLANATION_TEMPLATES = {
    "semgrep": {
        "title": "Analyse statique Semgrep",
        "body": (
            "Règle `{rule_id}` détectée dans `{file}`. "
            "Séverité déclarée : {severity}. "
            "Recommandation : réviser le pattern pointé et corriger avant merge."
        ),
    },
    "trivy": {
        "title": "Vulnérabilité image / package",
        "body": (
            "Vulnérabilité {cve} détectée dans `{package}` (version {installed} → "
            " {fixed}). Contexte detected: {context}. "
            "Action : mettre à jour le package ou la base image."
        ),
    },
    "falco": {
        "title": "Alerte de sécurité runtime",
        "body": (
            "Falco a détecté `{rule}` dans le pod `{pod}` (ns {ns}). "
            "Impact potentiel : {impact}. "
            "Recommandation : investigurer dès que possible."
        ),
    },
    "kyverno": {
        "title": "Violation de politique Kyverno",
        "body": (
            "Kubernetes admission a rejeté/punit une ressource `{resource}` "
            "(politique `{policy}`) : {message}. "
            "Recommandation : adapter le manifeste à la politique de référence."
        ),
    },
}


def explain(finding: Finding) -> str:
    """Génère une explication constitutionnelle-humaine pour un finding."""
    src = finding.source.value
    tmpl = EXPLANATION_TEMPLATES.get(src)
    if not tmpl:
        return f"Analyse sémantique de règle {finding.rule_id or 'unknown'} par SECAI."
    ev = finding.raw if finding.raw else {}
    fallback = {
        "rule_id": finding.rule_id or "?",
        "file": finding.file_path or "?",
        "severity": finding.severity.value,
        "cve": html.escape(str(ev.get("cve", "?")), quote=True),
        "package": html.escape(str(ev.get("package", "?")), quote=True),
        "installed": html.escape(str(ev.get("installed", "?")), quote=True),
        "fixed": html.escape(str(ev.get("fixed", "?")), quote=True),
        "context": html.escape(str(ev.get("context", "?")), quote=True),
        "rule": ev.get("rule", "?"),
        "pod": html.escape(str(ev.get("pod", "?")), quote=True),
        "ns": html.escape(str(ev.get("namespace", "?")), quote=True),
        "impact": html.escape(str(ev.get("impact", "?")), quote=True),
        "resource": html.escape(str(ev.get("resource", "?")), quote=True),
        "policy": html.escape(str(ev.get("policy", "?")), quote=True),
        "message": html.escape(str(ev.get("message", "?")), quote=True),
    }
    try:
        # Do NOT merge raw ev keys afterwards — they would overwrite escaped ones.
        return tmpl["body"].format(**fallback)
    except Exception:
        that = html.escape((finding.description or finding.title)[:160], quote=True)
        return f"Finding `{finding.finding_id}` (source={src}) — {that}"
