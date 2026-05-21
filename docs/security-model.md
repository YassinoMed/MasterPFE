# Modèle de sécurité — SecureRAG Hub

## Synthèse

| Couche | Contrôle | Implémentation Laravel |
|--------|----------|------------------------|
| **Identité** | JWT Sanctum, bcrypt, RBAC 3 rôles | `auth-users-service` |
| **Vecteur** | RBAC métadonnées Qdrant | `chatbot-manager-service` |
| **Prompt** | Audit pré-LLM, 11 patterns, scoring | `audit-security-service` |
| **Réponse** | Audit post-LLM, blocage si BLOCKED | id |
| **Logs** | Hashes only, jamais prompt brut | id |
| **Admission K8s** | Kyverno 7 policies | `infra/k8s/policies/kyverno/` |
| **Runtime K8s** | Falco MITRE rules + Loki | `infra/k8s/runtime-detection/` |
| **Réseau** | Default-deny + per-service NetworkPolicy | `infra/k8s/base/` |
| **Supply chain** | Trivy + Cosign + SBOM + digest pinning | `Jenkinsfile.cd` |
| **Secrets** | SOPS + age, rotation 90j | `.sops.yaml` |
| **Audit logs** | Append-only Loki + Prometheus alerts | `infra/k8s/observability/` |

## Authentification

- **Bcrypt** rounds=12 par défaut, configurable.
- **JWT Sanctum** : token court (1h), signing key en `JWT_SECRET` env var
  injectée via SOPS, jamais en clair.
- **Renouvellement** : login = nouveau token. Pas de refresh token →
  réduit la surface d'attaque.
- **Logout** : invalidation côté serveur (Sanctum revoke).

## Autorisation — RBAC à 3 niveaux

| Rôle | Périmètre |
|------|-----------|
| `USER` | Voit ses propres documents + documents `allowed_roles` ⊇ USER |
| `ADMIN` | Tout document, gestion utilisateurs, modifs RBAC |
| `AUDITOR` | Lecture audit logs, pas de modif applicative |

L'autorisation **descend jusqu'au Qdrant** : un USER ne peut pas
récupérer un chunk dont `allowed_roles` ne contient pas USER, même via
prompt injection (le filtre est appliqué *avant* embedding du contexte).

## Défense contre prompt injection

11 patterns surveillés (cf. CDC) :

```php
const ATTACK_PATTERNS = [
    'ignore previous instructions',
    'forget all instructions',
    'you are now',
    'jailbreak',
    'system prompt',
    'reveal your prompt',
    'token',
    'password',
    'api key',
    'secret',
    'private key',
];
```

Scoring composite :
- Pattern critique seul : +50
- Combinaisons (≥ 2 patterns) : +30 chacun
- Longueur anormale / langue inhabituelle : +10
- Demande d'exfiltration explicite (`output your`, `print all`) : +25

**Décisions** :
- 0-39 : `ALLOWED`
- 40-69 : `FLAGGED` (réponse possible mais loggée + alerte)
- 70-100 : `BLOCKED` (refus + log + Slack admin)

## Audit logs — format strict

```json
{
  "timestamp": "2026-05-21T10:42:13Z",
  "session_id": "sess_01HPX...",
  "user_id": 42,
  "role": "USER",
  "audit_score": 85,
  "action": "BLOCKED",
  "prompt_hash": "sha256:a1b2c3...",
  "response_hash": null,
  "latency_ms": 23,
  "patterns_matched": ["ignore previous instructions", "system prompt"]
}
```

⚠️ **Le contenu brut du prompt n'est JAMAIS stocké en production.** Seul
le hash est conservé, pour permettre la corrélation forensique sans
exposition des données.

## Filtrage de la réponse LLM

Avant retour à l'utilisateur, la réponse passe par `audit-security-service`
qui détecte :

- Hallucination de credentials (`password: ...`, `sk-...`)
- Fuite de chunks non autorisés (croisement avec les métadonnées Qdrant)
- Output de prompt système (`You are an AI assistant trained to...`)

## Sécurité K8s

Tous les Pods satisfont :

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 33     # ou 65532 (nobody)
  seccompProfile:
    type: RuntimeDefault
containers:
  - securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
automountServiceAccountToken: false
```

Validation continue via `scripts/validate/audit-pod-security.sh`.

## Secrets

- **Jamais** en clair dans Git (Gitleaks bloquant en CI).
- **SOPS + age** pour les secrets app (DB, JWT, API keys).
- **Jenkins credentials** pour les secrets pipeline (Cosign key, GitHub token).
- **Procédure rotation** : `docs/runbooks/secret-rotation.md` (90j prod,
  30j dev, immédiate sur compromission).

## Threat model résumé

| Menace | Mitigation primaire | Backup |
|--------|---------------------|--------|
| Compromission compte utilisateur | bcrypt + JWT 1h + rate-limit auth | logs Falco / Loki |
| Prompt injection / data exfil | Audit pré + post LLM, RBAC Qdrant | hash logs forensiques |
| Image malveillante | Trivy + Cosign verify admission Kyverno | SBOM Syft |
| Container escape | Pod Security strict + Falco runtime rules | Network egress restreint |
| Secret leak | Gitleaks CI + SOPS encrypt at-rest | rotation documentée |
| Drift cluster | Argo CD ServerSideApply + notifications | audit kubectl |
| Perte DB | CronJob backup + restore drill mensuel | snapshot S3 chiffré |

Détails complets : [`threat-model.md`](threat-model.md).
