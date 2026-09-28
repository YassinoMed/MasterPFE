# FinOps Cost Allocation — SecureRAG Hub

**Date**: 2026-09-27T21:13:24Z
**Infrastructure**: 2 × t3.2xlarge (AWS EC2, kind cluster)
**Coût total**: $267.26/mois

## Répartition des coûts par namespace

| Namespace | CPU (m) | Mémoire (Mi) | Part du CPU | Coût estimé/mois |
|---|---|---|---|---|
| namespace | cpu_milli | mem_mib | 0.0% | \$0.00 |
| falco | 970 | 548 | 53.7% | \$143.52 |
| kube-system | 301 | 3524 | 16.7% | \$44.63 |
| argocd | 117 | 1311 | 6.5% | \$17.37 |
| monitoring | 61 | 1509 | 3.4% | \$9.09 |
| securerag-prod | 47 | 1594 | 2.6% | \$6.95 |
| securerag-monitoring | 36 | 972 | 2.0% | \$5.35 |
| securerag-hub | 31 | 1292 | 1.7% | \$4.54 |
| vault | 28 | 111 | 1.6% | \$4.28 |
| securerag-hub-dr | 26 | 518 | 1.4% | \$3.74 |
| securerag-staging | 24 | 581 | 1.3% | \$3.47 |
| securerag-recette | 24 | 518 | 1.3% | \$3.47 |
| securerag-dev | 24 | 522 | 1.3% | \$3.47 |
| securerag-preprod | 21 | 582 | 1.2% | \$3.21 |
| securerag-test | 19 | 359 | 1.1% | \$2.94 |
| harbor | 18 | 216 | 1.0% | \$2.67 |
| kyverno | 16 | 284 | 0.9% | \$2.41 |
| velero | 7 | 116 | 0.4% | \$1.07 |
| chaos-testing | 8 | 199 | 0.4% | \$1.07 |
| spire-system | 5 | 67 | 0.3% | \$0.80 |
| trivy-system | 3 | 359 | 0.2% | \$0.53 |
| tempo | 3 | 56 | 0.2% | \$0.53 |
| loki | 3 | 50 | 0.2% | \$0.53 |
| external-secrets | 4 | 188 | 0.2% | \$0.53 |
| cert-manager | 3 | 142 | 0.2% | \$0.53 |
| otel-system | 2 | 63 | 0.1% | \$0.27 |
| local-path-storage | 1 | 19 | 0.1% | \$0.27 |
| jenkins | 2 | 594 | 0.1% | \$0.27 |
| ingress-nginx | 2 | 206 | 0.1% | \$0.27 |

## Top 5 consommateurs

1. namespace — 0.0% du CPU (\$0.00/mois)
2. falco — 53.7% du CPU (\$143.52/mois)
3. kube-system — 16.7% du CPU (\$44.63/mois)
4. argocd — 6.5% du CPU (\$17.37/mois)
5. monitoring — 3.4% du CPU (\$9.09/mois)

## Méthodologie

- Source: `kubectl top pods -A` (métriques réelles, pas d'estimation)
- Tarifs: AWS EC2 on-demand t3.2xlarge = $0.3712/h
- Allocation: proportionnelle à l'utilisation CPU
- Outil: ce script (reproductible: `bash scripts/finops/cost-allocation.sh`)

---
*Généré par scripts/finops/cost-allocation.sh*
