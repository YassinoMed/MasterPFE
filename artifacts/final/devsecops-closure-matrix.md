# DevSecOps Closure Matrix - SecureRAG Hub

- Generated at UTC: `2026-04-23T14:16:09Z`

| Bloc | Tâche | État | Priorité | Action restante |
|---|---|---:|---:|---|
| Bloc A | Preuve runtime imageID / digest | DÉPENDANT_DE_L_ENVIRONNEMENT | P0 | Rejouer `make runtime-image-proof` ou `make final-runtime-proof` sur le cluster cible. |
| Bloc A | Pods récents, logs, events et healthchecks | PARTIEL | P0 | Rejouer `make production-runtime-evidence` et `make portal-service-proof` après le dernier déploiement. |
| Bloc A | HPA runtime sans `<unknown>` | TERMINÉ | P1 | Rejouer `make hpa-runtime-proof` après installation ou réparation de metrics-server. |
| Bloc B | Sécurité post-déploiement runtime | DÉPENDANT_DE_L_ENVIRONNEMENT | P1 | Rejouer `make runtime-security-postdeploy` sur les pods actifs du namespace cible. |
| Bloc B | Hardening workloads / guards statiques | TERMINÉ | P1 | Corriger les lignes `FAIL` éventuelles puis rejouer `make k8s-ultra-hardening` et `make k8s-resource-guards`. |
| Bloc C | Supply chain complète / attestation release | PARTIEL | P0 | Rejouer `make supply-chain-execute` puis `make release-proof-strict` avec Docker, registry, Trivy, Syft et Cosign. |
| Bloc C | Déploiement digest immuable no-rebuild | PRÊT_NON_EXÉCUTÉ | P0 | Rejouer le déploiement avec `REQUIRE_DIGEST_DEPLOY=true` et des digests promus présents. |
| Bloc C | Provenance SLSA-style | PRÊT_NON_EXÉCUTÉ | P0 | Régénérer après attestation release complète via `make release-provenance`. |
| Bloc D | Kyverno Audit / PolicyReports runtime | DÉPENDANT_DE_L_ENVIRONNEMENT | P1 | Rejouer `make kyverno-runtime-proof` avec cluster, CRDs, contrôleurs et PolicyReports joignables. |
| Bloc D | Kyverno Enforce readiness | DÉPENDANT_DE_L_ENVIRONNEMENT | P2 | Garder Audit tant que `kyverno-enforce-readiness` n’est pas `TERMINÉ`. |
| Bloc E | PostgreSQL externe / overlay / secret DB | PRÊT_NON_EXÉCUTÉ | P1 | Utiliser `infra/k8s/overlays/production-external-db` et créer `securerag-database-secrets` hors Git. |
| Bloc E | Backup / restore prouvés | PRÊT_NON_EXÉCUTÉ | P1 | Renseigner les variables DB et rejouer `make data-resilience-proof` sur une base de restauration isolée. |
| Bloc F | Secrets management moderne | PRÊT_NON_EXÉCUTÉ | P1 | Appliquer le Secret DB externe réel; garder SOPS/age et ESO/Vault en `PRÊT_NON_EXÉCUTÉ` tant qu’ils ne tournent pas. |
| Bloc F | Jenkins webhook / SCM proof | PARTIEL | P1 | Rejouer `make jenkins-webhook-proof` et `make jenkins-ci-push-proof` sur le Jenkins cible. |
| Bloc F | Support pack final | TERMINÉ | P0 | Régénérer après les preuves finales réelles via `make support-pack`. |
| Bloc F | Source de vérité finale | DÉPENDANT_DE_L_ENVIRONNEMENT | P0 | Régénérer `make final-source-of-truth` et `make final-summary` après la dernière campagne. |

## Synthèse par état

- `TERMINÉ`: 3
- `PARTIEL`: 3
- `PRÊT_NON_EXÉCUTÉ`: 5
- `DÉPENDANT_DE_L_ENVIRONNEMENT`: 5

## Lecture honnête

- `TERMINÉ` signifie prouvé avec un artefact présent et cohérent.
- `PARTIEL` signifie que la preuve existe mais reste incomplète, échouée ou incohérente.
- `PRÊT_NON_EXÉCUTÉ` signifie que le dépôt est prêt mais que la campagne réelle n’a pas été rejouée.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` signifie qu’un cluster, Jenkins, une registry ou une base externe manque pour la preuve live.
