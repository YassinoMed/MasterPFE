# Demo Checklist — SecureRAG Hub

## Objectif
Fournir une checklist `go / no-go` simple avant une demonstration ou une soutenance.

## Scenario officiel recommande
Le scenario officiel recommande pour la soutenance est :

- **mode** : `demo`
- **overlay** : `infra/k8s/overlays/demo`
- **validation image** : `python:3.12-slim`
- **promotion strategy** : `digest`

Le mode reel avec `Ollama` ne doit etre utilise que si l'image a deja ete prechargee et si la machine dispose de ressources suffisantes.

## Checklist go / no-go

### Preflight machine
- [ ] Docker Desktop est demarre et `docker info` repond.
- [ ] Le shell actif utilise le bon environnement Python local si des tests Python sont lances.
- [ ] Les binaires `kubectl`, `kind`, `cosign`, `syft`, `trivy` et `semgrep` sont disponibles si la campagne complete est visee.

### Cluster et registre
- [ ] `kind get clusters` contient `securerag-dev`.
- [ ] `kubectl config current-context` pointe vers `kind-securerag-dev`.
- [ ] Le registre local `localhost:5001` repond.
- [ ] Les secrets du namespace `securerag-hub` existent.

### Security add-ons
- [ ] `kubectl get clusterpolicy` repond si Kyverno est attendu.
- [ ] `kubectl top pods -n securerag-hub` repond si `metrics-server` est attendu.
- [ ] Les policies Kyverno sont en `Audit` pour la demo standard.

### Release inputs
- [ ] Les images sources existent dans le registre local.
- [ ] Les signatures Cosign sont presentes si `verify/promote/deploy` doivent etre executes.
- [ ] `COSIGN_PUBLIC_KEY` pointe vers une cle valide.

### Scenario de soutenance
- [ ] Le scenario choisi est annonce explicitement : `demo` ou `real`.
- [ ] Si `real`, l'image `Ollama` a ete prechargee.
- [ ] Si `demo`, il est annonce que le moteur LLM local est remplace par un mock HTTP stable.

## Commandes de verification rapide

```bash
docker info
kubectl config current-context
kubectl get pods -n securerag-hub
kubectl get hpa -n securerag-hub
kubectl get clusterpolicy
```

## Go
Si toutes les verifications precedentes sont valides, lancer :

```bash
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=dry-run bash scripts/cd/run-final-campaign.sh
```

Puis, si les artefacts sont corrects et les prerequis verifies :

```bash
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=execute bash scripts/cd/run-final-campaign.sh
```

## No-go
Ne pas lancer une campagne `execute` si l'un des points suivants est observe :

- `docker info` echoue ;
- le registre local ne repond pas ;
- `COSIGN_PUBLIC_KEY` est absent alors qu'une verification est attendue ;
- le cluster n'est pas joignable ;
- le mode reel `Ollama` est selectionne sans prechargement prealable.
