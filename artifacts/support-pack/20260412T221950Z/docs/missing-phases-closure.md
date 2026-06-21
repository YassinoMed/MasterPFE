# Missing Phases Closure Runbook - SecureRAG Hub

## Objectif

Ce runbook décrit la manière de fermer les dernières phases encore partielles ou dépendantes de l'environnement, sans casser le scénario officiel `demo`.

## Principe

La commande principale est :

```bash
make close-missing-phases
```

Par défaut, elle est non destructive :

- elle ne déclenche pas volontairement Jenkins ;
- elle ne signe pas les images ;
- elle ne promeut pas les images ;
- elle n'installe pas d'addons Kubernetes ;
- elle génère uniquement des preuves factuelles.

## Phase 1 - preuves runtime réelles

### Webhook Jenkins

Commande :

```bash
make jenkins-webhook-proof
```

Résultat attendu :

- Jenkins répond sur `/github-webhook/` ;
- le endpoint refuse `GET/HEAD` avec `405`, ce qui est normal ;
- GitHub peut livrer un événement `push` en `POST`.

Diagnostic si échec :

- vérifier que Jenkins est accessible depuis Internet ;
- vérifier le port public `8085` ou le reverse proxy ;
- vérifier le plugin GitHub Jenkins ;
- vérifier les logs Jenkins.

### Preuve de commit consommé

Commande après un vrai `git push` :

```bash
RUN_CI_PUSH_PROOF=true make close-missing-phases
```

Résultat attendu :

- le dernier commit GitHub est visible dans Jenkins ;
- le job CI ou CD a consommé la révision attendue ;
- les preuves sont archivées dans `artifacts/jenkins`.

## Phase 2 - supply chain expert

Commande non destructive :

```bash
make release-attestation
make supply-chain-evidence
```

Commande complète si l'environnement est prêt :

```bash
RUN_SUPPLY_CHAIN_EXECUTE=true make close-missing-phases
```

Prérequis :

- images déjà construites dans le registry ;
- `syft` installé ;
- `cosign` installé ;
- clés Cosign hors Git ;
- registry local joignable.

Résultat attendu :

- SBOM générés ;
- signatures Cosign ;
- vérification Cosign ;
- promotion par digest ;
- attestation release rejouée.

## Phase 3 - sécurité cluster

Commande non destructive :

```bash
make cluster-security-proof
make observability-snapshot
```

Commande avec installation des addons :

```bash
RUN_CLUSTER_ADDON_INSTALL=true make close-missing-phases
```

Commande Enforce uniquement après prérequis :

```bash
RUN_CLUSTER_ADDON_INSTALL=true RUN_KYVERNO_ENFORCE=true make close-missing-phases
```

Points de vigilance :

- ne pas activer `Enforce` avant signatures et images vérifiées ;
- vérifier `kubectl top nodes` et `kubectl top pods` après metrics-server ;
- lire les `PolicyReport` Kyverno avant durcissement.

## Phase 4 - clôture

Commande :

```bash
make final-summary
make global-project-status
make support-pack
```

Preuves à conserver :

- `artifacts/final/missing-phases-closure.md` ;
- `artifacts/final/final-validation-summary.md` ;
- `artifacts/final/global-project-status.md` ;
- `artifacts/application/portal-service-connectivity.md` ;
- `artifacts/observability/observability-snapshot.md` ;
- `artifacts/release/release-attestation.md` ;
- `artifacts/support-pack/*.tar.gz`.

## Formulation soutenance

La formulation correcte est :

> Les dernières phases sont fermées autant que l'environnement le permet. Les scripts et preuves non destructives sont opérationnels. Les validations restantes sont explicitement dépendantes de Jenkins public, de la disponibilité du registry, de Cosign/Syft et d'un cluster actif pour metrics-server et Kyverno.
