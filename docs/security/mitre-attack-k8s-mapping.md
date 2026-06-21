# MITRE ATT&CK for Kubernetes — SecureRAG Hub coverage

> Reference matrix : <https://attack.mitre.org/matrices/enterprise/containers/>
> + extension MITRE ATT&CK for Containers/Kubernetes (TA00xx → TA00yy).
>
> **Légende couverture :**
> - 🟢 Couvert — contrôle implémenté + preuve archivée
> - 🟡 Partiel — contrôle présent mais runtime/non-prod
> - 🔴 Non couvert — gap accepté ou hors-scope

## Tactique TA0001 — Initial Access

| Technique | ID | Vecteur | Contrôle SecureRAG | Couverture | Preuve |
|-----------|----|---------|--------------------|:----------:|--------|
| Compromised image (in registry) | T1190 | Image avec malware tirée | Trivy CRITICAL gate dans CI ; Cosign verify ; Kyverno verifyImages | 🟢 | `artifacts/release/image-scan-summary.md` + `verify-summary.txt` |
| Application exploit (public-facing) | T1190 | Exploit Laravel CVE | Composer audit + Trivy fs + dependency-audit | 🟢 | `security/reports/dependency-audit-summary.md` |
| Exposed dashboard (K8s Dashboard, etc.) | T1078 | Dashboard non protégé | Aucun dashboard exposé ; ingress n'a aucune route vers `kubernetes-dashboard` | 🟢 | NetworkPolicy default-deny |
| Compromised credentials (kubeconfig) | T1078 | kubeconfig leaké | RBAC least-priv + audit log + rotation tokens | 🟡 | RBAC manifests ; rotation à automatiser |

## Tactique TA0002 — Execution

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| Container exec into pod (`kubectl exec`) | T1610 | Attaquant accédant au cluster | Falco rule `Terminal shell in container` → alerte Critical via falcosidekick→Loki | 🟢 | `security/falco/rules/` + `infra/k8s/runtime-detection/configmap-rules.yaml` |
| Application code injection | T1059 | RCE Laravel | SAST Semgrep + WAF (à ajouter) + readOnlyRootFilesystem | 🟡 | semgrep.json |
| Scheduled task abuse (CronJob) | T1053 | CronJob malveillant créé | Kyverno require-pod-security PSS Restricted ; RBAC restrict create cronjobs | 🟡 | `verify-cosign-images` aussi sur Job/CronJob (à étendre) |

## Tactique TA0003 — Persistence

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| Backdoor container | T1525 | Image modifiée pushée | Cosign signing + Kyverno verifyImages strict | 🟢 | `verify-cosign-images.yaml` |
| Implant Mutating webhook | T1547 | Webhook injecté | RBAC restrict admissionregistration.k8s.io | 🟡 | À renforcer dans `infra/k8s/base/rbac-runtime-readonly.yaml` |
| Persistent volume payload | T1543 | Payload dans PVC | readOnlyRootFilesystem + restrict-volume-types (no hostPath) | 🟢 | `restrict-volume-types.yaml` |

## Tactique TA0004 — Privilege Escalation

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| Privileged container | T1611 | `securityContext.privileged: true` | Kyverno require-pod-security PSS Restricted ; PSS namespace label | 🟢 | `tests/admission/negative/01-privileged-pod.yaml` |
| Container breakout via host PID/IPC | T1611 | `hostPID/hostIPC: true` | Kyverno require-pod-security | 🟢 | id |
| Capability abuse | T1548 | Container avec NET_ADMIN, SYS_ADMIN | `capabilities.drop: [ALL]` + Kyverno enforce | 🟢 | `audit-pod-security.sh` |
| sudo / setuid in container | T1548 | Binaires setuid présents | Trivy image + Distroless/scratch base | 🟡 | À auditer Dockerfiles |

## Tactique TA0005 — Defense Evasion

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| Disable runtime detection | T1562 | Falco DaemonSet supprimé | Kyverno restrict delete on falco DS + alerte Prometheus | 🟡 | À ajouter ClusterPolicy |
| Clear container logs | T1070 | `truncate /var/log/...` | Loki append-only + readOnlyRootFilesystem | 🟢 | Loki retention policy |
| Indicator removal on host | T1070 | tampering /etc/audit | Audit logs externalisés via Loki + Falco | 🟢 | id |
| Deploy in `kube-system` namespace | T1078 | Pod dans system NS | Kyverno scope = securerag-hub uniquement ; RBAC | 🟡 | À renforcer |

## Tactique TA0006 — Credential Access

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| Mounted SA token | T1552 | `automountServiceAccountToken: true` par défaut | `automountServiceAccountToken: false` partout | 🟢 | `audit-pod-security.sh` |
| Cleartext credentials in env | T1552 | Password en plain dans env | SOPS+age + audit-cleartext-env-values policy | 🟡 | `secret-rotation.md` ; SOPS to deploy |
| Credentials in K8s Secret | T1552 | Secret non chiffré at-rest | etcd encryption + SOPS at Git layer | 🟡 | À activer `--encryption-provider-config` |
| Image pulled with embedded creds | T1552 | Dockerfile ENV API_KEY | Gitleaks + Trivy secret scanner | 🟢 | `gitleaks.json` |

