# Metrics Server Runbook — SecureRAG Hub

## Objectif
Installer `metrics-server` sur le cluster local afin de rendre les `HorizontalPodAutoscaler` observables et exploitables.

## Prerequis
- cluster Kubernetes joignable via `kubectl`
- acces reseau pour recuperer le manifeste officiel `metrics-server`
- `kubectl` avec support Kustomize

## Fichiers utilises
- `infra/k8s/addons/metrics-server/kustomization.yaml`
- `scripts/deploy/install-metrics-server.sh`
- `scripts/validate/validate-hpa-runtime.sh`
- `scripts/validate/refresh-hpa-runtime-proof.sh`

## Particularites du mode local
Le manifeste est complete par deux arguments utiles en contexte `kind` :
- `--kubelet-insecure-tls`
- `--kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS`
- `--metric-resolution=15s`

Le premier est acceptable pour une demonstration locale uniquement. Il ne doit pas etre conserve tel quel pour une cible plus mature.

Le Deployment est aussi borne par des `resources` CPU/memoire/ephemeral-storage et un `securityContext` restreint afin d'eviter un addon plus permissif que les workloads applicatifs.

## Installation
```bash
bash scripts/deploy/install-metrics-server.sh
```

Le script rend le manifeste avec Kustomize, execute un dry-run server-side, applique l'addon, attend le deployment, attend l'APIService `v1beta1.metrics.k8s.io`, puis attend `kubectl top nodes` et `kubectl top pods`.

Pour une preuve complete avec rapport strict :

```bash
make refresh-hpa-runtime-proof
```

## Verification
```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -n securerag-hub
kubectl get hpa -n securerag-hub
bash scripts/validate/validate-hpa-runtime.sh
bash scripts/validate/validate-cluster-security-addons.sh
```

## Resultat attendu
- `kubectl top nodes` repond
- `kubectl top pods -n securerag-hub` repond
- les `HPA` ne restent plus avec `cpu: <unknown>`
- `artifacts/validation/hpa-runtime-report.md` classe les HPA en `TERMINÉ`
- `artifacts/validation/cluster-security-addons.md` classe metrics-server/HPA en `TERMINÉ`

## Limites
- `metrics-server` sert a l'autoscaling CPU/memoire, pas a une supervision complete
- sans `metrics-server`, les objets HPA existent mais restent peu informatifs
- sur une cible plus mature, remplacer `--kubelet-insecure-tls` par une configuration TLS propre
- si l'API Kubernetes est indisponible, les rapports doivent rester `DÉPENDANT_DE_L_ENVIRONNEMENT`
