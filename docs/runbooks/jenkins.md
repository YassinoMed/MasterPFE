# Jenkins Live Proof Runbook - SecureRAG Hub

## Objectif

Fermer la preuve Jenkins live sans hardcoder le nom du job et sans bloquer la clôture Kubernetes si le token API ou les permissions ne sont pas disponibles.

## Variables

```bash
export JENKINS_URL="http://127.0.0.1:8085"
export JENKINS_USER="admin"
export JENKINS_TOKEN="<api-token>"
export JENKINS_JOB_NAME="masterpfe-ci"
```

`JENKINS_JOB_NAME` remplace l'ancien implicite `securerag-hub-ci`. Si le job réel s'appelle `masterpfe-ci`, aucune modification de script n'est nécessaire.

## Preuves

```bash
make jenkins-webhook-proof
make jenkins-ci-push-proof
```

Artefacts attendus :

- `artifacts/validation/jenkins-webhook-proof.md`
- `artifacts/validation/jenkins-ci-push-proof.md`

## Diagnostics

- HTTP 401 : token absent ou invalide.
- HTTP 403 : l'utilisateur authentifié n'a pas les permissions nécessaires sur l'API ou le job.
- HTTP 404 : `JENKINS_JOB_NAME` ne correspond pas au job réel.
- HTTP 000 : Jenkins n'est pas joignable à `JENKINS_URL`.

## Statut honnête

Jenkins live reste `DÉPENDANT_DE_L_ENVIRONNEMENT` si l'API, le token ou les permissions du job ne permettent pas la preuve. Cette situation ne bloque pas les preuves Kubernetes, supply chain ou runtime déjà archivées.
