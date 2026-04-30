# SecureRAG Hub — Scope officiel (RAG vs Legacy)

> Référence canonique du périmètre de la soutenance et de la chaîne DevSecOps.
> Toute autre documentation (README, runbooks, rapports) doit s'aligner sur ce
> document. Statut : `TERMINÉ`.

## 1. Périmètre officiel — Plateforme Laravel (in-scope)

La démonstration officielle de SecureRAG Hub repose **exclusivement** sur les
cinq services Laravel ci-dessous, déployés via l'overlay Kustomize
`infra/k8s/overlays/demo` (ou `production` pour la cible HA).

| Service | Rôle | Image Docker | Overlay base |
|---|---|---|---|
| `portal-web` | Portail Blade (UI front, point d'entrée HTTP) | `securerag-hub-portal-web` | `infra/k8s/base/portal-web/` |
| `auth-users` | Authentification + gestion utilisateurs | `securerag-hub-auth-users` | `infra/k8s/base/auth-users/` |
| `chatbot-manager` | Orchestration conversationnelle | `securerag-hub-chatbot-manager` | `infra/k8s/base/chatbot-manager/` |
| `conversation-service` | Persistance des conversations | `securerag-hub-conversation-service` | `infra/k8s/base/conversation-service/` |
| `audit-security-service` | Audit & journalisation sécurité | `securerag-hub-audit-security-service` | `infra/k8s/base/audit-security-service/` |

Les sources Laravel correspondantes vivent sous :

- `platform/portal-web/`
- `services-laravel/auth-users-service/`
- `services-laravel/chatbot-manager-service/`
- `services-laravel/conversation-service/`
- `services-laravel/audit-security-service/`
- `services-laravel/shared-security/` (paquet PHP transverse)

## 2. Périmètre legacy — Stack Python/RAG (out-of-scope)

Les composants suivants existent toujours dans le dépôt pour des raisons
historiques (preuve de continuité de la phase R&D RAG initiale), mais ne font
**pas** partie de la démonstration DevSecOps officielle. Ils sont :

- absents de l'overlay `demo` ;
- présents uniquement dans l'overlay `infra/k8s/overlays/legacy/` ;
- **non scannés**, **non signés**, **non promus** en release officielle ;
- documentés ici pour transparence académique.

| Composant legacy | Localisation | Statut officiel |
|---|---|---|
| `api-gateway` | `services/api-gateway/` | `LEGACY_OUT_OF_SCOPE` |
| `knowledge-hub` | `services/knowledge-hub/` | `LEGACY_OUT_OF_SCOPE` |
| `llm-orchestrator` | `services/llm-orchestrator/` | `LEGACY_OUT_OF_SCOPE` |
| `security-auditor` | `services/security-auditor/` (Python) | `LEGACY_OUT_OF_SCOPE` |
| `auth-users` (Python) | `services/auth-users/` | Remplacé par version Laravel |
| `chatbot-manager` (Python) | `services/chatbot-manager/` | Remplacé par version Laravel |
| `ollama` | base K8s + binaries | `LEGACY_OUT_OF_SCOPE` |
| `qdrant` | base K8s | `LEGACY_OUT_OF_SCOPE` |

**Règle d'or** : aucune preuve, runbook, rapport ou alerte de la chaîne officielle
ne doit dépendre des composants ci-dessus. Si un script ou un manifeste les
référence, il doit appartenir à `infra/k8s/overlays/legacy/` ou être
explicitement préfixé `legacy-*`.

## 3. Autorité CI/CD

| Plan | Outil | Statut | Référence |
|---|---|---|---|
| CI source de vérité | **Jenkins** (`Jenkinsfile`) | `TERMINÉ` | `infra/jenkins/` |
| CD source de vérité | **Jenkins** (`Jenkinsfile.cd`) | `TERMINÉ` | `Jenkinsfile.cd` |
| GitOps (P1 nouveau) | **Argo CD** | `PRÊT_NON_EXÉCUTÉ` | `infra/k8s/argocd/` |
| Mirror / historique | GitHub Actions (`.github/workflows/`) | `LEGACY_MIRROR_ONLY` | en-têtes commentés |

GitHub Actions est conservé pour traçabilité historique mais **n'est plus
utilisé comme gate**. Toute évaluation CI/CD passe par Jenkins.

## 4. Politique de promotion

- **Digest-first** (`@sha256:…`) sur l'overlay `production` et `production-external-db`.
- Tag mutables tolérés uniquement sur `dev` et `demo`.
- Les images sont signées Cosign (keyless ou keyed) puis attestées avec leur
  SBOM CycloneDX avant promotion.
- Kyverno applique en mode `Audit` la politique `verify-cosign-images` et peut
  être basculé en `Enforce` via l'overlay `infra/k8s/policies/kyverno-enforce/`
  une fois les conditions remplies (cf. `docs/runbooks/kyverno-install.md`).

## 5. Taxonomie de statut

Tous les rapports doivent utiliser exactement les libellés suivants :

| Libellé | Signification |
|---|---|
| `TERMINÉ` | Contrôle exécuté avec succès et preuve archivée. |
| `PARTIEL` | Implémentation présente mais avec écarts ou findings ouverts. |
| `PRÊT_NON_EXÉCUTÉ` | Code/manifeste prêt, exécution non lancée (faute d'environnement). |
| `DÉPENDANT_DE_L_ENVIRONNEMENT` | Nécessite un service externe (Jenkins live, registre, cluster). |

## 6. Vérification automatique du scope

Le script `scripts/validate/validate-official-scope.sh` (livré avec les
améliorations expert) vérifie que :

- les Deployments rendus par l'overlay `demo` correspondent exactement aux
  cinq services Laravel listés en §1 ;
- aucun objet legacy de §2 n'apparaît dans `demo` ou `production` ;
- les images des Deployments officiels portent le préfixe attendu.

Tout écart fait sortir le script en code 1 et bloque les cibles
`make expert-readiness` et `make final-summary`.
