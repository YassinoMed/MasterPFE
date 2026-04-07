#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
AUDITOR_URL="${AUDITOR_URL:-http://security-auditor:8080/healthz}"
VALIDATION_IMAGE="${VALIDATION_IMAGE:-localhost:5001/securerag-hub-api-gateway:dev}"
pod_name="adversarial-check-$(date +%s)"

echo "Basic adversarial validation bootstrap"
kubectl run "${pod_name}" --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --command -- python -c "
import urllib.request
with urllib.request.urlopen('${AUDITOR_URL}', timeout=5) as response:
    if response.status != 200:
        raise SystemExit(response.status)
print('Security-Auditor basic availability OK')
"
