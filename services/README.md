# `services/` — Implémentations Python / FastAPI (legacy / expérimental)

> ⚠️ **Statut :** Prototype Python — **non utilisé** dans le runtime officiel.
> Le runtime officiel de SecureRAG Hub est **Laravel** ; voir
> [`docs/architecture/decision-001-laravel-as-official-runtime.md`](../docs/architecture/decision-001-laravel-as-official-runtime.md).

## Pourquoi ce dossier existe

Ce dossier conserve les **squelettes des microservices Python / FastAPI**
prévus dans le cahier des charges initial :

- `api-gateway/` — passerelle prévue, JWT + routing
- `auth-users/` — utilisateurs + JWT + RBAC (la seule à avoir un début de code
  applicatif, `services/auth-users/src/` — exclusivement à titre de
  référence d'implémentation, **non build / non déployée**)
- `chatbot-manager/` — équivalent Python du `llm-orchestrator`
- `knowledge-hub/` — vectorstore / Qdrant
- `llm-orchestrator/` — RAG + LLM Ollama
- `security-auditor/` — détection prompt-injection + audit

## Pourquoi ce code n'est pas en production

| Critère | État Python `services/*/` | État Laravel `services-laravel/*` |
|---------|---------------------------|-----------------------------------|
| Code applicatif réel | quasi-vide | ~10 000 lignes, mature |
| Tests | 1 fichier (auth-users seul) | 26 fichiers PHPUnit |
| Référencé par Jenkinsfile (CI) | non | oui (`LARAVEL_APPS`) |
| Référencé par Jenkinsfile.cd (CD) | non | oui (build, scan, sign, deploy) |
| Déployé sur le cluster kind / production | non | oui |
| Couvert par Cosign + Trivy + SBOM | non | oui |

## Conservé pour quoi faire alors ?

1. **Traçabilité du cahier des charges initial.** Le projet a démarré sur
   une hypothèse FastAPI ; ces dossiers documentent ce choix initial.
2. **Référence de structure de microservices** au cas où un futur sprint
   souhaite implémenter une variante Python à côté de Laravel.
3. **Démonstration pédagogique** : le passage Python → Laravel illustre
   un arbitrage architectural réaliste, sujet d'examen soutenance.

## Ne pas

- ❌ Builder les images de ce dossier en CI/CD (les Dockerfiles présents
  font `COPY src ./src` mais `src/` n'existe pas pour la majorité).
- ❌ Référencer ce dossier dans un nouveau manifest Kubernetes.
- ❌ Présenter ces services comme déployés en soutenance.

## Pour réactiver ce runtime à l'avenir

Voir la section "Critère de réversibilité" dans l'ADR-001 :
[`docs/architecture/decision-001-laravel-as-official-runtime.md`](../docs/architecture/decision-001-laravel-as-official-runtime.md).
