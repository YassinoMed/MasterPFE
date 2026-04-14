# Kubernetes Integration Status — Laravel Business Services

## Objectif
Clarifier l’état réel d’intégration Kubernetes des services Laravel métier afin d’éviter toute surdéclaration dans les preuves sécurité et la soutenance.

## État réel
Le déploiement Kubernetes `demo` officiel expose les workloads de démonstration nécessaires à la soutenance DevSecOps :

- `api-gateway`
- `auth-users`
- `chatbot-manager`
- `knowledge-hub`
- `llm-orchestrator`
- `security-auditor`
- `portal-web`
- `qdrant`
- `ollama`

Les microservices Laravel métier existent dans le dépôt et disposent de tests, APIs et contrats, mais ils ne doivent être déclarés comme workloads Kubernetes runtime que lorsqu’un manifest explicite est ajouté et validé dans `infra/k8s`.

## Lecture sécurité
- Les contrôles Kubernetes runtime actuels protègent le socle `demo` officiel.
- Les contrôles applicatifs Laravel sont validés par tests locaux et par configuration des microservices.
- L’intégration Kubernetes des microservices Laravel doit être traitée comme une extension contrôlée, avec manifests, NetworkPolicies, probes, secrets et preuves runtime dédiées.

## Preuves à fournir avant déclaration runtime
Avant de déclarer `conversation-service` ou `audit-security-service` comme déployés officiellement dans Kubernetes, il faut archiver :

```bash
kubectl kustomize infra/k8s/overlays/demo
kubectl get deploy,svc,networkpolicy,pdb,hpa -n securerag-hub
kubectl get pods -n securerag-hub
kubectl logs -n securerag-hub deploy/<service-name> --tail=80
```

## Formulation recommandée
La formulation défendable est :

> Le mode `demo` Kubernetes est stable et validé sur les workloads officiels. Les microservices Laravel métier sont prêts côté code/API/tests et peuvent être intégrés au cluster via une phase d’industrialisation Kubernetes dédiée.
