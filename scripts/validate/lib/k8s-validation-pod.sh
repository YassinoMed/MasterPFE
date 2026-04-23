#!/usr/bin/env bash

validation_pod_service_account() {
  printf '%s' "${VALIDATION_SERVICE_ACCOUNT:-sa-validation}"
}

validation_pod_request_cpu() {
  printf '%s' "${VALIDATION_REQUEST_CPU:-50m}"
}

validation_pod_request_memory() {
  printf '%s' "${VALIDATION_REQUEST_MEMORY:-64Mi}"
}

validation_pod_request_ephemeral_storage() {
  printf '%s' "${VALIDATION_REQUEST_EPHEMERAL_STORAGE:-64Mi}"
}

validation_pod_limit_cpu() {
  printf '%s' "${VALIDATION_LIMIT_CPU:-100m}"
}

validation_pod_limit_memory() {
  printf '%s' "${VALIDATION_LIMIT_MEMORY:-128Mi}"
}

validation_pod_limit_ephemeral_storage() {
  printf '%s' "${VALIDATION_LIMIT_EPHEMERAL_STORAGE:-64Mi}"
}

validation_pod_tmp_size_limit() {
  printf '%s' "${VALIDATION_TMP_SIZE_LIMIT:-64Mi}"
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
            "cpu": "$(validation_pod_request_cpu)",
            "memory": "$(validation_pod_request_memory)",
            "ephemeral-storage": "$(validation_pod_request_ephemeral_storage)"
          },
          "limits": {
            "cpu": "$(validation_pod_limit_cpu)",
            "memory": "$(validation_pod_limit_memory)",
            "ephemeral-storage": "$(validation_pod_limit_ephemeral_storage)"
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
          "sizeLimit": "$(validation_pod_tmp_size_limit)"
        }
      }
    ]
  }
}
JSON
}
