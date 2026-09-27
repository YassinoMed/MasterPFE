# FinOps Cost Allocation — SecureRAG Hub

**Date**: 2026-09-27T08:47:16Z
**Infrastructure**: 2 × t3.2xlarge (AWS EC2, kind cluster)
**Coût total**: $267.26/mois

## Répartition des coûts par namespace

| Namespace | CPU (m) | Mémoire (Mi) | Part du CPU | Coût estimé/mois |
|---|---|---|---|---|
| namespace | cpu_milli | mem_mib | 0.0% | \$0.00 |
| kube-system | 164 | 2508 | 25.2% | \$67.35 |
| falco | 94 | 538 | 14.5% | \$38.75 |
| securerag-prod | 60 | 2122 | 9.2% | \$24.59 |
| monitoring | 51 | 1168 | 7.8% | \$20.85 |
| securerag-hub | 34 | 1289 | 5.2% | \$13.90 |
| securerag-staging | 24 | 580 | 3.7% | \$9.89 |
| vault | 23 | 98 | 3.5% | \$9.35 |
| securerag-recette | 23 | 519 | 3.5% | \$9.35 |
| securerag-preprod | 23 | 580 | 3.5% | \$9.35 |
| securerag-hub-dr | 22 | 515 | 3.4% | \$9.09 |
| securerag-monitoring | 21 | 769 | 3.2% | \$8.55 |
| securerag-dev | 21 | 522 | 3.2% | \$8.55 |
| securerag-test | 20 | 517 | 3.1% | \$8.29 |
| harbor | 16 | 218 | 2.5% | \$6.68 |
| argocd | 14 | 1189 | 2.2% | \$5.88 |
| kyverno | 11 | 273 | 1.7% | \$4.54 |
| velero | 6 | 145 | 0.9% | \$2.41 |
| loki | 4 | 49 | 0.6% | \$1.60 |
| trivy-system | 3 | 268 | 0.5% | \$1.34 |
| tempo | 3 | 56 | 0.5% | \$1.34 |
| external-secrets | 3 | 168 | 0.5% | \$1.34 |
| cert-manager | 3 | 123 | 0.5% | \$1.34 |
| otel-system | 2 | 63 | 0.3% | \$0.80 |
| jenkins | 2 | 592 | 0.3% | \$0.80 |
| ingress-nginx | 2 | 205 | 0.3% | \$0.80 |
| local-path-storage | 1 | 19 | 0.2% | \$0.53 |

## Top 5 consommateurs

1. namespace — 0.0% du CPU (\$0.00/mois)
2. kube-system — 25.2% du CPU (\$67.35/mois)
3. falco — 14.5% du CPU (\$38.75/mois)
4. securerag-prod — 9.2% du CPU (\$24.59/mois)
5. monitoring — 7.8% du CPU (\$20.85/mois)

## Méthodologie

- Source: `kubectl top pods -A` (métriques réelles, pas d'estimation)
- Tarifs: AWS EC2 on-demand t3.2xlarge = $0.3712/h
- Allocation: proportionnelle à l'utilisation CPU
- Outil: ce script (reproductible: `bash scripts/finops/cost-allocation.sh`)

---
*Généré par scripts/finops/cost-allocation.sh*
