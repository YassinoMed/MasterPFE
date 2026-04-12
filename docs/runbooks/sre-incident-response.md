# SRE Incident Response Runbook - SecureRAG Hub

## Objectif

Ajouter une couche SRE simple et défendable pour la soutenance : SLO, incident response, modes dégradés et preuves de récupération.

## SLO minimaux proposés

- API Gateway health disponible pendant la démo : 99%.
- Portal Web health disponible pendant la démo : 99%.
- Tous les pods applicatifs demo `Running` avant soutenance.
- Jenkins accessible pendant la phase CI/CD de démonstration.

## Error budget pédagogique

Pour une fenêtre de démo de 60 minutes :

- indisponibilité tolérée API Gateway : environ 36 secondes pour un SLO 99%;
- indisponibilité tolérée Portal Web : environ 36 secondes pour un SLO 99%;
- au-delà, basculer vers preuves archivées et support pack.

## Scénario incident 1 : Jenkins inaccessible

Diagnostic :

```bash
curl -I http://localhost:8085/login
docker ps | grep securerag-jenkins
docker logs securerag-jenkins --tail=100
```

Fallback :

- utiliser `/workspace` ;
- montrer le dernier support pack ;
- exécuter les scripts non destructifs localement.

## Scénario incident 2 : cluster kind indisponible

Diagnostic :

```bash
kubectl config current-context
kubectl get nodes
kubectl get pods -n securerag-hub
```

Fallback :

- montrer `artifacts/final/final-validation-summary.md` ;
- montrer `artifacts/support-pack/*.tar.gz` ;
- relancer le bootstrap uniquement si le temps de soutenance le permet.

## Scénario incident 3 : metrics-server ou HPA non prêts

Diagnostic :

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl get hpa -n securerag-hub
```

Fallback :

- expliquer que HPA est manifesté mais dépend de metrics-server ;
- conserver la preuve `cluster-security-addons.md`.

## Preuves à archiver

```bash
make observability-snapshot
make devsecops-final-proof
make final-summary support-pack
```

## Règle soutenance

Ne jamais masquer un incident. Le présenter comme une situation d'exploitation, puis montrer le diagnostic, le fallback et les preuves.
