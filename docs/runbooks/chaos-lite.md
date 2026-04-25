# Chaos Lite Runbook - SecureRAG Hub

## Objectif

Prouver le self-healing Kubernetes sans rendre la démo instable.

## Preuve read-only

```bash
make chaos-lite-proof
```

Cette commande vérifie l'API Kubernetes, les Deployments, PDB, HPA, pods et events sans mutation.

## Tests mutatifs contrôlés

```bash
RUN_POD_DELETE=true CONFIRM_CHAOS_LITE=YES make chaos-lite-proof
RUN_ROLLOUT_RESTART=true CONFIRM_CHAOS_LITE=YES make chaos-lite-proof
RUN_NODE_DRAIN=true CONFIRM_CHAOS_LITE=YES CONFIRM_NODE_DRAIN=YES NODE_NAME='<worker>' make chaos-lite-proof
```

## Artefact

```text
artifacts/validation/chaos-lite-proof.md
```

## Sécurité

Toutes les actions qui modifient le cluster sont opt-in. Le drain de noeud nécessite en plus `NODE_NAME` et `CONFIRM_NODE_DRAIN=YES`.
