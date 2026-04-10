# Jenkins Recovery Runbook — SecureRAG Hub

## Objectif
Fournir une procedure courte de reprise de Jenkins local pour la demonstration et l'exploitation de la chaine CI/CD.

## Symptomes typiques

- Jenkins ne repond plus sur `http://localhost:8085`
- les jobs `securerag-hub-ci` et `securerag-hub-cd` n'apparaissent plus
- les credentials Cosign ne sont plus disponibles
- Jenkins ne peut plus joindre Docker ou le cluster local

## Redemarrage rapide

```bash
docker compose -f infra/jenkins/docker-compose.yml down
docker compose -f infra/jenkins/docker-compose.yml up --build -d
bash scripts/jenkins/wait-for-jenkins.sh
```

## Re-bootstrap minimal

```bash
bash scripts/jenkins/bootstrap-local-credentials.sh
bash scripts/jenkins/bootstrap-local-kubeconfig.sh
docker compose -f infra/jenkins/docker-compose.yml up --build -d
```

## Verifications post-reprise

```bash
curl -I http://localhost:8085
docker logs securerag-jenkins --tail 100
```

Verifier ensuite dans l'interface :

- presence du job `securerag-hub-ci`
- presence du job `securerag-hub-cd`
- presence des credentials Cosign

## Sauvegarde minimale recommandee

Conserver au minimum :

- `infra/jenkins/casc/`
- `infra/jenkins/jobs/`
- `infra/jenkins/init.groovy.d/`
- `infra/jenkins/secrets/` pour la demonstration locale
- le volume Jenkins (`jenkins_home`) si une restauration exacte est necessaire

## Rotation simple des credentials Cosign de demo

1. arreter Jenkins ;
2. sauvegarder ou supprimer `infra/jenkins/secrets/cosign.*` et `cosign.password` ;
3. relancer :

```bash
bash scripts/jenkins/bootstrap-local-credentials.sh
docker compose -f infra/jenkins/docker-compose.yml up --build -d
```

Cette rotation est adaptee a un environnement de demonstration, pas a une production.

## Droits minimums Jenkins

L'instance Jenkins locale doit pouvoir :

- lire le workspace du depot ;
- acceder au socket Docker local ;
- utiliser le kubeconfig local injecte ;
- lire les fichiers de credentials de demonstration.

## Point de vigilance

Si Jenkins est de nouveau indisponible juste avant une soutenance, la voie de repli officielle reste :

- l'execution locale des scripts shell versionnes ;
- la conservation des artefacts deja produits ;
- l'usage des workflows GitHub legacy uniquement en relance manuelle exceptionnelle, si explicitement annonce.
