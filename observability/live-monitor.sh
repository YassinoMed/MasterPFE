#!/bin/bash
# Monitoring temps réel — SecurRag Hub k6 + resources
# Usage : ./observability/live-monitor.sh [duree_secondes]
DURATION=${1:-90}
MONITOR_FILE=/tmp/opencode/k6-live-monitor.txt

echo "═══════════════════════════════════════════════════════════════════"
echo "⏱  LIVE MONITORING — k6 load + CPU/RAM (toutes les 2s)"
echo "   Durée: ${DURATION}s | Fichier: $MONITOR_FILE"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

echo "TIMESTAMP,POD,CPU(m),RAM(Mi)" > "$MONITOR_FILE"
echo "  ▪ Enregistrement : $MONITOR_FILE"

# Vérifier si k6 tourne
K6_TEST=
if ! kill -0 $(cat /tmp/opencode/k6.pid 2>/dev/null) 2>/dev/null; then
  echo "  ⚠  Le test k6 n'est pas en cours."
  echo "     Démarrez-le d'abord avec : ./scripts/performance/k6-heavy.sh"
  echo ""
else
  echo "  ▪ Test k6 détecté (PID: $(cat /tmp/opencode/k6.pid))"
fi

echo ""

printf "  %-6s | %-38s | %8s | %8s\n" "HEURE" "POD" "CPU(m)" "RAM(Mi)"
printf "  %s\n" "────────────────────────────────────────────────────────────────────"

for sec in $(seq 1 $DURATION); do
  T=$(date '+%H:%M:%S').$(date '+%N' | cut -c1-3)
  
  kubectl top pod -n securerag-hub 2>/dev/null | \
    grep -E "^ai-gateway|^ollama|^qdrant|^secai" | \
    while read pod cpu mem _; do
      cpu_m=$(echo "$cpu" | sed 's/[^0-9]//g')
      ram_m=$( echo "$mem" | sed 's/[^0-9]//g')
      printf "  %-6s | %-38s | %8s | %8s\n" "$T" "$pod" "$cpu" "$mem"
      echo "$T,$pod,$cpu_m,$ram_m" >> "$MONITOR_FILE"
    done

  # Ligne vide tous les 10 monitoring ticks
  if [ $((sec % 5)) -eq 0 ]; then
    kubectl top node 2>/dev/null | grep securerag | \
      awk '{printf "  %-6s | Node %-30s | CPU: %6s (%s) | RAM: %8s (%s)\n", $2" ", $1, $3, $4, $5, $6}'
    echo ""
  fi

  sleep 2
done

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  Done. $(wc -l < $MONITOR_FILE) lignes dans \"$MONITOR_FILE\""
echo "  Pour visualiser : awk -F, '{print $1,$2,$4}' $MONITOR_FILE"
