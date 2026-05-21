# ADR-001 — Laravel comme runtime officiel de SecureRAG Hub

> **Status:** Accepté · **Date:** 2026-05 · **Décideurs:** équipe projet
> **Catégorie:** Architecture Decision Record (ADR)

## Contexte

Le cahier des charges initial de SecureRAG Hub prévoyait une architecture
microservices **Python / FastAPI** :

- 1 API Gateway FastAPI
- 4 services métier : `auth-users`, `vectorstore-service`,
  `llm-orchestrator`, `security-auditor`

Au cours de l'implémentation, deux runtimes ont coexisté :

| Runtime | Statut réel observé | Tests | Déployé K8s | Pipeline officiel |
|---------|---------------------|------:|:-----------:|:-----------------:|
| Python `services/*/` | Squelettes (Dockerfile + requirements seulement) | 1 fichier | non | non |
| **Laravel `services-laravel/*` + `platform/portal-web`** | Implémentation mature, modulaire | **26 fichiers** | **oui** | **oui** |

Le pipeline Jenkins déclare explicitement :

```groovy
LARAVEL_APPS = 'platform/portal-web services-laravel/auth-users-service \
                services-laravel/chatbot-manager-service \
                services-laravel/conversation-service \
                services-laravel/audit-security-service'
```

Aucun stage CI/CD n'invoque les services Python. Aucun manifest K8s ne
construit ces images. La preuve runtime production
(`artifacts/security/security-status-source-of-truth.md`) marque le runtime
Python comme `PRÊT_NON_EXÉCUTÉ / exclu du runtime officiel`.

## Décision

**Laravel devient le runtime officiel et démontrable de SecureRAG Hub.**

Les services Python sont conservés mais reclassés en :
- **Référence d'implémentation** du cahier des charges FastAPI initial
- **Piste expérimentale** non poursuivie en production
- **Documentation de l'évolution technique** du projet

## Justifications

1. **Maturité du code** : 26 fichiers de tests PHP existent ; les services
   Python ne contiennent pas de code applicatif réel.
2. **Cohérence pipeline** : Jenkinsfile, Trivy, Cosign, Kyverno et Argo CD
   sont déjà configurés pour le runtime Laravel.
3. **Déployabilité K8s** : les manifests `infra/k8s/base/*` reflètent
   l'architecture Laravel — `portal-web` consomme `auth-users-service`,
   `chatbot-manager-service`, `conversation-service` et
   `audit-security-service`.
4. **Risque soutenance** : démontrer un runtime qui marche réellement
   est plus solide qu'une intention non livrée.
5. **Intégration DevSecOps** : Composer + PHPUnit + PHPStan s'intègrent
   naturellement aux outils Jenkins déjà configurés (audit-dependencies,
   coverage, quality-gate).
6. **Sécurité** : un runtime mature et testé limite l'exposition à des
   vulnérabilités évitables (CVE non patchées dans une stack abandonnée).

## Conséquences

### Positives
- ✅ La démo soutenance pointe vers un produit réellement déployable.
- ✅ Le pipeline DevSecOps complet (CI + CD + GitOps) tourne sur du code réel.
- ✅ Les preuves runtime (`artifacts/security/runtime-security-postdeploy.md`,
  etc.) reflètent l'état véritable du cluster.
- ✅ La complexité cognitive du projet baisse : 1 runtime au lieu de 2.

### Négatives ou neutres
- ⚠️ Le cahier des charges initial parlait de Python. Il faut documenter
  explicitement la dérogation et l'argumenter (`docs/soutenance-argumentaire.md`).
- ⚠️ Les services Python restent dans le repo en l'état. Ils sont marqués
  `legacy/expérimental` via `services/README.md`.

## Mapping CDC FastAPI → Laravel équivalent

| Module CDC FastAPI | Service Laravel correspondant | Localisation |
|--------------------|-------------------------------|--------------|
| `api-gateway` | Routes + Middleware `portal-web` | `platform/portal-web` |
| `auth-users` | `auth-users-service` (Sanctum + RBAC) | `services-laravel/auth-users-service` |
| `vectorstore-service` | Partagé `conversation-service` + `chatbot-manager-service` | id |
| `llm-orchestrator` | `chatbot-manager-service` (RAG + Ollama integration) | `services-laravel/chatbot-manager-service` |
| `security-auditor` | `audit-security-service` | `services-laravel/audit-security-service` |

**Conformité fonctionnelle :** 5/5 modules CDC livrés en Laravel.
**Conformité technologique :** 0/5 (Laravel ≠ FastAPI) — argument soutenance
détaillé dans [`soutenance-argumentaire.md`](../soutenance-argumentaire.md).

## Statut des artefacts hérités du CDC initial

| Artefact | Décision |
|----------|----------|
| `services/<svc>/Dockerfile` | Conservés, marqués prototype dans `services/README.md` |
| `services/<svc>/requirements.txt` | id |
| `services/auth-users/src/*.py` (cette session) | Conservés à titre démonstratif, NON déployés |
| `infra/k8s/base/api-gateway/`, etc. | Conservés (manifests valides, ne dépendent pas du code Python) |

## Critère de réversibilité

Si le runtime Python devient prioritaire à l'avenir, la marche à suivre est :

1. Compléter le code applicatif des 5 services Python (~2000 lignes).
2. Builder + signer les images Python (déjà supportées par Jenkinsfile.cd).
3. Inverser la convention dans `infra/k8s/base/kustomization.yaml` (ajouter
   les deployments Python, retirer les Laravel).
4. Sceller cette décision dans un nouvel ADR.

L'inversion ne brise pas le repo : aucune référence cassée des deux côtés.

## Références

- Source de vérité runtime : [`docs/security/security-status-source-of-truth.md`](../security/security-status-source-of-truth.md)
- Audit complet : [`docs/missing-parts-audit.md`](../missing-parts-audit.md)
- Argumentaire soutenance : [`docs/soutenance-argumentaire.md`](../soutenance-argumentaire.md)
- Scope officiel : [`docs/architecture/official-scope.md`](official-scope.md)
