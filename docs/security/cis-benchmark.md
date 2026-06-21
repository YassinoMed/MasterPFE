# CIS Kubernetes Benchmark — SecureRAG Hub

## Présentation

Le **CIS (Center for Internet Security) Kubernetes Benchmark** est un ensemble de recommandations de sécurité pour la configuration sécurisée des clusters Kubernetes. SecureRAG Hub exécute ce benchmark automatiquement et génère des rapports de conformité.

## Exécution

### Manuellement
```bash
# Exécution complète (benchmark + rapport)
bash scripts/security/run-cis-benchmark.sh

# Parser un résultat existant
bash scripts/security/cis-report-parser.sh \
  artifacts/security/kube-bench.json \
  artifacts/security/cis-report.md
```

### Automatiquement (CronJob)
Le CronJob `cis-benchmark` s'exécute chaque lundi à 6h UTC :
```bash
kubectl apply -f infra/k8s/jobs/cis-benchmark-cronjob.yaml
```

### Résultats
Les rapports sont stockés dans `artifacts/security/` :
- `kube-bench.json` — Résultats bruts JSON
- `cis-report.md` — Rapport formaté avec scores et remédiations

## Catégories du Benchmark

| Contrôle | Catégorie | Checks |
|----------|-----------|--------|
| 1 | Master Node Security | Fichiers de configuration, API Server, Controller Manager, Scheduler |
| 2 | etcd | Configuration du datastore, TLS, authentification |
| 3 | Control Plane | Configuration générale du plan de contrôle |
| 4 | Worker Nodes | Configuration des kubelets, fichiers de nœud |
| 5 | Policies | RBAC, Pod Security, Network Policies, Secrets |

## Remédiation des Échecs Courants

### 1.x — API Server
**Problème :** Anonymous auth activé, encryption désactivée
```yaml
# API Server flags sécurisés
--anonymous-auth=false
--enable-admission-plugins=NodeRestriction,PodSecurity
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
--profiling=false
```

### 2.x — etcd
**Problème :** etcd sans TLS ou sans authentification
```yaml
# etcd flags sécurisés
--client-cert-auth=true
--peer-client-cert-auth=true
--auto-tls=false
--peer-auto-tls=false
--cert-file=/etc/kubernetes/pki/etcd/server.crt
--key-file=/etc/kubernetes/pki/etcd/server.key
--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

### 4.x — Kubelet
**Problème :** Port non sécurisé ouvert, anonymous auth
```yaml
# Kubelet flags sécurisés
--read-only-port=0
--anonymous-auth=false
--protect-kernel-defaults=true
--make-iptables-util-chains=true
--event-qps=5
--streaming-connection-idle-timeout=5m
--rotate-certificates=true
```

### 5.x — RBAC & Pod Security
**Problème :** Permissions trop larges, PSS non appliqué
```bash
# Appliquer Pod Security Standards
kubectl label ns --all pod-security.kubernetes.io/enforce=restricted

# Vérifier les permissions
kubectl describe clusterrolebindings
kubectl describe clusterroles
```

## Intégration CI/CD

Le benchmark peut être intégré dans Jenkins ou GitHub Actions :

```yaml
# .github/workflows/cis-benchmark.yml
- name: Run CIS Benchmark
  run: |
    bash scripts/security/run-cis-benchmark.sh

- name: Archive Report
  uses: actions/upload-artifact@v4
  with:
    name: cis-report
    path: artifacts/security/cis-report.md
```

Le script `run-cis-benchmark.sh` exit avec `exit code 1` si des échecs critiques sont détectés, permettant de bloquer le pipeline.

## Métriques de Conformité

La cible SecureRAG Hub est **≥90% de conformité** au CIS Benchmark, avec zéro échec critique sur les contrôles scorés.
