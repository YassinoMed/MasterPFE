# Falco runtime security — SecureRAG Hub

## What ships in this repo

| Path | Purpose |
|------|---------|
| `infra/k8s/runtime-detection/` | Kustomize install (DaemonSet + RBAC + ConfigMap). Authoritative install path used by `make falco-up`. |
| `security/falco/custom-rules.yaml` | Canonical MITRE ATT&CK-aligned rule set. Mirrored into the Kustomize ConfigMap as `securerag_mitre_rules.yaml`. |
| `security/falco/values.yaml` | Optional Helm values for the `falcosecurity/falco` chart. |
| `security/falco/test-triggers.sh` | Harmless commands to verify rules fire. |
| `scripts/ci/validate-falco-rules.sh` | CI lint (Falco container or YAML fallback). |

## Install (in-repo Kustomize path — recommended)

```bash
make falco-up        # applies infra/k8s/runtime-detection/ via kubectl apply -k
kubectl -n falco get ds falco
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=50
```

## Install (alternative — Helm)

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm upgrade --install falco falcosecurity/falco \
  -n falco --create-namespace \
  -f security/falco/values.yaml
```

Pick **one** install path; do not mix.

## Test that rules fire

```bash
# Tail Falco logs in one terminal:
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=200 -f | grep SecureRAG

# Trigger harmless events from an ephemeral pod:
kubectl -n securerag-hub run falco-test --rm -it --restart=Never \
  --image=alpine:3.20 -- /bin/sh
# then paste the snippets printed by:
bash security/falco/test-triggers.sh
```

Expected hits: `SecureRAG Shell in Container`, `Package Manager`, `Sensitive File Read`, `Outbound Unexpected Port`, `Write Below Sensitive Path`, `User Account Mutation`.

## Rule coverage (MITRE ATT&CK)

| Rule | Tactic | Technique |
|------|--------|-----------|
| Shell in Container | Execution | T1059 |
| Reverse Shell Indicator | Execution | T1059 |
| Package Manager in Container | Execution | T1059 / T1105 |
| Write Below Sensitive Path | Persistence | T1505 / T1136 |
| User Account Mutation | Persistence | T1136.001 |
| Persistence Mechanism Touched | Persistence | T1543 |
| Privilege Escalation Attempt | Privilege Escalation | T1611 / T1548 |
| Sensitive / Credential File Read | Credential Access | T1552.001 |
| Log Tampering | Defense Evasion | T1070 |
| Outbound Unexpected Port (Refined) | C2 | TA0011 |
| Suspicious K8s API Verb | Discovery | T1613 / T1610 |

## Tuning false positives

1. Tail logs and isolate the rule name.
2. Edit `security/falco/custom-rules.yaml` (canonical).
3. Mirror the change in `infra/k8s/runtime-detection/configmap-rules.yaml`.
4. Add allow-list expressions inline (e.g. extend `securerag_egress_ports` for new dependencies).
5. Re-run `bash scripts/ci/validate-falco-rules.sh`.
6. `kubectl -n falco rollout restart ds/falco`.

Always prefer **scoping** (namespace/pod/process) over disabling.

## Outputs

- Default: stdout (JSON). Visible via `kubectl logs`.
- Optional: enable Falcosidekick → Loki + Alertmanager via the Helm values
  (set `falcosidekick.enabled: true`). The cluster already runs Loki and
  Alertmanager in the `observability` namespace.

## Operational runbook

See `docs/runbooks/runtime-security-operations.md`.
