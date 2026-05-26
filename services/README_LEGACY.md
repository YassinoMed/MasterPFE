# ⚠️ Services Legacy Python — Exclus du scénario officiel

## Statut : EXCLU DU BUILD / DEPLOY / TEST OFFICIEL

Ce dossier contient les **prototypes initiaux** des microservices SecureRAG Hub, développés en Python durant la phase exploratoire du projet.

## Historique

Les services Python suivants ont été conçus comme preuve de concept pour valider l'architecture RAG/LLM :

| Service | Rôle initial | Statut actuel |
|---------|-------------|---------------|
| `api-gateway/` | Routage API centralisé | Remplacé par le portail Laravel |
| `auth-users/` | Authentification utilisateurs | Remplacé par `services-laravel/auth-users-service/` |
| `chatbot-manager/` | Gestion catalogue chatbots | Remplacé par `services-laravel/chatbot-manager-service/` |
| `knowledge-hub/` | Base de connaissances RAG | Perspective future, sources Python absentes |
| `llm-orchestrator/` | Orchestration LLM/Ollama | Perspective future, sources Python absentes |
| `security-auditor/` | Audit sécurité | Remplacé par `services-laravel/audit-security-service/` |

## Pourquoi ces dossiers sont conservés

1. **Traçabilité** : ils documentent l'évolution architecturale du projet (Python → Laravel).
2. **Référence** : les manifests Kubernetes associés (`infra/k8s/base/`) conservent les définitions pour une restauration éventuelle.
3. **Perspective RAG** : les services `knowledge-hub` et `llm-orchestrator` pourront être restaurés si les sources Python sont ajoutées dans une version future.

## Version officielle

La version officielle de SecureRAG Hub repose sur **Laravel** :

| Composant officiel | Chemin |
|-------------------|--------|
| Portail web (Blade) | `platform/portal-web/` |
| Auth & Users | `services-laravel/auth-users-service/` |
| Chatbot Manager | `services-laravel/chatbot-manager-service/` |
| Conversation Service | `services-laravel/conversation-service/` |
| Audit Security Service | `services-laravel/audit-security-service/` |

## Ce qui est exclu

- ❌ **Build Docker** : aucune image n'est construite depuis `services/`
- ❌ **Tests CI** : aucun test n'est exécuté depuis `services/`
- ❌ **Déploiement** : aucun pod Kubernetes n'est déployé depuis `services/`
- ❌ **Scan sécurité** : les sources Python ne sont pas scannées en CI officiel
- ❌ **Couverture** : non comptabilisée dans le seuil de couverture

## Recommandation

Ne pas supprimer ce dossier. Il fait partie de l'historique du projet et peut être utile pour :
- comprendre les choix d'architecture lors de la soutenance ;
- documenter la migration Python → Laravel ;
- restaurer les services RAG/LLM dans une version future.

---

*Document créé dans le cadre de la finalisation DevSecOps — branche `devsecops-final-hardening`*
