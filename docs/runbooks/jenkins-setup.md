# Jenkins Setup Runbook — SecureRAG Hub

## Objectif
Mettre en service Jenkins comme source de vérité officielle de la CI/CD pour SecureRAG Hub, avec une configuration locale reproductible, versionnée et adaptée à une démonstration PFE.

## Pré-requis
- Docker Desktop ou Docker Engine en état de fonctionnement
- accès au dépôt GitHub [YassinoMed/MasterPFE](https://github.com/YassinoMed/MasterPFE)
- accès réseau sortant pour télécharger les plugins Jenkins et les outils de pipeline lors du build initial de l’image Jenkins
- clés Cosign disponibles localement

## Structure utilisée
- `infra/jenkins/Dockerfile`
- `infra/jenkins/docker-compose.yml`
- `infra/jenkins/plugins.txt`
- `infra/jenkins/casc/jenkins.yaml`
- `infra/jenkins/jobs/securerag-hub-ci.groovy`
- `infra/jenkins/jobs/securerag-hub-cd.groovy`

## Démarrage
```bash
mkdir -p artifacts/jenkins
bash scripts/jenkins/bootstrap-local-credentials.sh
bash scripts/jenkins/bootstrap-local-kubeconfig.sh
cd infra/jenkins
docker compose up --build -d
docker compose ps
```

## Accès
- URL Jenkins : `http://localhost:8085`
- utilisateur initial : `admin`
- mot de passe initial : `change-me-now`

## Post-installation immédiate
1. Se connecter à Jenkins.
2. Changer immédiatement le mot de passe administrateur local.
3. Vérifier que les jobs `securerag-hub-ci` et `securerag-hub-cd` sont présents.
4. Vérifier que le dépôt référencé est correct dans :
   - `infra/jenkins/jobs/securerag-hub-ci.groovy`
   - `infra/jenkins/jobs/securerag-hub-cd.groovy`

## Credentials Jenkins
En mode local, les credentials Cosign peuvent être bootstrapés automatiquement par :
```bash
bash scripts/jenkins/bootstrap-local-credentials.sh
```

Le conteneur Jenkins lit ensuite :
- `infra/jenkins/secrets/cosign.key`
- `infra/jenkins/secrets/cosign.pub`
- `infra/jenkins/secrets/cosign.password`
- `infra/jenkins/secrets/kubeconfig`

et crée/actualise automatiquement les credentials :
- `cosign-private-key`
- `cosign-public-key`
- `cosign-password`

Le fichier `infra/jenkins/secrets/kubeconfig` est monté dans le conteneur Jenkins pour permettre à `kubectl` d’accéder au cluster `kind`.

## Accès au registre et au cluster depuis Jenkins
Le conteneur Jenkins démarre des forwarders locaux vers :
- `localhost:5001` -> registre local `kind`
- `localhost:6443` -> API server `kind`

Cela permet de conserver les mêmes valeurs de `REGISTRY_HOST` et les mêmes scripts qu’en exécution hôte.

## Triggers
- le job `securerag-hub-ci` utilise un polling SCM léger (`H/5 * * * *`) pour une démo locale simple
- en environnement plus mature, remplacer ce mode par un webhook GitHub

## Jobs attendus

### `securerag-hub-ci`
- checkout
- lint/tests/couverture
- Semgrep
- Gitleaks
- Trivy filesystem
- archivage des rapports

### `securerag-hub-cd`
- vérification des signatures du tag source
- promotion sans rebuild vers un tag cible
- génération SBOM sur le tag promu
- vérification avant déploiement
- déploiement sur `kind`
- validations post-déploiement

## Artefacts à vérifier dans Jenkins
- `.coverage-artifacts/**`
- `security/reports/**`
- `artifacts/sbom/**`
- `artifacts/release/**`
- `artifacts/validation/**`

## Vérifications de bon fonctionnement
```bash
docker compose -f infra/jenkins/docker-compose.yml logs -f
curl -fsS http://localhost:8085/login >/dev/null && echo "Jenkins OK"
bash scripts/jenkins/collect-local-proof.sh
```

## Points d’attention sécurité
- le compte `admin` local n’est acceptable que pour un environnement de démonstration
- les credentials Cosign ne doivent jamais être committés dans le dépôt
- l’accès au socket Docker donne des privilèges élevés au conteneur Jenkins ; ce choix est acceptable pour une démo locale, mais doit être remplacé par des agents dédiés en contexte professionnel plus strict
- si Jenkins devient la source de vérité officielle, les workflows GitHub Actions du dépôt doivent être dépréciés explicitement

## Dépannage rapide
- Jenkins ne démarre pas : `docker compose -f infra/jenkins/docker-compose.yml logs`
- les jobs n’apparaissent pas : vérifier `CASC_JENKINS_CONFIG` et les montages `./jobs`
- les builds échouent sur Docker : vérifier l’accès à `/var/run/docker.sock`
- les étapes Cosign échouent : vérifier les IDs de credentials et les fichiers clés
