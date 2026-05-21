# Kubernetes Security — SecureRAG Hub

> Vue agrégée des contrôles K8s. Référence canonique :
> [`docs/security/devsecops-hardening-applied.md`](security/devsecops-hardening-applied.md).

## Pod Security

Tous les Pods Laravel respectent **Pod Security Standards — Restricted** :

```yaml
spec:
  template:
    spec:
      automountServiceAccountToken: false
      serviceAccountName: sa-<service>
      securityContext:
        runAsNonRoot: true
        runAsUser: 33          # ou 65532
        runAsGroup: 33
        fsGroup: 33
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: <service>
          image: ghcr.io/.../<service>@sha256:...
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          resources:
            requests: { cpu: 50m, memory: 64Mi }
            limits:   { cpu: 500m, memory: 256Mi }
          livenessProbe:  { httpGet: { path: /health, port: http } }
          readinessProbe: { httpGet: { path: /health, port: http } }
```

**Validation continue :** `make audit-pod-security` (script statique sur
les manifests `infra/k8s/base/*/deployment.yaml`).

## RBAC

| Composant | Permissions |
|-----------|-------------|
| `sa-portal-web` | none (couche UI seule) |
| `sa-auth-users` | none |
| `sa-chatbot-manager` | none |
| `sa-conversation-service` | none |
| `sa-audit-security-service` | get/list events (Kubernetes API pour Falco logs) |
| `runtime-readonly` | get/list pods, services, configmaps (debug only) |

Manifests : `infra/k8s/base/rbac-runtime-readonly.yaml` + per-service
`serviceaccount.yaml`.

## NetworkPolicies

- **Default-deny** namespace-wide : `networkpolicy-default-deny.yaml`
- **Allow DNS** explicite : `networkpolicy-allow-dns.yaml`
- **Per-service allow** : ingress + egress whitelisting ciblés
- Validation : `make audit-networkpolicies`

Flux autorisés :

```
ingress-nginx → portal-web:8000
portal-web → {auth-users,chatbot-manager,conversation-service,audit-security}:8000
chatbot-manager → qdrant:6333, ollama:11434, audit-security-service:8000
auth-users → postgres:5432
conversation-service → postgres:5432
audit-security-service → postgres:5432
```

## Kyverno Policies (7)

| Policy | Mode actuel | Rôle |
|--------|:-----------:|------|
| `restrict-image-references` | Audit | Refuse `:latest`, registry whitelist |
| `restrict-volume-types` | Audit | Refuse `hostPath`, `nfs` non-whitelisté |
| `require-pod-security` | Audit | PSS Restricted appliqué |
| `require-workload-controls` | Audit | resources/probes/replicas obligatoires |
| `restrict-service-exposure` | Audit | Refuse NodePort/LoadBalancer non whitelisté |
| `verify-cosign-images` | Audit | Verify signature Cosign avant admission |
| `audit-cleartext-env-values` | Audit | Détecte ENV `password=...` en clair |

Bascule Enforce : `make kyverno-enforce-sequenced` (policy par policy avec
auto-rollback si violation post-Enforce).

## ResourceQuota + LimitRange

- `infra/k8s/base/resourcequota.yaml` : namespace `securerag-hub`
  contraint à 16 CPU / 32Gi requests max.
- `infra/k8s/base/limitrange.yaml` : limites par défaut + min/max par pod.

Protection contre **resource hijacking** (T1496 MITRE).

## Observabilité sécurité

- **Prometheus** scrape `kube-state-metrics`, `kyverno`, `falco`.
- **Alertes** : voir `infra/k8s/observability/prometheus-rules-security.yaml`
  (8 alertes : CrashLoopBackOff, PodNotReady, OOMKilled, Kyverno failures,
  Falco Critical events, Falco shell, ArgoCD OutOfSync, ArgoCD Degraded).
- **Loki** ingère Falco events via falcosidekick.
- **Grafana dashboards** : SRE + Sécurité (compteurs Kyverno/Falco, top
  rules, taux 401/403, ...).

## Admission tests

Voir [`artifacts/validation/kyverno-admission-tests.md`](../artifacts/validation/kyverno-admission-tests.md).

6 fixtures couvrent les cas types :

- ✅ Pod conforme accepté
- ❌ Pod privileged refusé
- ❌ hostPath refusé
- ❌ image `:latest` refusée
- ❌ image non signée refusée
- ❌ secret en clair en env refusé

## MITRE ATT&CK coverage

37 techniques cataloguées dans [`docs/security/mitre-attack-k8s-mapping.md`](security/mitre-attack-k8s-mapping.md).

Couverture par tactique :

| Tactique | 🟢 | 🟡 | 🔴 |
|----------|---:|---:|---:|
| Initial Access | 3 | 1 | 0 |
| Execution | 1 | 2 | 0 |
| Persistence | 2 | 1 | 0 |
| Privilege Escalation | 3 | 1 | 0 |
| Defense Evasion | 2 | 2 | 0 |
| Credential Access | 1 | 3 | 0 |
| Discovery | 3 | 0 | 0 |
| Lateral Movement | 2 | 1 | 0 |
| Collection | 2 | 0 | 0 |
| Exfiltration | 3 | 0 | 0 |
| Impact | 3 | 1 | 0 |
| **Total** | **25** | **12** | **0** | (= 68%) |
