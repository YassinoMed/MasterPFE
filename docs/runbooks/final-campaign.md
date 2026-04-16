# Final Campaign Runbook — SecureRAG Hub

## Objectif
Formaliser la campagne de reference unique du projet :

`verify -> promote -> deploy -> validate`

avec une logique de :

- scenario officiel stable ;
- promotion sans rebuild ;
- evidence release + runtime ;
- support pack de soutenance.

## Source de verite
Jenkins est la source de verite officielle pour la CI/CD.

Ce runbook decrit la campagne equivalente rejouable localement a partir des memes scripts.

## Gates CI -> CD

La CD ne doit etre lancee que si :

1. les tests passent ;
2. les scans principaux sont au vert ou acceptes explicitement ;
3. les artefacts images existent dans le registre ;
4. la verification Cosign passe ;
5. la promotion produit un digest trace ;
6. l'environnement local est declare `go` dans la checklist.

## Scenario officiel

Le scenario officiel de demonstration est :

- `OFFICIAL_SCENARIO=demo`
- `PROMOTION_STRATEGY=digest`
- `VALIDATION_IMAGE=curlimages/curl:8.11.1`
- runtime officiel : `portal-web`, `auth-users`, `chatbot-manager`, `conversation-service`, `audit-security-service`

## Commande recommandee

### Verification preparatoire
```bash
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=dry-run \
bash scripts/cd/run-final-campaign.sh
```

### Campagne reelle
```bash
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=execute \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
bash scripts/cd/run-final-campaign.sh
```

## Scénario legacy RAG/Ollama

Le scénario `real/Ollama` est exclu de la campagne officielle actuelle car les sources Python applicatives sous `services/` sont absentes. Toute réactivation doit être traitée comme une évolution distincte avec sources restaurées, manifests et preuves runtime.

## Artefacts produits

- `artifacts/release/verify-summary.txt`
- `artifacts/release/promotion-by-digest-summary.txt`
- `artifacts/release/promotion-digests.txt`
- `artifacts/release/release-evidence.md`
- `artifacts/sbom/*`
- `artifacts/validation/*`
- `artifacts/final/*`
- `artifacts/support-pack/<timestamp>/`

## Resultat attendu

Une campagne reussie doit produire :

- un tag source verifie ;
- un tag cible promu sans rebuild ;
- un digest trace par service ;
- un deploiement effectif ;
- un rapport de validation post-deploiement ;
- un support pack final.
