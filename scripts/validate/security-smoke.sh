#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"

echo "Checking deployment security context..."
kubectl get deploy -n "${NS}" -o custom-columns='NAME:.metadata.name,SA:.spec.template.spec.serviceAccountName,RUN_AS_NON_ROOT:.spec.template.spec.securityContext.runAsNonRoot,READ_ONLY_FS:.spec.template.spec.containers[*].securityContext.readOnlyRootFilesystem,NO_PRIV_ESC:.spec.template.spec.containers[*].securityContext.allowPrivilegeEscalation'

echo "Checking network policies..."
kubectl get networkpolicy -n "${NS}"

echo "Checking service accounts..."
kubectl get sa -n "${NS}"
