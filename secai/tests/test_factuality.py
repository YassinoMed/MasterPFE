"""Tests du guardrail FACTUALITY (OWASP LLM09 — anti-hallucination).

Chaque test prouve le comportement de détection :
  - une réponse qui cite les CVE du contexte est GROUNDED
  - une réponse qui INVENTE une CVE est UNGROUNDED (hallucination attrapée)
  - un mélange est PARTIAL
  - les URLs/fichiers/commandes inventées sont attrapés aussi
"""
from __future__ import annotations

from secai.guardrails.factuality import (
    check_factuality,
    extract_claims,
    factuality_envelope,
)

CONTEXT = """
Rapport Trivy image securerag-hub-auth-users:dev :
- CVE-2023-49103 HIGH in libcrypt (glibc qsort, escalation locale)
- CVE-2024-25251 MEDIUM in libsystemd
Voir https://nvd.nist.gov/vuln/detail/CVE-2023-49103
Le fichier /etc/shadow a été lu par un process non fiable (Falco).
Correctif : apt-get upgrade libcrypt
"""


class TestExtractClaims:
    def test_extrait_les_cves(self):
        claims = extract_claims("CVE-2023-49103 et cve-2024-25251 sont critiques")
        assert len(claims) == 2
        assert all(c.kind == "cve" for c in claims)

    def test_extrait_urls_fichiers_commandes(self):
        claims = extract_claims(
            "Lance apt-get upgrade et supprime config.yaml via https://evil.sh"
        )
        kinds = {c.kind for c in claims}
        assert "command" in kinds
        assert "file" in kinds
        assert "url" in kinds


class TestGrounded:
    def test_reponse_tracee_est_grounded(self):
        v = check_factuality(
            "Le rapport mentionne CVE-2023-49103 (HIGH) et CVE-2024-25251 (MEDIUM) "
            "dans les paquets libcrypt et libsystemd.",
            CONTEXT,
        )
        assert v.verdict == "GROUNDED"
        assert v.grounded_ratio == 1.0
        assert not v.ungrounded_claims

    def test_sans_claims_verifiables_grounded_par_defaut(self):
        v = check_factuality("Voici un résumé sans identifiants techniques.", CONTEXT)
        assert v.verdict == "GROUNDED"


class TestHallucination:
    def test_cve_inventee_est_attrapee(self):
        v = check_factuality(
            "La CVE-2999-0001 CRITICALE exige de patcher nginx immédiatement.",
            CONTEXT,  # ne contient PAS CVE-2999-0001
        )
        assert v.verdict == "UNGROUNDED"
        assert v.grounded_ratio == 0.0
        assert any(c.value.upper() == "CVE-2999-0001" for c in v.ungrounded_claims)

    def test_url_inventee_est_attrapee(self):
        v = check_factuality(
            "Téléchargez le patch sur https://evil.example.com/fix.sh",
            CONTEXT,
        )
        assert v.ungrounded_claims
        assert any("evil.example.com" in c.value for c in v.ungrounded_claims)

    def test_commande_non_au_contexte_attrapee(self):
        v = check_factuality("Exécute rm -rf /var/lib/postgresql", CONTEXT)
        cmds = [c for c in v.ungrounded_claims if c.kind == "command"]
        assert cmds  # rm n'est pas dans le contexte → non vérifié

    def test_melange_partiel(self):
        # 2 claims tracés (CVE du contexte) + 1 inventé → 0.667 → PARTIAL
        v = check_factuality(
            "CVE-2023-49103 et CVE-2024-25251 sont citées, mais aussi CVE-2999-0001.",
            CONTEXT,
        )
        assert v.verdict == "PARTIAL"
        assert len(v.ungrounded_claims) == 1


class TestEnvelope:
    def test_enveloppe_exige_review_humain_si_ungrounded(self):
        env = factuality_envelope("CVE-2999-0001 détruit tout", CONTEXT)
        assert env["factuality"]["verdict"] == "UNGROUNDED"
        assert env["requires_human_review"] is True
        assert env["factuality"]["ungrounded"][0]["value"] == "CVE-2999-0001"

    def test_enveloppe_grounded_pas_de_review(self):
        env = factuality_envelope("CVE-2023-49103 est documentée", CONTEXT)
        assert env["factuality"]["verdict"] == "GROUNDED"
        assert env["requires_human_review"] is False
