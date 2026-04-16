#!/usr/bin/env bash

validation_pod_service_account() {
  printf '%s' "${VALIDATION_SERVICE_ACCOUNT:-sa-validation}"
}

validation_pod_overrides() {
  local container_name="${1:?container name is required}"
  local service_account

  service_account="$(validation_pod_service_account)"

  cat <<JSON
{
  "apiVersion": "v1",
  "spec": {
    "serviceAccountName": "${service_account}",
    "automountServiceAccountToken": false,
    "securityContext": {
      "runAsNonRoot": true,
      "runAsUser": 10001,
      "runAsGroup": 10001,
      "seccompProfile": {
        "type": "RuntimeDefault"
      }
    },
    "containers": [
      {
        "name": "${container_name}",
        "securityContext": {
          "allowPrivilegeEscalation": false,
          "readOnlyRootFilesystem": true,
          "capabilities": {
            "drop": ["ALL"]
          }
        },
        "resources": {
          "requests": {
            "cpu": "10m",
            "memory": "32Mi",
            "ephemeral-storage": "16Mi"
          },
          "limits": {
            "cpu": "100m",
            "memory": "128Mi",
            "ephemeral-storage": "64Mi"
          }
        },
        "volumeMounts": [
          {
            "name": "tmp",
            "mountPath": "/tmp"
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "tmp",
        "emptyDir": {
          "medium": "Memory",
          "sizeLimit": "64Mi"
        }
      }
    ]
  }
}
JSON
}
