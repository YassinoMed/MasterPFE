# Observability Modernization Runbook - SecureRAG Hub

## Objectif

Améliorer la lisibilité opérationnelle de SecureRAG Hub sans alourdir le scénario officiel `demo`.

## Niveau actuel

Le projet dispose déjà de preuves runtime, de health checks, de HPA manifests, de PDB, de NetworkPolicies et de scripts de validation. Le niveau actuel est suffisant pour une soutenance DevSecOps, mais il reste léger côté observabilité continue.

## Cible réaliste

La cible recommandée est progressive :

- niveau 1 : snapshot runtime avec `kubectl`, events, HPA, metrics-server et Kyverno reports ;
- niveau 2 : metrics-server stable, HPA observables et logs applicatifs collectables ;
- niveau 3 : Prometheus, Grafana et Loki si la machine de démo dispose des ressources nécessaires.

## Commandes

Snapshot non destructif :

```bash
make observability-snapshot
```

Installation metrics-server :

```bash
make metrics-install
make cluster-security-proof
```

## Résultats attendus

- `artifacts/observability/observability-snapshot.md`
- `artifacts/validation/cluster-security-addons.md`
- HPA avec métriques non `unknown`
- `kubectl top nodes` et `kubectl top pods` fonctionnels

## Diagnostic

Si `kubectl top` échoue :

- vérifier que metrics-server est installé ;
- vérifier les arguments TLS adaptés à kind ;
- attendre 30 à 90 secondes après l'installation ;
- relancer `kubectl get apiservice v1beta1.metrics.k8s.io`.

Si les HPA restent en `unknown` :

- vérifier que les pods ont des requests CPU/memory ;
- vérifier l'état du metrics-server ;
- vérifier que les HPA ciblent les bons Deployments.

## Extension optionnelle

Prometheus/Grafana/Loki apportent une vraie valeur si la soutenance inclut une démonstration d'observabilité continue. Leur coût d'intégration est plus élevé : ressources supplémentaires, dashboards, stockage et temps de stabilisation. Pour le scénario officiel `demo`, ils doivent rester optionnels.
