# Argo CD bootstrap pour SecureRAG Hub

## Installation

```bash
# 1. Installer Argo CD (officiel, version stable)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.7/manifests/install.yaml

# 2. Attendre que Argo CD soit prêt
kubectl rollout status deploy/argocd-server -n argocd --timeout=300s

# 3. Appliquer les Applications SecureRAG
kubectl apply -k infra/k8s/argocd

# 4. Récupérer le mot de passe initial admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Drift detection

```bash
# Lister les Applications
kubectl get applications -n argocd

# État de sync
kubectl get applications -n argocd -o wide

# Forcer un refresh
kubectl annotate application securerag-demo -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

## Audit & rollback

Argo CD conserve `revisionHistoryLimit` revisions par Application :
- `securerag-demo` : 10 dernières
- `securerag-production` : 20 dernières

```bash
argocd app history securerag-production
argocd app rollback securerag-production <REVISION>
```

## Statut

- `PRÊT_NON_EXÉCUTÉ` : manifests présents et validés `kustomize build`.
- `TERMINÉ` après installation Argo CD + premier sync réussi avec preuve
  archivée sous `artifacts/gitops/argocd-sync-proof.md`.
