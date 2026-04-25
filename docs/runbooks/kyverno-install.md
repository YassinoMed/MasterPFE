# Kyverno Installation Runbook — SecureRAG Hub

## Objectif
Rendre Kyverno installable de maniere reproductible sur le cluster local de demonstration, puis appliquer les policies SecureRAG en mode `Audit` ou `Enforce`.

## Prerequis
- un cluster Kubernetes joignable via `kubectl`
- acces reseau pour recuperer le manifeste officiel Kyverno
- `kubectl` avec support Kustomize

## Fichiers utilises
- `infra/k8s/addons/kyverno/kustomization.yaml`
- `infra/k8s/policies/kyverno/kustomization.yaml`
- `infra/k8s/policies/kyverno-enforce/kustomization.yaml`
- `scripts/deploy/install-kyverno.sh`

## Installation en mode Audit
```bash
bash scripts/deploy/install-kyverno.sh
```

Cela :
- installe Kyverno dans le namespace `kyverno`
- attend les deployments Kyverno
- verifie la presence du CRD `clusterpolicies.kyverno.io`
- rend les policies avec Kustomize
- execute un dry-run server-side
- applique les policies SecureRAG en mode `Audit`

## Installation avec policies Enforce
```bash
KYVERNO_POLICY_MODE=enforce bash scripts/deploy/install-kyverno.sh
```

Cette variante utilise l'overlay `infra/k8s/policies/kyverno-enforce`. Elle bascule uniquement les policies image sûres en `Enforce` :

- interdiction des tags `latest` ;
- restriction à `securerag-registry:5000` ;
- exigence de digest `@sha256` pour les images SecureRAG officielles ;
- `verifyImages` Cosign lorsque les signatures sont disponibles.

Les policies plus larges de securite Pod, volumes, services et probes restent en `Audit` au depart pour eviter de casser le runtime stable pendant la demo.

## Verification post-install
```bash
kubectl get pods -n kyverno
kubectl get crd clusterpolicies.kyverno.io
kubectl get clusterpolicy
kubectl get policyreport,clusterpolicyreport -A
bash scripts/validate/validate-cluster-security-addons.sh
make kyverno-runtime-proof
```

Preuves attendues :
- `artifacts/validation/cluster-security-addons.md`
- `artifacts/validation/kyverno-runtime-report.md`

## Strategie Audit -> Enforce

### Audit
Mode recommande pour :
- le developpement local ;
- les campagnes de demonstration ;
- les premiers tests de compatibilite des policies.

Dans ce mode, la policy produit des resultats exploitables sans bloquer le cluster.

### Enforce
Mode recommande seulement si :
- les images SecureRAG sont reellement signees et verifiees ;
- la cle publique Cosign correspond bien aux signatures publiees ;
- la registry est joignable par le cluster et/ou le moteur Kyverno ;
- les images non signees ne sont plus deployees sur le namespace cible.
- `artifacts/validation/kyverno-runtime-report.md` indique que les PolicyReports existent et ne contiennent pas de `fail` ou `error` ;
- `artifacts/release/release-attestation.json` est en statut `COMPLETE_PROVEN`.

Verification readiness Enforce :
```bash
make kyverno-runtime-proof
grep -n "Kyverno Enforce readiness" artifacts/validation/kyverno-runtime-report.md
```

Ne pas lancer `make kyverno-enforce` si cette ligne ne retourne pas `TERMINÉ`.

Preuve d'admission positive/negative :

```bash
APPLY_ENFORCE=true REGISTRY_CLUSTER_HOST=securerag-registry:5000 make kyverno-enforce-proof
```

Artefacts :

- `artifacts/validation/kyverno-enforce-proof.md`
- `artifacts/validation/kyverno-admission-positive-test.md`
- `artifacts/validation/kyverno-admission-negative-test.md`
- `artifacts/validation/kyverno-enforce-rollback.md`

### Cas particulier de la registry locale kind

Si un ancien environnement utilise encore `localhost:5001/...`, la verification
Cosign `verifyImages` en `Enforce` doit rester bloquee : depuis un pod Kyverno,
`localhost` pointe vers le pod lui-meme et non vers la registry de l'hote. Le
perimetre officiel corrige cela avec `securerag-registry:5000/...@sha256`.

- ne pas reintroduire `localhost:5001` ou `127.0.0.1:5002` dans les manifests Kubernetes officiels ;
- garder Cosign verify cote hote comme gate release bloquant ;
- archiver la preuve d'admission ou le rollback dans `artifacts/validation/`.

## Risque si Enforce est active trop tot
- refus de creation des Pods SecureRAG ;
- echec de deploiement si la signature est absente ou invalide ;
- confusion si l'environnement local utilise encore des tags non signes.

## Recommandation
- commencer en `Audit`
- valider la campagne `verify -> promote -> deploy -> validate`
- passer ensuite a `Enforce` sur un cluster de demonstration stabilise
- conserver `artifacts/validation/cluster-security-addons.md` et `artifacts/validation/kyverno-runtime-report.md` comme preuves runtime
