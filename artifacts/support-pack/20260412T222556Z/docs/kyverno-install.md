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
- `infra/k8s/policies/kyverno/overlays/enforce/kustomization.yaml`
- `scripts/deploy/install-kyverno.sh`

## Installation en mode Audit
```bash
bash scripts/deploy/install-kyverno.sh
```

Cela :
- installe Kyverno dans le namespace `kyverno`
- attend les deployments Kyverno
- verifie la presence du CRD `clusterpolicies.kyverno.io`
- applique les policies SecureRAG en mode `Audit`

## Installation avec policies Enforce
```bash
KYVERNO_POLICY_MODE=enforce bash scripts/deploy/install-kyverno.sh
```

Cette variante bascule uniquement la policy de verification Cosign en `Enforce`.

## Verification post-install
```bash
kubectl get pods -n kyverno
kubectl get crd clusterpolicies.kyverno.io
kubectl get clusterpolicy
```

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

## Risque si Enforce est active trop tot
- refus de creation des Pods SecureRAG ;
- echec de deploiement si la signature est absente ou invalide ;
- confusion si l'environnement local utilise encore des tags non signes.

## Recommandation
- commencer en `Audit`
- valider la campagne `verify -> promote -> deploy -> validate`
- passer ensuite a `Enforce` sur un cluster de demonstration stabilise
