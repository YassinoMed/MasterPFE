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

## Depuis un dépôt déjà cloné dans `/MasterPFE`

Le script all-in-one possède maintenant l'URL officielle par défaut. Cette commande est valide même si `REPO_URL` n'est pas défini :

```bash
cd /MasterPFE
chmod +x install_securerag_hub_all_in_one.sh securerag-launch-all.sh

./install_securerag_hub_all_in_one.sh
```

Pour relancer explicitement le runtime production sans détruire le cluster existant :

```bash
MODE=production \
RUN_METRICS=true \
RUN_KYVERNO_AUDIT=true \
RUN_SUPPORT_PACK=true \
./securerag-launch-all.sh
```

## Correction kind sur VPS

Le projet utilise `kind v0.29.0` comme version testée pour Debian/VPS. Si `kind version` indique `0.31.0` et que la création échoue avec :

```text
could not find a log line that matches "Reached target .*Multi-User System.*|detected cgroup v1"
```

réinstalle la version stable :

```bash
ARCH="$(dpkg --print-architecture)"
curl -fsSLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-${ARCH}"
chmod +x /usr/local/bin/kind
kind version
```

Puis supprime uniquement le cluster kind raté avant de relancer :

```bash
kind delete cluster --name securerag-dev || true
docker rm -f securerag-dev-control-plane securerag-dev-worker 2>/dev/null || true

MODE=production RUN_METRICS=true RUN_KYVERNO_AUDIT=true RUN_SUPPORT_PACK=true ./securerag-launch-all.sh
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
