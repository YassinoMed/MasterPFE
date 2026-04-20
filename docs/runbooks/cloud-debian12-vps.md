# Déploiement VPS Debian 12 depuis Git

Ce runbook corrige la syntaxe `REPO_URL` pour un serveur Debian 12 vierge ou quasi vierge.

## Commande corrigée

Ne pas laisser un `\` seul après l'affectation. Le `\` sert uniquement à continuer une commande sur la ligne suivante.

```bash
export REPO_URL="https://github.com/YassinoMed/MasterPFE.git"
```

Ou, si la variable est passée à une commande :

```bash
REPO_URL="https://github.com/YassinoMed/MasterPFE.git" \
APP_DIR="/MasterPFE" \
BRANCH="main" \
bash scripts/deploy/bootstrap-cloud-debian12-from-git.sh
```

## Depuis un VPS sans dépôt cloné

```bash
apt-get update
apt-get install -y ca-certificates git

REPO_URL="https://github.com/YassinoMed/MasterPFE.git"
APP_DIR="/MasterPFE"
BRANCH="main"

git clone --branch "${BRANCH}" "${REPO_URL}" "${APP_DIR}"
cd "${APP_DIR}"

bash scripts/deploy/cloud-debian12-full-run.sh
```

## Avec le script de bootstrap versionné

Depuis une copie locale du dépôt :

```bash
REPO_URL="https://github.com/YassinoMed/MasterPFE.git" \
APP_DIR="/MasterPFE" \
BRANCH="main" \
RUN_STACK="true" \
bash scripts/deploy/bootstrap-cloud-debian12-from-git.sh
```

## Lecture honnête

- Action mutative : clone ou mise à jour fast-forward du dépôt dans `APP_DIR`.
- Action mutative si `RUN_STACK=true` : création cluster kind, build images, déploiement Kubernetes, démarrage Jenkins.
- Dépendances : accès réseau GitHub, Docker fonctionnel, kind, kubectl, registry local.
- Le mode `demo` reste inchangé.
