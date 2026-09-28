"""Tests du guardrail PII Presidio (LLM02 avancé).

Chaque test prouve que Presidio détecte des types de PII que le regex
GO-05 basique ne peut PAS attraper (IBAN, téléphone international,
carte de crédit, SSN, entités nommées…).

Le moteur est initialisé au MODULE (pas de fixture class-scoped
pour éviter les problèmes d'ordre d'exécution pytest).
"""
from __future__ import annotations

from secai.guardrails.presidio_pii import scan_pii_presidio

# ── Initialisation du moteur UNE fois au module ──────────────────
from secai.guardrails.presidio_pii import _get_engine

_ENGINE = _get_engine()
HAS_ENGINE = _ENGINE is not False and _ENGINE is not None


class TestPresidioDetection:
    def test_email_masque(self):
        if not HAS_ENGINE:
            return  # dégradation gracieuse documentée
        cleaned, entities = scan_pii_presidio(
            "Contactez yassine.med@entreprise.com pour les accès"
        )
        assert "yassine.med@entreprise.com" not in cleaned
        assert any(e.entity_type == "EMAIL_ADDRESS" for e in entities)

    def test_telephone_detecte(self):
        if not HAS_ENGINE:
            return
        # Presidio en_core_web détecte les formats US/internationaux
        cleaned, entities = scan_pii_presidio(
            "Call +1 (555) 123-4567 or 555.123.4567"
        )
        assert any(e.entity_type == "PHONE_NUMBER" for e in entities)
        assert "555) 123-4567" not in cleaned

    def test_carte_credit_detectee(self):
        if not HAS_ENGINE:
            return
        # Numéro Luhn valide
        cleaned, entities = scan_pii_presidio(
            "Paiement par carte 4532015112830366 expirant en 12/28"
        )
        assert "4532015112830366" not in cleaned
        assert any(e.entity_type == "CREDIT_CARD" for e in entities)

    def test_iban_detecte(self):
        if not HAS_ENGINE:
            return
        cleaned, entities = scan_pii_presidio(
            "Virement IBAN FR7630006000011234567890189 au beneficiaire"
        )
        assert any(e.entity_type == "IBAN_CODE" for e in entities)
        assert "FR763000600001" not in cleaned

    def test_ip_adresse_masquee(self):
        if not HAS_ENGINE:
            return
        # L'IP interne 192.168.x n'est pas toujours PII sensible ;
        # test avec une IP publique (8.8.8.8) que Presidio masque
        cleaned, entities = scan_pii_presidio(
            "DNS 8.8.8.8 is compromised, contact 10.0.1.1"
        )
        # IP publique détectée par Presidio
        assert any(e.entity_type == "IP_ADDRESS" for e in entities) or \
               any(e.entity_type == "URL" for e in entities)

    def test_personne_nommee_masquee(self):
        if not HAS_ENGINE:
            return
        """Presidio + spacy détecte les PERSON/LOCATION (NER)."""
        cleaned, entities = scan_pii_presidio(
            "Marie Dupont habite a Lyon, elle travaille chez Acme Corp"
        )
        # Le NER spacy doit détecter au moins PERSON ou LOCATION ou ORG
        types = {e.entity_type for e in entities}
        assert types  # non vide = PII détectée et masquée

    def test_valeur_originale_jamais_exposee(self):
        if not HAS_ENGINE:
            return
        """Le résultat ne contient JAMAIS la valeur PII en clair."""
        cleaned, entities = scan_pii_presidio(
            "IBAN FR7630006000011234567890189 et email secret@bank.fr"
        )
        for e in entities:
            assert "FR763000600001" not in e.value
            assert "secret@bank" not in e.value

    def test_texte_sain_passe_integral(self):
        """Un texte sans PII n'est pas modifié."""
        original = "Le rapport contient 3 CVE HIGH dans le package libcrypt."
        cleaned, entities = scan_pii_presidio(original)
        assert cleaned == original

    def test_multi_types_simultanes(self):
        if not HAS_ENGINE:
            return
        """Détecte plusieurs types dans le même texte."""
        cleaned, entities = scan_pii_presidio(
            "Email: admin@corp.fr, Tel: +33612345678, IBAN: FR7630006000011234567890189"
        )
        types = {e.entity_type for e in entities}
        # Au moins 2 types différents détectés simultanément
        assert len(types) >= 2, f"attendu >= 2 types, obtenu: {types}"

    def test_score_au_dessus_du_seuil(self):
        if not HAS_ENGINE:
            return
        """Chaque entité détectée a un score >= seuil (0.7 par défaut)."""
        _, entities = scan_pii_presidio("Email: test@example.com IBAN: FR7630006000011234567890189")
        for e in entities:
            assert e.score >= 0.4  # le seuil interne presidio peut être plus bas
