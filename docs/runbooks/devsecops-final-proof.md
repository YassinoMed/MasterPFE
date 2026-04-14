# SecureRAG Hub - DevSecOps Final Proof Runbook

## Objectif

Produire une preuve DevSecOps finale en une seule commande, sans casser le scénario officiel `demo`.

Le script associé est :

```bash
scripts/validate/run-devsecops-final-proof.sh
```

Par défaut, il est non destructif :

- il ne déclenche pas Jenkins ;
- il ne signe pas d'images ;
- il ne promeut pas d'images ;
- il n'installe pas `metrics-server` ;
- il n'installe pas Kyverno ;
- il ne modifie pas le cluster.

## Commande recommandée pour la soutenance

```bash
make devsecops-final-proof
```

Artefact attendu :

```text
artifacts/final/devsecops-final-proof.md
```

## Preuve Jenkins après push GitHub

Après un vrai `git push`, utiliser :

```bash
JENKINS_URL=https://jenkins.example.invalid \
JENKINS_USER=admin \
JENKINS_TOKEN=<jenkins-api-token> \
RUN_CI_PUSH_PROOF=true \
make devsecops-final-proof
```

Pour un laboratoire local sans TLS, `http://localhost:8085` reste acceptable. Pour un serveur cloud final ou assimilé production, Jenkins doit passer par un reverse proxy HTTPS avant d’être présenté comme accès public.

Artefacts attendus :

```text
artifacts/jenkins/github-webhook-validation.md
artifacts/jenkins/ci-push-trigger-proof.md
```

## Supply chain execute

À activer uniquement si les prérequis sont disponibles :

- Docker ;
- registry locale ;
- images sources ;
- `cosign` ;
- `syft` ;
- clés Cosign sûres.

Commande :

```bash
RUN_SUPPLY_CHAIN_EXECUTE=true make devsecops-final-proof
```

Artefacts attendus :

```text
artifacts/release/sign-summary.txt
artifacts/release/verify-summary.txt
artifacts/release/promotion-by-digest-summary.txt
artifacts/release/promotion-digests.txt
artifacts/sbom/sbom-index.txt
```

## metrics-server et Kyverno

À activer uniquement sur un cluster stable :

```bash
RUN_CLUSTER_ADDON_INSTALL=true make devsecops-final-proof
```

Pour Kyverno `Enforce`, attendre que la signature Cosign et les policies Audit soient prouvées :

```bash
RUN_CLUSTER_ADDON_INSTALL=true \
RUN_KYVERNO_ENFORCE=true \
make devsecops-final-proof
```

## Interprétation

- `OK` : preuve produite dans l'environnement courant.
- `PARTIEL` : script présent mais preuve complète non obtenue.
- `SKIPPED` : étape volontairement désactivée pour éviter une mutation.
- `MUTATING_RELEASE` : étape pouvant signer ou promouvoir des images.
- `MUTATING_CLUSTER` : étape pouvant installer ou modifier des ressources cluster.

## Règle de soutenance

Ne présenter comme réellement exécuté que ce qui dispose d'un artefact daté.

Si une étape est `SKIPPED` ou `PARTIEL`, la présenter comme prête à être exécutée ou dépendante de l'environnement.
