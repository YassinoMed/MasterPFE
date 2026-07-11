#!/usr/bin/env bash
POD=$(kubectl get pods -n securerag-hub -l app.kubernetes.io/name=auth-users -o jsonpath='{.items[0].metadata.name}')

for i in $(seq 1 10); do
  T_ACTION=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
  kubectl exec "$POD" -n securerag-hub -- /bin/sh -c "id" > /dev/null 2>&1
  echo "Répétition $i — action à $T_ACTION" >> mttd_log.txt
  sleep 5
done
