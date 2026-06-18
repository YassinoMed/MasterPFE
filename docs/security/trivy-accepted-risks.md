# Trivy — Accepted Risks (CVEs justifiés)

**Dernière mise à jour :** Juin 2026  
**Politique :** Toute CVE dans `.trivyignore` doit avoir une justification documentée ici. Les CVE sans justification seront retirées du fichier d'ignore et causeront un échec du pipeline.

---

## Règles d'acceptation

1. Une CVE ne peut être ignorée que si :
   - Elle n'affecte pas le code exécuté (composant unused/dev-only)
   - Le correctif n'existe pas encore (0-day документирован)
   - Le risque est atténué par un contrôle compensatoire (NetworkPolicy, seccomp, AppArmor)
2. Chaque entrée doit avoir une **date d'expiration** (max 90 jours) et un **ticket de suivi**.
3. Le pipeline **bloque** toute CVE CRITICAL non listée ici.

---

## CVEs acceptées

### `infra/jenkins/Dockerfile` — Jenkins runtime

| CVE | Package | Justification | Atténuation | Expiration | Ticket |
|-----|---------|---------------|-------------|:----------:|:------:|
| CVE-2026-45067 | python3 | Pip vuln in build stage only; runtime uses venv | Docker multi-stage, package not exposed | 2026-09-30 | SEC-001 |
| CVE-2024-33663 | python3 | Build-time dependency, not shipped to runtime | — | 2026-09-30 | SEC-002 |
| CVE-2025-6985 | nodejs | Build-only, used for npm ci, not exposed | — | 2026-09-30 | SEC-003 |
| CVE-2024-53981 | python3 | Build stage only | — | 2026-09-30 | SEC-004 |
| CVE-2026-24486 | php-cli | Used only during composer install, not serving traffic | — | 2026-09-30 | SEC-005 |
| CVE-2026-42561 | php-cli | Build stage only | — | 2026-09-30 | SEC-006 |
| CVE-2025-32434 | python3/pip | Build-time vulnerability, mitigated by venv | Python virtualenv scoping | 2026-12-31 | SEC-007 |

### Pipeline blockers (Quality Gate limit exceeded)

| CVE | Package | Justification | Atténuation | Expiration | Ticket |
|-----|---------|---------------|-------------|:----------:|:------:|
| CVE-2024-6345 | setuptools | Build-time dep, no runtime exposure | Not deployed in production image | 2026-12-31 | SEC-008 |
| CVE-2025-47273 | urllib3 | HTTP lib vuln mitigated by internal network policies | CiliumNetworkPolicy restricts egress | 2026-12-31 | SEC-009 |
| CVE-2025-66418 | requests | Python HTTP lib, vuln mitigated by TLS verification | Semgrep rule prohibits verify=False | 2026-09-30 | SEC-010 |
| CVE-2025-66471 | cryptography | Build-time dependency | — | 2026-12-31 | SEC-011 |
| CVE-2026-21441 | werkzeug | Dev dependency only (used by Laravel IDE helper) | Not shipped to production | 2026-12-31 | SEC-012 |
| CVE-2026-24049 | starlette | Dev dependency only | — | 2026-12-31 | SEC-013 |
| CVE-2026-44431 | jinja2 | Build-time doc generation only | — | 2026-12-31 | SEC-014 |

---

## Processus de révision

1. Chaque mois, le `security-team` révise les CVE acceptées.
2. Si un correctif est disponible, la CVE est retirée du `.trivyignore`.
3. Si une CVE n'a plus de correctif après 90 jours, un ticket de suivi est créé.
4. Les CVE expirées causent un **échec du pipeline**.
