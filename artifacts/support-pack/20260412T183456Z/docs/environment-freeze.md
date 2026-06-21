# Environment Freeze — SecureRAG Hub

## Objectif
Definir un environnement de reference pour rejouer la demonstration DevSecOps avec le moins de variance possible.

## Matrice de reference

| Composant | Role | Reference recommandee | Commande de verification | Observation locale actuelle |
|---|---|---|---|---|
| Docker | Build, registry, Jenkins, kind | version recente stable Desktop / Engine | `docker --version` | `Docker version 29.3.1` |
| kind | Cluster local | version compatible Kubernetes 1.35 | `kind --version` | non detecte dans ce shell, requis pour les campagnes locales |
| kubectl | Pilotage cluster | `v1.34.x` | `kubectl version --client --output=yaml` | `v1.34.1` |
| Kustomize | Rendu overlays | integre a `kubectl`, `v5.7.x` | `kubectl version --client --output=yaml` | `v5.7.1` |
| Cosign | Signature / verification | version recente stable | `cosign version` | depend de l'installation locale |
| Syft | Generation SBOM | version recente stable | `syft version` | depend de l'installation locale |
| Trivy | Scan filesystem / image | version recente stable | `trivy --version` | depend de l'installation locale |
| Semgrep | SAST | version recente stable | `semgrep --version` | `1.156.0` observe dans ce shell |
| Kyverno | Admission policies | image / manifest du repo `v1.16.2` | `kubectl get pods -n kyverno` | actif si installe via addon |
| metrics-server | HPA metrics | manifest du repo `v0.8.0` | `kubectl top nodes` | actif si installe via addon |

## Regle pratique

- Pour une soutenance, ne pas changer plusieurs versions a la fois.
- Geler les versions sur la machine de demonstration au moins 24 heures avant la presentation.
- Rejouer une campagne `dry-run` puis une campagne `execute` sur ce meme environnement.

## Verification minimale avant campagne

```bash
docker --version
kubectl version --client --output=yaml
semgrep --version
kind --version
cosign version
syft version
trivy --version
```

## Addons de cluster

### Kyverno
```bash
bash scripts/deploy/install-kyverno.sh
kubectl get clusterpolicy
```

### metrics-server
```bash
bash scripts/deploy/install-metrics-server.sh
kubectl top nodes
kubectl top pods -n securerag-hub
```

## Position recommande

- **Scenario officiel soutenance** : `demo`
- **Scenario technique complementaire** : `real` uniquement si `Ollama` a deja ete precharge et stabilise
