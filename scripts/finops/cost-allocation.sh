#!/bin/bash
# cost-allocation.sh — Mesure les coûts Kubernetes par namespace (FinOps)
# Phase 13 : Utilise kubectl top (données réelles) + tarifs AWS on-demand.
set -euo pipefail

# Tarifs AWS EC2 on-demand us-east-1 (approximatifs, 2026)
# kind tourne sur 1 instance EC2 — le coût total est divisé par l'utilisation
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.2xlarge}"
PRICE_PER_HOUR=0.3712  # t3.2xlarge on-demand
NODES=2

EVIDENCE_DIR="evidence/$(date +%Y-%m-%d)"
mkdir -p "$EVIDENCE_DIR"
REPORT="$EVIDENCE_DIR/finops-cost-allocation.md"

echo "[FINOPS] Mesure des coûts réels depuis kubectl top..."

# ── Coût total du nœud ────────────────────────────────────────────
TOTAL_MONTHLY=$(python3 -c "print(f'{$PRICE_PER_HOUR * 24 * 30:.2f}')")
echo "[FINOPS] Coût infrastructure: \$$TOTAL_MONTHLY/mois ($INSTANCE_TYPE × $NODES nœud(s))"

# ── Utilisation par namespace ─────────────────────────────────────
echo -e "\nnamespace\tcpu_milli\tmem_mib\tshare_pct" > /tmp/finops-data.txt

kubectl top pods -A --no-headers 2>/dev/null | while read ns name cpu mem rest; do
  cpu_m=$(echo "$cpu" | tr -d 'm')
  mem_m=$(echo "$mem" | tr -d 'Mi')
  echo -e "$ns\t$cpu_m\t${mem_m:-0}\t0"
done | awk -F'\t' '
{
  ns[$1] += $2; ns_mem[$1] += $3; total += $2
} END {
  for (n in ns) {
    pct = (ns[n]/total*100)
    printf "%s\t%d\t%d\t%.1f\n", n, ns[n], ns_mem[n], pct
  }
}' | sort -t$'\t' -k4 -rn >> /tmp/finops-data.txt

# ── Génération du rapport ─────────────────────────────────────────
cat > "$REPORT" << REPORT_EOF
# FinOps Cost Allocation — SecureRAG Hub

**Date**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Infrastructure**: $NODES × $INSTANCE_TYPE (AWS EC2, kind cluster)
**Coût total**: \$$TOTAL_MONTHLY/mois

## Répartition des coûts par namespace

| Namespace | CPU (m) | Mémoire (Mi) | Part du CPU | Coût estimé/mois |
|---|---|---|---|---|
$(awk -F'\t' 'NR>1 {
  cost = $4/100 * '"$TOTAL_MONTHLY"'
  printf "| %s | %s | %s | %.1f%% | \\$%.2f |\n", $1, $2, $3, $4, cost
}' /tmp/finops-data.txt)

## Top 5 consommateurs

$(awk -F'\t' 'NR>1 && NR<=6 {
  printf "%d. %s — %.1f%% du CPU (\\$%.2f/mois)\n", NR-1, $1, $4, $4/100*'"$TOTAL_MONTHLY"'
}' /tmp/finops-data.txt)

## Méthodologie

- Source: \`kubectl top pods -A\` (métriques réelles, pas d'estimation)
- Tarifs: AWS EC2 on-demand $INSTANCE_TYPE = \$$PRICE_PER_HOUR/h
- Allocation: proportionnelle à l'utilisation CPU
- Outil: ce script (reproductible: \`bash scripts/finops/cost-allocation.sh\`)

---
*Généré par scripts/finops/cost-allocation.sh*
REPORT_EOF

echo "[FINOPS] Rapport: $REPORT"
echo ""
echo "=== RÉSUMÉ ==="
awk -F'\t' 'NR>1 && NR<=6 {
  printf "  %d. %-24s %5.1f%% (≈\$%.2f/mois)\n", NR-1, $1, $4, $4/100*'"$TOTAL_MONTHLY"'
}' /tmp/finops-data.txt

