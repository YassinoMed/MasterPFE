# Runtime security — Post-deployment operations

Audience: SRE / DevSecOps on-call. Companion to `security/falco/README.md`.

## 1. Alert review workflow

| Step | Owner | Action |
|------|-------|--------|
| 1 | On-call | Tail `kubectl -n falco logs -l app.kubernetes.io/name=falco --since=15m` and triage by `priority` field. |
| 2 | On-call | Cross-check the alert against the runbook for that MITRE technique. |
| 3 | On-call | Open an incident in the audit-security-service if `priority` ≥ ERROR. |
| 4 | DevSecOps | Confirm true/false positive within 30 min for CRITICAL. |
| 5 | DevSecOps | Tune rule (`security/falco/custom-rules.yaml`) or quarantine pod. |
| 6 | DevSecOps | Postmortem + Kyverno policy update if pattern reproducible. |

## 2. Falco alert destinations

Default: container stdout (JSON), collected by Loki via the cluster log
agent. Optional pipeline:

```
Falco DaemonSet ──► stdout (json) ──► Loki ──► Grafana dashboard
                  └► Falcosidekick ──► Alertmanager ──► PagerDuty / Slack
```

Falcosidekick is **disabled by default**. Enable by flipping
`falcosidekick.enabled: true` in `security/falco/values.yaml` then
re-applying the Helm release.

## 3. Incident triage checklist

- [ ] Confirm Falco event is not from `kube-system` or operator pods.
- [ ] Snapshot pod state: `kubectl -n securerag-hub describe pod <name>`.
- [ ] Pull last 200 lines of pod logs and Falco logs to evidence bucket.
- [ ] If CRITICAL: cordon node, scale deployment to 0, take memory dump if possible.
- [ ] Verify image digest: `kubectl -n securerag-hub get pod <name> -o jsonpath='{.status.containerStatuses[*].imageID}'` and compare to release manifest.
- [ ] Run on-demand Trivy scan of the running image digest.
- [ ] Kyverno PolicyReport check: `kubectl get policyreport -A`.
- [ ] Open ticket with: pod name, image digest, rule name, MITRE id, evidence paths.

## 4. Log retention & monitoring

- Falco stdout → Loki (retention 14 days, configured in
  `infra/k8s/observability/loki-deployment.yaml`).
- K8s API audit log forwarding: enable `--audit-log-path` and an
  `--audit-policy-file` on the API server (kind cluster: patch via
  `infra/kind/`). Ship to the same Loki.
- Prometheus alert: `FalcoEventsHigh` — rate of `priority=critical`
  events > 0 over 5 min triggers Alertmanager.

## 5. Vulnerability re-scan after deployment

```bash
# Use the digest pinned by the CD pipeline, not :tag
kubectl -n securerag-hub get pods -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u
trivy image --severity HIGH,CRITICAL <image>@sha256:<digest>
```

Also run `cosign verify` against the same digest to confirm signature.

## 6. Image digest verification

The CD pipeline already promotes images by digest (`@sha256:...`).
Post-deploy gate:

```bash
bash scripts/validate/generate-final-validation-summary.sh
# detect_digest_runtime_status() asserts every running pod uses an
# `@sha256:` reference. Returns 1 on tag-only deployments.
```

## 7. Rollback plan

| Trigger | Action |
|---------|--------|
| CRITICAL Falco rule fires repeatedly on same pod | `kubectl -n securerag-hub rollout undo deploy/<name>`. |
| Kyverno PolicyReport shows new violation post-deploy | `bash scripts/deploy/kyverno-enforce-toggle.sh --to=audit` (auto-rollback to Audit mode). |
| Image signature verification fails | `kubectl -n securerag-hub set image deploy/<name> <ctr>=<previous-digest>`. |
| Cluster-wide regression | `argocd app rollback securerag-hub-production <prev-rev>`. |

Rollback drills should run quarterly (already tracked in
`docs/runbooks/data-resilience.md`).

## 8. Periodic rule tuning

| Cadence | Activity |
|---------|----------|
| Weekly | Review `priority>=ERROR` Falco events in Loki; close out FPs. |
| Monthly | Walk through `security/falco/custom-rules.yaml` against MITRE ATT&CK release notes. |
| Quarterly | Run red-team exercise using `security/falco/test-triggers.sh` patterns; verify each rule still fires. |
| Per release | Re-run `scripts/ci/validate-falco-rules.sh` and confirm CI artefact present. |

## 9. Evidence trail

All post-deploy commands write into `artifacts/security/`. Keep:

- `runtime-security-postdeploy.md` (existing — refreshed by CD).
- `falco-rules-validation.log` (CI lint).
- `kube-score-report.md` (CI shift-left).
- `kyverno-policy-validation.md` (admission).
- `security-optimization-evaluation.md` (this round).