## Tactique TA0007 — Discovery

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| Network service scanning | T1046 | Pod scanne le cluster | NetworkPolicy default-deny + per-service egress allowlist | 🟢 | `audit-networkpolicies.sh` |
| Cluster API enumeration | T1613 | `kubectl get pods -A` depuis pod | RBAC : SA n'a pas `list pods` cluster-wide | 🟢 | `rbac-runtime-readonly.yaml` |
| ConfigMap discovery | T1613 | Lecture configmaps cluster | RBAC namespaced uniquement | 🟢 | id |

## Tactique TA0008 — Lateral Movement

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| Cluster API to other namespaces | T1199 | SA cross-namespace | RBAC namespaced + Kyverno block cross-NS Service | 🟡 | À documenter |
| Pod-to-pod via service | T1021 | Service exposé inter-NS | NetworkPolicy par-service avec namespaceSelector explicite | 🟢 | `infra/k8s/base/<svc>/networkpolicy.yaml` |
| Container escape → host network | T1611 | hostNetwork: true | Kyverno require-pod-security PSS Restricted | 🟢 | id |

## Tactique TA0009 — Collection

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| Data from local volumes / hostPath | T1005 | hostPath mount | `restrict-volume-types.yaml` Kyverno | 🟢 | `tests/admission/negative/02-hostpath-volume.yaml` |
| Snapshot of database | T1530 | pg_dump non autorisé | RBAC `pg-backup-sa` minimal + NetworkPolicy egress restic-only | 🟢 | `infra/k8s/backup/postgres-backup-cronjob.yaml` |

## Tactique TA0010 — Exfiltration

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| DNS tunneling | T1048 | Exfil via DNS | Falco DNS rule + egress NetworkPolicy DNS-only via CoreDNS | 🟢 | `security/falco/rules/` + `networkpolicy-allow-dns.yaml` |
| HTTP exfil to attacker | T1567 | curl vers C2 | Egress allowlist par-service (chatbot-manager n'a pas accès Internet) | 🟢 | `audit-networkpolicies.sh` |
| Public S3 bucket | T1567 | Code écrit vers public bucket | RBAC + secrets scan + NetworkPolicy egress | 🟢 | id |

## Tactique TA0040 — Impact

| Technique | ID | Vecteur | Contrôle | Couv. | Preuve |
|-----------|----|---------|----------|:-----:|--------|
| Resource hijacking (cryptomining) | T1496 | Pod consomme CPU/RAM | LimitRange + ResourceQuota + Falco rule (cryptomining IoC) | 🟢 | `infra/k8s/base/limitrange.yaml` + `resourcequota.yaml` |
| Endpoint DoS | T1499 | Crash service | HPA + PDB + readiness/liveness probes | 🟢 | `infra/k8s/overlays/production/patches/pdb-production.yaml` + HPA |
| Data destruction | T1485 | DROP TABLE etc. | Backup PG quotidien + restore drill prouvé | 🟡 | `scripts/backup/restore-drill.sh` (à exécuter en prod) |
| Defacement | T1491 | Modif portal-web | Argo CD GitOps strict ; toute modif hors-Git = drift alerté | 🟢 | `argocd-notifications-cm.yaml` |

## Synthèse couverture

| Tactique | Techniques cataloguées | 🟢 | 🟡 | 🔴 | Couverture % |
|----------|---:|---:|---:|---:|----:|
| TA0001 Initial Access | 4 | 3 | 1 | 0 | 75 |
| TA0002 Execution | 3 | 1 | 2 | 0 | 33 |
| TA0003 Persistence | 3 | 2 | 1 | 0 | 67 |
| TA0004 Privilege Escalation | 4 | 3 | 1 | 0 | 75 |
| TA0005 Defense Evasion | 4 | 2 | 2 | 0 | 50 |
| TA0006 Credential Access | 4 | 1 | 3 | 0 | 25 |
| TA0007 Discovery | 3 | 3 | 0 | 0 | 100 |
| TA0008 Lateral Movement | 3 | 2 | 1 | 0 | 67 |
| TA0009 Collection | 2 | 2 | 0 | 0 | 100 |
| TA0010 Exfiltration | 3 | 3 | 0 | 0 | 100 |
| TA0040 Impact | 4 | 3 | 1 | 0 | 75 |
| **Total** | **37** | **25** | **12** | **0** | **68%** |

## Plan de complétion vers 90 %

1. **TA0006 / TA0002** : déployer SOPS+age + activer `--encryption-provider-config`
   sur etcd (kubeadm patch ou managed K8s setting). +3 🟢 → +8 % global.
2. **TA0005** : Kyverno ClusterPolicy `protect-falco-daemonset` qui refuse
   `delete daemonsets/falco`. +1 🟢.
3. **TA0001** : automatiser rotation kubeconfig admin. +1 🟢.
4. **TA0040 data destruction** : exécuter le restore drill mensuellement et
   archiver. +1 🟢.

Cible post-roadmap : **>90 % de techniques en 🟢**.
