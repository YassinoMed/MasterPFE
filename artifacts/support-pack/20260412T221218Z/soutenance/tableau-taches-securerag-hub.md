# Tableau Des Tâches SecureRAG Hub

Ce tableau distingue l'état fonctionnel réel du projet après consolidation applicative et DevSecOps. Il ne présente comme terminé que les éléments créés, testés ou déjà validés. Les éléments dépendants d'un environnement actif restent explicitement marqués comme partiels.

| Bloc | Tâche | État | Priorité | Action restante |
|---|---|---:|---:|---|
| Gouvernance | Scénario officiel `demo` | TERMINÉ | P0 | Aucune |
| Gouvernance | Jenkins comme CI/CD officielle | TERMINÉ | P0 | Aucune |
| Gouvernance | GitHub Actions legacy | TERMINÉ | P0 | Aucune |
| CI qualité | Tests Python, coverage, Ruff, Semgrep, Gitleaks, Trivy fs | TERMINÉ | P0 | Aucune |
| Kubernetes demo | kind, registry, namespace, overlays, services, NodePorts | TERMINÉ | P0 | Aucune |
| Kubernetes demo | Workloads demo `9/9 Running` | TERMINÉ | P0 | Revalider avant soutenance |
| Portail Blade | Landing, health, dashboards `/app`, `/admin`, `/devsecops` | TERMINÉ | P1 | Aucune |
| Portail Blade | `/admin/users` connecté à `auth-users-service` | TERMINÉ | P1 | Démarrer le service pour données persistantes |
| Portail Blade | `/admin/roles` connecté à `auth-users-service` | TERMINÉ | P1 | Démarrer le service pour données persistantes |
| Portail Blade | `/chatbots` connecté à `chatbot-manager-service` | TERMINÉ | P1 | Démarrer le service pour données persistantes |
| Portail Blade | `/chat` connecté à `conversation-service` | TERMINÉ | P2 | Démarrer le service pour données persistantes |
| Portail Blade | `/history` connecté à `conversation-service` | TERMINÉ | P2 | Démarrer le service pour données persistantes |
| Portail Blade | `/security` connecté à `audit-security-service` | TERMINÉ | P2 | Démarrer le service pour données persistantes |
| Laravel métier | `auth-users-service` | TERMINÉ | P1 | Aucune |
| Laravel métier | `chatbot-manager-service` | TERMINÉ | P1 | Aucune |
| Laravel métier | `conversation-service` | TERMINÉ | P2 | Intégration Docker/Kubernetes optionnelle |
| Laravel métier | `audit-security-service` | TERMINÉ | P2 | Intégration Docker/Kubernetes optionnelle |
| Tests Laravel | Portail + 4 microservices métier | TERMINÉ | P1 | Rejouer `make laravel-test` |
| Preuves applicatives | Connectivité portail ↔ microservices | TERMINÉ | P1 | Rejouer `make portal-service-proof` avec services lancés |
| OpenAPI | `auth-users-service.yaml` | TERMINÉ | P3 | Ajouter exemples si demandé |
| OpenAPI | `chatbot-manager-service.yaml` | TERMINÉ | P3 | Ajouter exemples si demandé |
| OpenAPI | `conversation-service.yaml` | TERMINÉ | P3 | Ajouter exemples si demandé |
| OpenAPI | `audit-security-service.yaml` | TERMINÉ | P3 | Ajouter exemples si demandé |
| Jenkins | Webhook GitHub vers Jenkins | PARTIEL | P1 | Revalider avec Jenkins actif et URL publique |
| Jenkins | CI automatique au push GitHub | PARTIEL | P1 | Faire un `git push`, vérifier build Jenkins, archiver preuve |
| Jenkins | Accès SCM GitHub depuis conteneur Jenkins | PARTIEL | P1 | Vérifier egress réseau ou utiliser fallback `/workspace` |
| Preuves runtime | Orchestration des phases manquées | TERMINÉ | P1 | Rejouer `make close-missing-phases` sur l'environnement final |
| Supply chain | SBOM Syft | PARTIEL | P3 | Exécuter avec images et Syft disponibles |
| Supply chain | Signature Cosign | PARTIEL | P3 | Fournir clés Cosign et signer images |
| Supply chain | Vérification Cosign | PARTIEL | P3 | Vérifier signatures avant promotion |
| Supply chain | Promotion par digest | PARTIEL | P3 | Promouvoir images validées par digest |
| CD | Déploiement sans rebuild | PARTIEL | P3 | Rejouer `CAMPAIGN_MODE=execute` si environnement prêt |
| Kubernetes sécurité | metrics-server | PARTIEL | P3 | Installer et valider Metrics API |
| Kubernetes sécurité | HPA exploitable | PARTIEL | P3 | Valider après metrics-server |
| Kubernetes sécurité | Kyverno Audit | PARTIEL | P3 | Installer Kyverno et appliquer policies Audit |
| Kubernetes sécurité | Kyverno Enforce | PARTIEL | P3 | Activer uniquement après signatures prouvées |
| Mémoire | Chapitre 1 et références bibliographiques | TERMINÉ | P2 | Adapter au gabarit final LaTeX |
| Soutenance | Démo 5-7 minutes | TERMINÉ | P1 | Répéter avec environnement final |
| Soutenance | Support pack final | TERMINÉ | P1 | Régénérer juste avant la soutenance |
| Mémoire | Artefacts DevSecOps à citer | TERMINÉ | P1 | Inclure `docs/memoire/artefacts-devsecops-a-citer.tex` dans le mémoire final |

## Synthèse Par État

- TERMINÉ : socle demo, portail Blade connecté avec fallback, quatre services Laravel métier, tests Laravel, contrats OpenAPI, preuves non destructives, chapitre 1 référencé, orchestration des phases manquées.
- PARTIEL : Jenkins webhook réel, CI push réelle, supply chain execute, metrics-server, HPA, Kyverno Audit/Enforce.
- DÉPENDANT DE L'ENVIRONNEMENT : Jenkins actif, accès GitHub depuis conteneur, registry et images locales, clés Cosign, cluster kind disponible.

## Ordre Recommandé Final

1. Démarrer l'environnement cloud/Jenkins/kind officiel.
2. Exécuter `make laravel-test`.
3. Exécuter `make jenkins-webhook-proof`, puis faire un `git push` de validation.
4. Exécuter `make devsecops-final-proof`.
5. Exécuter `make supply-chain-execute` seulement si Docker, registry, Syft, Cosign et clés sont disponibles.
6. Installer metrics-server et Kyverno si le cluster est stable.
7. Régénérer `make final-summary support-pack`.

## Conclusion

Le projet est opérationnel pour la démonstration applicative et DevSecOps en mode `demo`. Les blocs avancés encore partiels ne relèvent plus d'un manque de code principal, mais de validations dépendantes de l'environnement d'exécution.
