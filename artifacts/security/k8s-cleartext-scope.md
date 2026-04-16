# Kubernetes Clear-Text Scope Validation — SecureRAG Hub

| Contrôle | Résultat |
|---|---|
| Statut global | TERMINÉ |
| Overlays contrôlés | infra/k8s/overlays/dev infra/k8s/overlays/demo |
| Hôtes internes autorisés | auth-users chatbot-manager conversation-service audit-security-service portal-web |

## Règle appliquée

- Aucun manifest Kubernetes ne doit contenir de valeur directe `http://...` dans les variables d'environnement.
- Les communications internes HTTP doivent passer par `$(INTERNAL_SERVICE_SCHEME)://service:port`.
- Les pods concernés doivent porter l'annotation `security.securerag.dev/internal-cleartext-scope=cluster-only-networkpolicy`.
- Les hôtes autorisés sont limités aux Services internes SecureRAG et aux composants locaux du namespace.

## Notes

- Aucun écart détecté.

## Lecture sécurité

Le trafic HTTP interne reste accepté uniquement pour le mode demo/quasi pré-production local, sous réserve des NetworkPolicies et de l'absence d'exposition publique directe. Toute exposition utilisateur finale doit être publiée en HTTPS.
