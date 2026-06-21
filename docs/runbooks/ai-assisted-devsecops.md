# AI-Assisted DevSecOps Runbook - SecureRAG Hub

## Objectif

Définir un usage sûr de l'IA dans la chaîne DevSecOps : assistance à l'analyse, corrélation et synthèse, sans remplacer les contrôles déterministes.

## Principe

L'IA peut aider à comprendre et prioriser les signaux. Elle ne doit pas décider seule d'une promotion, d'un déploiement, d'une exception sécurité ou d'une suppression d'alerte.

## Cas d'usage acceptables

- résumer les logs Jenkins ;
- expliquer un échec Semgrep, Trivy ou Gitleaks ;
- corréler incidents Kyverno, HPA et événements Kubernetes ;
- proposer une checklist de remédiation ;
- générer un résumé de support pack pour la soutenance.

## Cas d'usage interdits

- ignorer automatiquement une vulnérabilité critique ;
- publier une image non vérifiée ;
- générer ou stocker des secrets ;
- activer Kyverno Enforce sans validation humaine ;
- modifier les manifests de production sans revue.

## Workflow recommandé

1. Les outils déterministes produisent les faits : tests, scans, SBOM, signatures, digests, policy reports.
2. L'IA lit uniquement les artefacts nécessaires.
3. L'IA produit un résumé et des recommandations.
4. Un humain valide ou rejette les actions.
5. Les décisions importantes sont archivées dans les preuves.

## Prompt de synthèse sécurisé

```text
Analyse les artefacts DevSecOps fournis.
Ne propose aucune action destructive.
Classe les problèmes par criticité.
Indique les preuves manquantes.
Ne prétends pas qu'une étape a été exécutée si l'artefact correspondant est absent.
```

## Preuve soutenance

Présenter l'IA comme un copilote d'analyse. Les garde-fous restent Jenkins, Semgrep, Gitleaks, Trivy, Syft, Cosign, Kyverno et les validations humaines.
