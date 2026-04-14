# Clear-Text Protocol Risk Acceptance — SecureRAG Hub

## Objectif
Documenter précisément les usages `http://` qui restent acceptables dans SecureRAG Hub, afin d’éviter une interprétation trop optimiste des alertes SAST.

## Règle générale
Tout accès utilisateur ou exposition publique doit passer par HTTPS en environnement final.

Les URL `http://` sont tolérées uniquement dans les cas suivants :

- communications internes Kubernetes entre Services `ClusterIP`, protégées par NetworkPolicies ;
- health checks locaux ou Docker Compose sur `localhost` / `127.0.0.1` ;
- registre local kind `localhost:5001` / réseau Docker `kind`, utilisé comme registre OCI de démonstration ;
- endpoints de démonstration explicitement non exposés comme interface publique finale.

## Cas acceptés dans le dépôt
| Cas | Exemple | Justification | Condition |
|---|---|---|---|
| Service interne Kubernetes | `http://api-gateway:8080` | Trafic interne au namespace, non exposé directement | NetworkPolicies actives |
| Health check local | `http://localhost:8085/login` | Validation locale Jenkins | Ne pas présenter comme TLS production |
| Registre local kind | `http://securerag-registry:5000` | kind supporte couramment un registre local HTTP isolé | Réseau Docker local uniquement |
| OpenAPI local | `http://127.0.0.1:8091/api/v1` | Documentation de test local | Ajouter serveur HTTPS si exposition publique |

## Cas non acceptés
- Exposer Jenkins publiquement sans reverse proxy HTTPS.
- Exposer le portail public final uniquement en HTTP.
- Utiliser HTTP pour appeler des APIs externes sur Internet.
- Transmettre secrets, tokens ou mots de passe sur HTTP hors réseau local ou cluster interne.

## Validation recommandée
```bash
rg -n "http://" infra scripts platform services-laravel docs/openapi README.md --glob '!**/vendor/**' --glob '!artifacts/**'
```

Chaque occurrence doit être classée comme locale, interne cluster, registre kind, ou corrigée vers HTTPS.

## Formulation soutenance
La formulation défendable est :

> Le projet utilise HTTP pour la démonstration locale, les health checks et les communications internes au cluster. Toute exposition publique finale doit être protégée par un reverse proxy HTTPS et des secrets injectés hors dépôt.
