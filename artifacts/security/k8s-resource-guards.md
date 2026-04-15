# Kubernetes Resource Guards Validation — SecureRAG Hub

| Contrôle | Résultat |
|---|---|
| Statut global | TERMINÉ |
| Overlays contrôlés | infra/k8s/overlays/dev infra/k8s/overlays/demo |
| Contrôle container | resources.requests.ephemeral-storage et resources.limits.ephemeral-storage requis |
| Contrôle namespace | LimitRange avec defaults ephemeral-storage requis |

## Notes

- Aucun écart détecté.

## Lecture sécurité

Les workloads SecureRAG déclarent explicitement une consommation temporaire attendue, et le namespace conserve un LimitRange de secours. Cela réduit le risque d'éviction imprévisible et ferme l'alerte Sonar/Kubernetes sur les requêtes de stockage éphémère.
