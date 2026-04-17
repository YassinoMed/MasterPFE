# Kubernetes Ultra Hardening Validation - SecureRAG Hub

| Overlay | Control | Status | Evidence |
|---|---|---:|---|
| `demo` | Pod Security Admission enforce restricted | TERMINÉ | `namespace label enforce=restricted` |
| `demo` | Pod Security Admission audit restricted | TERMINÉ | `namespace label audit=restricted` |
| `demo` | Pod Security Admission warn restricted | TERMINÉ | `namespace label warn=restricted` |
| `demo` | ServiceAccount sa-portal-web token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | ServiceAccount sa-auth-users token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | ServiceAccount sa-chatbot-manager token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | ServiceAccount sa-conversation-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | ServiceAccount sa-audit-security-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | ServiceAccount sa-validation token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | Deployment portal-web rendered | TERMINÉ | `Deployment present` |
| `demo` | portal-web explicit non-default ServiceAccount | TERMINÉ | `sa-portal-web` |
| `demo` | portal-web token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | portal-web pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `demo` | portal-web RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `demo` | portal-web hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `demo` | portal-web hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `demo` | portal-web hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `demo` | portal-web no hostPath volume | TERMINÉ | `hostPath absent` |
| `demo` | portal-web/portal-web privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `demo` | portal-web/portal-web read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `demo` | portal-web/portal-web drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `demo` | portal-web/portal-web cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `demo` | portal-web/portal-web memory request and limit | TERMINÉ | `requests/limits memory` |
| `demo` | portal-web/portal-web ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `demo` | portal-web/portal-web readinessProbe | TERMINÉ | `readinessProbe present` |
| `demo` | portal-web/portal-web livenessProbe | TERMINÉ | `livenessProbe present` |
| `demo` | portal-web/portal-web startupProbe | TERMINÉ | `startupProbe present` |
| `demo` | portal-web/portal-web image not latest | TERMINÉ | `localhost:5001/securerag-hub-portal-web:demo` |
| `demo` | Deployment auth-users rendered | TERMINÉ | `Deployment present` |
| `demo` | auth-users explicit non-default ServiceAccount | TERMINÉ | `sa-auth-users` |
| `demo` | auth-users token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | auth-users pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `demo` | auth-users RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `demo` | auth-users hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `demo` | auth-users hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `demo` | auth-users hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `demo` | auth-users no hostPath volume | TERMINÉ | `hostPath absent` |
| `demo` | auth-users/auth-users privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `demo` | auth-users/auth-users read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `demo` | auth-users/auth-users drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `demo` | auth-users/auth-users cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `demo` | auth-users/auth-users memory request and limit | TERMINÉ | `requests/limits memory` |
| `demo` | auth-users/auth-users ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `demo` | auth-users/auth-users readinessProbe | TERMINÉ | `readinessProbe present` |
| `demo` | auth-users/auth-users livenessProbe | TERMINÉ | `livenessProbe present` |
| `demo` | auth-users/auth-users startupProbe | TERMINÉ | `startupProbe present` |
| `demo` | auth-users/auth-users image not latest | TERMINÉ | `localhost:5001/securerag-hub-auth-users:demo` |
| `demo` | Deployment chatbot-manager rendered | TERMINÉ | `Deployment present` |
| `demo` | chatbot-manager explicit non-default ServiceAccount | TERMINÉ | `sa-chatbot-manager` |
| `demo` | chatbot-manager token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | chatbot-manager pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `demo` | chatbot-manager RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `demo` | chatbot-manager hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `demo` | chatbot-manager hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `demo` | chatbot-manager hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `demo` | chatbot-manager no hostPath volume | TERMINÉ | `hostPath absent` |
| `demo` | chatbot-manager/chatbot-manager privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `demo` | chatbot-manager/chatbot-manager read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `demo` | chatbot-manager/chatbot-manager drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `demo` | chatbot-manager/chatbot-manager cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `demo` | chatbot-manager/chatbot-manager memory request and limit | TERMINÉ | `requests/limits memory` |
| `demo` | chatbot-manager/chatbot-manager ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `demo` | chatbot-manager/chatbot-manager readinessProbe | TERMINÉ | `readinessProbe present` |
| `demo` | chatbot-manager/chatbot-manager livenessProbe | TERMINÉ | `livenessProbe present` |
| `demo` | chatbot-manager/chatbot-manager startupProbe | TERMINÉ | `startupProbe present` |
| `demo` | chatbot-manager/chatbot-manager image not latest | TERMINÉ | `localhost:5001/securerag-hub-chatbot-manager:demo` |
| `demo` | Deployment conversation-service rendered | TERMINÉ | `Deployment present` |
| `demo` | conversation-service explicit non-default ServiceAccount | TERMINÉ | `sa-conversation-service` |
| `demo` | conversation-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | conversation-service pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `demo` | conversation-service RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `demo` | conversation-service hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `demo` | conversation-service hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `demo` | conversation-service hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `demo` | conversation-service no hostPath volume | TERMINÉ | `hostPath absent` |
| `demo` | conversation-service/conversation-service privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `demo` | conversation-service/conversation-service read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `demo` | conversation-service/conversation-service drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `demo` | conversation-service/conversation-service cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `demo` | conversation-service/conversation-service memory request and limit | TERMINÉ | `requests/limits memory` |
| `demo` | conversation-service/conversation-service ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `demo` | conversation-service/conversation-service readinessProbe | TERMINÉ | `readinessProbe present` |
| `demo` | conversation-service/conversation-service livenessProbe | TERMINÉ | `livenessProbe present` |
| `demo` | conversation-service/conversation-service startupProbe | TERMINÉ | `startupProbe present` |
| `demo` | conversation-service/conversation-service image not latest | TERMINÉ | `localhost:5001/securerag-hub-conversation-service:demo` |
| `demo` | Deployment audit-security-service rendered | TERMINÉ | `Deployment present` |
| `demo` | audit-security-service explicit non-default ServiceAccount | TERMINÉ | `sa-audit-security-service` |
| `demo` | audit-security-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `demo` | audit-security-service pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `demo` | audit-security-service RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `demo` | audit-security-service hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `demo` | audit-security-service hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `demo` | audit-security-service hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `demo` | audit-security-service no hostPath volume | TERMINÉ | `hostPath absent` |
| `demo` | audit-security-service/audit-security-service privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `demo` | audit-security-service/audit-security-service read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `demo` | audit-security-service/audit-security-service drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `demo` | audit-security-service/audit-security-service cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `demo` | audit-security-service/audit-security-service memory request and limit | TERMINÉ | `requests/limits memory` |
| `demo` | audit-security-service/audit-security-service ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `demo` | audit-security-service/audit-security-service readinessProbe | TERMINÉ | `readinessProbe present` |
| `demo` | audit-security-service/audit-security-service livenessProbe | TERMINÉ | `livenessProbe present` |
| `demo` | audit-security-service/audit-security-service startupProbe | TERMINÉ | `startupProbe present` |
| `demo` | audit-security-service/audit-security-service image not latest | TERMINÉ | `localhost:5001/securerag-hub-audit-security-service:demo` |
| `demo` | Service audit-security-service exposure restricted | TERMINÉ | `type=ClusterIP` |
| `demo` | Service auth-users exposure restricted | TERMINÉ | `type=ClusterIP` |
| `demo` | Service chatbot-manager exposure restricted | TERMINÉ | `type=ClusterIP` |
| `demo` | Service conversation-service exposure restricted | TERMINÉ | `type=ClusterIP` |
| `demo` | Service portal-web exposure restricted | TERMINÉ | `type=NodePort` |
| `demo` | PDB for portal-web | TERMINÉ | `PodDisruptionBudget present` |
| `demo` | PDB for auth-users | TERMINÉ | `PodDisruptionBudget present` |
| `demo` | PDB for chatbot-manager | TERMINÉ | `PodDisruptionBudget present` |
| `demo` | PDB for conversation-service | TERMINÉ | `PodDisruptionBudget present` |
| `demo` | PDB for audit-security-service | TERMINÉ | `PodDisruptionBudget present` |
| `demo` | NetworkPolicy default-deny-all | TERMINÉ | `NetworkPolicy present` |
| `demo` | NetworkPolicy allow-dns-egress | TERMINÉ | `NetworkPolicy present` |
| `demo` | NetworkPolicy allow-validation-ingress | TERMINÉ | `NetworkPolicy present` |
| `demo` | NetworkPolicy allow-validation-egress | TERMINÉ | `NetworkPolicy present` |
| `demo` | NetworkPolicy selects portal-web | TERMINÉ | `podSelector covers portal-web` |
| `demo` | NetworkPolicy selects auth-users | TERMINÉ | `podSelector covers auth-users` |
| `demo` | NetworkPolicy selects chatbot-manager | TERMINÉ | `podSelector covers chatbot-manager` |
| `demo` | NetworkPolicy selects conversation-service | TERMINÉ | `podSelector covers conversation-service` |
| `demo` | NetworkPolicy selects audit-security-service | TERMINÉ | `podSelector covers audit-security-service` |
| `dev` | Pod Security Admission enforce restricted | TERMINÉ | `namespace label enforce=restricted` |
| `dev` | Pod Security Admission audit restricted | TERMINÉ | `namespace label audit=restricted` |
| `dev` | Pod Security Admission warn restricted | TERMINÉ | `namespace label warn=restricted` |
| `dev` | ServiceAccount sa-portal-web token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | ServiceAccount sa-auth-users token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | ServiceAccount sa-chatbot-manager token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | ServiceAccount sa-conversation-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | ServiceAccount sa-audit-security-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | ServiceAccount sa-validation token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | Deployment portal-web rendered | TERMINÉ | `Deployment present` |
| `dev` | portal-web explicit non-default ServiceAccount | TERMINÉ | `sa-portal-web` |
| `dev` | portal-web token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | portal-web pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `dev` | portal-web RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `dev` | portal-web hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `dev` | portal-web hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `dev` | portal-web hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `dev` | portal-web no hostPath volume | TERMINÉ | `hostPath absent` |
| `dev` | portal-web/portal-web privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `dev` | portal-web/portal-web read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `dev` | portal-web/portal-web drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `dev` | portal-web/portal-web cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `dev` | portal-web/portal-web memory request and limit | TERMINÉ | `requests/limits memory` |
| `dev` | portal-web/portal-web ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `dev` | portal-web/portal-web readinessProbe | TERMINÉ | `readinessProbe present` |
| `dev` | portal-web/portal-web livenessProbe | TERMINÉ | `livenessProbe present` |
| `dev` | portal-web/portal-web startupProbe | TERMINÉ | `startupProbe present` |
| `dev` | portal-web/portal-web image not latest | TERMINÉ | `localhost:5001/securerag-hub-portal-web:dev` |
| `dev` | Deployment auth-users rendered | TERMINÉ | `Deployment present` |
| `dev` | auth-users explicit non-default ServiceAccount | TERMINÉ | `sa-auth-users` |
| `dev` | auth-users token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | auth-users pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `dev` | auth-users RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `dev` | auth-users hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `dev` | auth-users hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `dev` | auth-users hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `dev` | auth-users no hostPath volume | TERMINÉ | `hostPath absent` |
| `dev` | auth-users/auth-users privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `dev` | auth-users/auth-users read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `dev` | auth-users/auth-users drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `dev` | auth-users/auth-users cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `dev` | auth-users/auth-users memory request and limit | TERMINÉ | `requests/limits memory` |
| `dev` | auth-users/auth-users ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `dev` | auth-users/auth-users readinessProbe | TERMINÉ | `readinessProbe present` |
| `dev` | auth-users/auth-users livenessProbe | TERMINÉ | `livenessProbe present` |
| `dev` | auth-users/auth-users startupProbe | TERMINÉ | `startupProbe present` |
| `dev` | auth-users/auth-users image not latest | TERMINÉ | `localhost:5001/securerag-hub-auth-users:dev` |
| `dev` | Deployment chatbot-manager rendered | TERMINÉ | `Deployment present` |
| `dev` | chatbot-manager explicit non-default ServiceAccount | TERMINÉ | `sa-chatbot-manager` |
| `dev` | chatbot-manager token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | chatbot-manager pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `dev` | chatbot-manager RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `dev` | chatbot-manager hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `dev` | chatbot-manager hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `dev` | chatbot-manager hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `dev` | chatbot-manager no hostPath volume | TERMINÉ | `hostPath absent` |
| `dev` | chatbot-manager/chatbot-manager privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `dev` | chatbot-manager/chatbot-manager read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `dev` | chatbot-manager/chatbot-manager drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `dev` | chatbot-manager/chatbot-manager cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `dev` | chatbot-manager/chatbot-manager memory request and limit | TERMINÉ | `requests/limits memory` |
| `dev` | chatbot-manager/chatbot-manager ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `dev` | chatbot-manager/chatbot-manager readinessProbe | TERMINÉ | `readinessProbe present` |
| `dev` | chatbot-manager/chatbot-manager livenessProbe | TERMINÉ | `livenessProbe present` |
| `dev` | chatbot-manager/chatbot-manager startupProbe | TERMINÉ | `startupProbe present` |
| `dev` | chatbot-manager/chatbot-manager image not latest | TERMINÉ | `localhost:5001/securerag-hub-chatbot-manager:dev` |
| `dev` | Deployment conversation-service rendered | TERMINÉ | `Deployment present` |
| `dev` | conversation-service explicit non-default ServiceAccount | TERMINÉ | `sa-conversation-service` |
| `dev` | conversation-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | conversation-service pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `dev` | conversation-service RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `dev` | conversation-service hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `dev` | conversation-service hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `dev` | conversation-service hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `dev` | conversation-service no hostPath volume | TERMINÉ | `hostPath absent` |
| `dev` | conversation-service/conversation-service privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `dev` | conversation-service/conversation-service read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `dev` | conversation-service/conversation-service drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `dev` | conversation-service/conversation-service cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `dev` | conversation-service/conversation-service memory request and limit | TERMINÉ | `requests/limits memory` |
| `dev` | conversation-service/conversation-service ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `dev` | conversation-service/conversation-service readinessProbe | TERMINÉ | `readinessProbe present` |
| `dev` | conversation-service/conversation-service livenessProbe | TERMINÉ | `livenessProbe present` |
| `dev` | conversation-service/conversation-service startupProbe | TERMINÉ | `startupProbe present` |
| `dev` | conversation-service/conversation-service image not latest | TERMINÉ | `localhost:5001/securerag-hub-conversation-service:dev` |
| `dev` | Deployment audit-security-service rendered | TERMINÉ | `Deployment present` |
| `dev` | audit-security-service explicit non-default ServiceAccount | TERMINÉ | `sa-audit-security-service` |
| `dev` | audit-security-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `dev` | audit-security-service pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `dev` | audit-security-service RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `dev` | audit-security-service hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `dev` | audit-security-service hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `dev` | audit-security-service hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `dev` | audit-security-service no hostPath volume | TERMINÉ | `hostPath absent` |
| `dev` | audit-security-service/audit-security-service privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `dev` | audit-security-service/audit-security-service read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `dev` | audit-security-service/audit-security-service drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `dev` | audit-security-service/audit-security-service cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `dev` | audit-security-service/audit-security-service memory request and limit | TERMINÉ | `requests/limits memory` |
| `dev` | audit-security-service/audit-security-service ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `dev` | audit-security-service/audit-security-service readinessProbe | TERMINÉ | `readinessProbe present` |
| `dev` | audit-security-service/audit-security-service livenessProbe | TERMINÉ | `livenessProbe present` |
| `dev` | audit-security-service/audit-security-service startupProbe | TERMINÉ | `startupProbe present` |
| `dev` | audit-security-service/audit-security-service image not latest | TERMINÉ | `localhost:5001/securerag-hub-audit-security-service:dev` |
| `dev` | Service audit-security-service exposure restricted | TERMINÉ | `type=ClusterIP` |
| `dev` | Service auth-users exposure restricted | TERMINÉ | `type=ClusterIP` |
| `dev` | Service chatbot-manager exposure restricted | TERMINÉ | `type=ClusterIP` |
| `dev` | Service conversation-service exposure restricted | TERMINÉ | `type=ClusterIP` |
| `dev` | Service portal-web exposure restricted | TERMINÉ | `type=NodePort` |
| `dev` | PDB for portal-web | TERMINÉ | `PodDisruptionBudget present` |
| `dev` | PDB for auth-users | TERMINÉ | `PodDisruptionBudget present` |
| `dev` | PDB for chatbot-manager | TERMINÉ | `PodDisruptionBudget present` |
| `dev` | PDB for conversation-service | TERMINÉ | `PodDisruptionBudget present` |
| `dev` | PDB for audit-security-service | TERMINÉ | `PodDisruptionBudget present` |
| `dev` | NetworkPolicy default-deny-all | TERMINÉ | `NetworkPolicy present` |
| `dev` | NetworkPolicy allow-dns-egress | TERMINÉ | `NetworkPolicy present` |
| `dev` | NetworkPolicy allow-validation-ingress | TERMINÉ | `NetworkPolicy present` |
| `dev` | NetworkPolicy allow-validation-egress | TERMINÉ | `NetworkPolicy present` |
| `dev` | NetworkPolicy selects portal-web | TERMINÉ | `podSelector covers portal-web` |
| `dev` | NetworkPolicy selects auth-users | TERMINÉ | `podSelector covers auth-users` |
| `dev` | NetworkPolicy selects chatbot-manager | TERMINÉ | `podSelector covers chatbot-manager` |
| `dev` | NetworkPolicy selects conversation-service | TERMINÉ | `podSelector covers conversation-service` |
| `dev` | NetworkPolicy selects audit-security-service | TERMINÉ | `podSelector covers audit-security-service` |
| `kyverno-enforce-policies` | Kyverno policy securerag-audit-cleartext-env-values rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-enforce-policies` | Kyverno policy securerag-require-pod-security rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-enforce-policies` | Kyverno policy securerag-require-workload-controls rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-enforce-policies` | Kyverno policy securerag-restrict-image-references rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-enforce-policies` | Kyverno policy securerag-restrict-service-exposure rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-enforce-policies` | Kyverno policy securerag-restrict-volume-types rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-enforce-policies` | Kyverno policy securerag-verify-cosign-images rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-enforce-policies` | securerag-audit-cleartext-env-values is Enforce | TERMINÉ | `validationFailureAction=Enforce` |
| `kyverno-enforce-policies` | securerag-require-pod-security is Enforce | TERMINÉ | `validationFailureAction=Enforce` |
| `kyverno-enforce-policies` | securerag-require-workload-controls is Enforce | TERMINÉ | `validationFailureAction=Enforce` |
| `kyverno-enforce-policies` | securerag-restrict-image-references is Enforce | TERMINÉ | `validationFailureAction=Enforce` |
| `kyverno-enforce-policies` | securerag-restrict-service-exposure is Enforce | TERMINÉ | `validationFailureAction=Enforce` |
| `kyverno-enforce-policies` | securerag-restrict-volume-types is Enforce | TERMINÉ | `validationFailureAction=Enforce` |
| `kyverno-enforce-policies` | securerag-verify-cosign-images is Enforce | TERMINÉ | `validationFailureAction=Enforce` |
| `kyverno-policies` | Kyverno policy securerag-audit-cleartext-env-values rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-policies` | Kyverno policy securerag-require-pod-security rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-policies` | Kyverno policy securerag-require-workload-controls rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-policies` | Kyverno policy securerag-restrict-image-references rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-policies` | Kyverno policy securerag-restrict-service-exposure rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-policies` | Kyverno policy securerag-restrict-volume-types rendered | TERMINÉ | `ClusterPolicy present` |
| `kyverno-policies` | Kyverno policy securerag-verify-cosign-images rendered | TERMINÉ | `ClusterPolicy present` |
| `production` | Pod Security Admission enforce restricted | TERMINÉ | `namespace label enforce=restricted` |
| `production` | Pod Security Admission audit restricted | TERMINÉ | `namespace label audit=restricted` |
| `production` | Pod Security Admission warn restricted | TERMINÉ | `namespace label warn=restricted` |
| `production` | ServiceAccount sa-portal-web token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | ServiceAccount sa-auth-users token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | ServiceAccount sa-chatbot-manager token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | ServiceAccount sa-conversation-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | ServiceAccount sa-audit-security-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | ServiceAccount sa-validation token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | Deployment portal-web rendered | TERMINÉ | `Deployment present` |
| `production` | portal-web explicit non-default ServiceAccount | TERMINÉ | `sa-portal-web` |
| `production` | portal-web token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | portal-web pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `production` | portal-web RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `production` | portal-web hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `production` | portal-web hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `production` | portal-web hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `production` | portal-web no hostPath volume | TERMINÉ | `hostPath absent` |
| `production` | portal-web/portal-web privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `production` | portal-web/portal-web read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `production` | portal-web/portal-web drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `production` | portal-web/portal-web cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `production` | portal-web/portal-web memory request and limit | TERMINÉ | `requests/limits memory` |
| `production` | portal-web/portal-web ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `production` | portal-web/portal-web readinessProbe | TERMINÉ | `readinessProbe present` |
| `production` | portal-web/portal-web livenessProbe | TERMINÉ | `livenessProbe present` |
| `production` | portal-web/portal-web startupProbe | TERMINÉ | `startupProbe present` |
| `production` | portal-web/portal-web image not latest | TERMINÉ | `localhost:5001/securerag-hub-portal-web:production` |
| `production` | Deployment auth-users rendered | TERMINÉ | `Deployment present` |
| `production` | auth-users explicit non-default ServiceAccount | TERMINÉ | `sa-auth-users` |
| `production` | auth-users token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | auth-users pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `production` | auth-users RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `production` | auth-users hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `production` | auth-users hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `production` | auth-users hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `production` | auth-users no hostPath volume | TERMINÉ | `hostPath absent` |
| `production` | auth-users/auth-users privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `production` | auth-users/auth-users read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `production` | auth-users/auth-users drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `production` | auth-users/auth-users cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `production` | auth-users/auth-users memory request and limit | TERMINÉ | `requests/limits memory` |
| `production` | auth-users/auth-users ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `production` | auth-users/auth-users readinessProbe | TERMINÉ | `readinessProbe present` |
| `production` | auth-users/auth-users livenessProbe | TERMINÉ | `livenessProbe present` |
| `production` | auth-users/auth-users startupProbe | TERMINÉ | `startupProbe present` |
| `production` | auth-users/auth-users image not latest | TERMINÉ | `localhost:5001/securerag-hub-auth-users:production` |
| `production` | Deployment chatbot-manager rendered | TERMINÉ | `Deployment present` |
| `production` | chatbot-manager explicit non-default ServiceAccount | TERMINÉ | `sa-chatbot-manager` |
| `production` | chatbot-manager token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | chatbot-manager pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `production` | chatbot-manager RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `production` | chatbot-manager hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `production` | chatbot-manager hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `production` | chatbot-manager hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `production` | chatbot-manager no hostPath volume | TERMINÉ | `hostPath absent` |
| `production` | chatbot-manager/chatbot-manager privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `production` | chatbot-manager/chatbot-manager read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `production` | chatbot-manager/chatbot-manager drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `production` | chatbot-manager/chatbot-manager cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `production` | chatbot-manager/chatbot-manager memory request and limit | TERMINÉ | `requests/limits memory` |
| `production` | chatbot-manager/chatbot-manager ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `production` | chatbot-manager/chatbot-manager readinessProbe | TERMINÉ | `readinessProbe present` |
| `production` | chatbot-manager/chatbot-manager livenessProbe | TERMINÉ | `livenessProbe present` |
| `production` | chatbot-manager/chatbot-manager startupProbe | TERMINÉ | `startupProbe present` |
| `production` | chatbot-manager/chatbot-manager image not latest | TERMINÉ | `localhost:5001/securerag-hub-chatbot-manager:production` |
| `production` | Deployment conversation-service rendered | TERMINÉ | `Deployment present` |
| `production` | conversation-service explicit non-default ServiceAccount | TERMINÉ | `sa-conversation-service` |
| `production` | conversation-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | conversation-service pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `production` | conversation-service RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `production` | conversation-service hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `production` | conversation-service hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `production` | conversation-service hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `production` | conversation-service no hostPath volume | TERMINÉ | `hostPath absent` |
| `production` | conversation-service/conversation-service privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `production` | conversation-service/conversation-service read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `production` | conversation-service/conversation-service drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `production` | conversation-service/conversation-service cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `production` | conversation-service/conversation-service memory request and limit | TERMINÉ | `requests/limits memory` |
| `production` | conversation-service/conversation-service ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `production` | conversation-service/conversation-service readinessProbe | TERMINÉ | `readinessProbe present` |
| `production` | conversation-service/conversation-service livenessProbe | TERMINÉ | `livenessProbe present` |
| `production` | conversation-service/conversation-service startupProbe | TERMINÉ | `startupProbe present` |
| `production` | conversation-service/conversation-service image not latest | TERMINÉ | `localhost:5001/securerag-hub-conversation-service:production` |
| `production` | Deployment audit-security-service rendered | TERMINÉ | `Deployment present` |
| `production` | audit-security-service explicit non-default ServiceAccount | TERMINÉ | `sa-audit-security-service` |
| `production` | audit-security-service token automount disabled | TERMINÉ | `automountServiceAccountToken=false` |
| `production` | audit-security-service pod runs as non-root | TERMINÉ | `runAsNonRoot=true` |
| `production` | audit-security-service RuntimeDefault seccomp | TERMINÉ | `seccompProfile=RuntimeDefault` |
| `production` | audit-security-service hostNetwork disabled | TERMINÉ | `hostNetwork=false/absent` |
| `production` | audit-security-service hostPID disabled | TERMINÉ | `hostPID=false/absent` |
| `production` | audit-security-service hostIPC disabled | TERMINÉ | `hostIPC=false/absent` |
| `production` | audit-security-service no hostPath volume | TERMINÉ | `hostPath absent` |
| `production` | audit-security-service/audit-security-service privilege escalation disabled | TERMINÉ | `allowPrivilegeEscalation=false` |
| `production` | audit-security-service/audit-security-service read-only root filesystem | TERMINÉ | `readOnlyRootFilesystem=true` |
| `production` | audit-security-service/audit-security-service drops all capabilities | TERMINÉ | `capabilities.drop includes ALL` |
| `production` | audit-security-service/audit-security-service cpu request and limit | TERMINÉ | `requests/limits cpu` |
| `production` | audit-security-service/audit-security-service memory request and limit | TERMINÉ | `requests/limits memory` |
| `production` | audit-security-service/audit-security-service ephemeral-storage request and limit | TERMINÉ | `requests/limits ephemeral-storage` |
| `production` | audit-security-service/audit-security-service readinessProbe | TERMINÉ | `readinessProbe present` |
| `production` | audit-security-service/audit-security-service livenessProbe | TERMINÉ | `livenessProbe present` |
| `production` | audit-security-service/audit-security-service startupProbe | TERMINÉ | `startupProbe present` |
| `production` | audit-security-service/audit-security-service image not latest | TERMINÉ | `localhost:5001/securerag-hub-audit-security-service:production` |
| `production` | Service audit-security-service exposure restricted | TERMINÉ | `type=ClusterIP` |
| `production` | Service auth-users exposure restricted | TERMINÉ | `type=ClusterIP` |
| `production` | Service chatbot-manager exposure restricted | TERMINÉ | `type=ClusterIP` |
| `production` | Service conversation-service exposure restricted | TERMINÉ | `type=ClusterIP` |
| `production` | Service portal-web exposure restricted | TERMINÉ | `type=ClusterIP` |
| `production` | PDB for portal-web | TERMINÉ | `PodDisruptionBudget present` |
| `production` | PDB for auth-users | TERMINÉ | `PodDisruptionBudget present` |
| `production` | PDB for chatbot-manager | TERMINÉ | `PodDisruptionBudget present` |
| `production` | PDB for conversation-service | TERMINÉ | `PodDisruptionBudget present` |
| `production` | PDB for audit-security-service | TERMINÉ | `PodDisruptionBudget present` |
| `production` | NetworkPolicy default-deny-all | TERMINÉ | `NetworkPolicy present` |
| `production` | NetworkPolicy allow-dns-egress | TERMINÉ | `NetworkPolicy present` |
| `production` | NetworkPolicy allow-validation-ingress | TERMINÉ | `NetworkPolicy present` |
| `production` | NetworkPolicy allow-validation-egress | TERMINÉ | `NetworkPolicy present` |
| `production` | NetworkPolicy selects portal-web | TERMINÉ | `podSelector covers portal-web` |
| `production` | NetworkPolicy selects auth-users | TERMINÉ | `podSelector covers auth-users` |
| `production` | NetworkPolicy selects chatbot-manager | TERMINÉ | `podSelector covers chatbot-manager` |
| `production` | NetworkPolicy selects conversation-service | TERMINÉ | `podSelector covers conversation-service` |
| `production` | NetworkPolicy selects audit-security-service | TERMINÉ | `podSelector covers audit-security-service` |

## Interpretation

Statut global: TERMINÉ for static Kubernetes hardening render checks.
