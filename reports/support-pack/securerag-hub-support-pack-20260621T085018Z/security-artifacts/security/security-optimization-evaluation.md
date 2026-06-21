# SecureRAG Hub — Security optimization evaluation

Date: 2026-04-30
Scope: pre-deployment hardening + Falco runtime extension + post-deployment.

## 1. Discovery snapshot

| Area | Detected |
|------|----------|
| Languages | PHP 8.4 (Laravel × 5), Python (Knowledge Hub / LLM orchestrator) |
| Containers | 9 Dockerfiles, all pinned by digest (`composer:2@sha256:...`, `php:8.4-cli-bookworm@sha256:...`) |
| Orchestration | Kubernetes (kind for dev), Kustomize overlays: `demo`, `dev`, `legacy`, `production`, `production-external-db` |
| Authoritative CI/CD | Jenkins (`Jenkinsfile`, `Jenkinsfile.cd`) — GitHub Actions = `LEGACY_MIRROR_ONLY` |
| Static security present | Semgrep, Gitleaks, Trivy fs, SonarQube (gated), Composer/npm audit |
| Supply chain | Cosign sign+verify, digest-only promotion, Syft SBOM, attestations, SLSA-style provenance |
| Admission | Kyverno (Audit + Enforce toggle with auto-rollback) |
| Runtime | Falco DaemonSet 0.38.2 modern-bpf; Tetragon optional (currently disabled) |
| Observability | Prometheus 2.54 + Grafana 11 + Loki 3.1 + Alertmanager 0.27 |
| Backup | CronJob pg_dump 02:30 UTC, 14d retention, restore-cycle test |
| Secrets | SOPS/age active rotation + leak detection |

## 2. Risk evaluation

| Severity | Area | Evidence | Risk | Fix shipped |
|----------|------|----------|------|-------------|
| HIGH | Runtime detection coverage | `infra/k8s/runtime-detection/configmap-rules.yaml` had 4 rules only, no MITRE mapping | Many TTPs (reverse shell, persistence, package mgr, log tampering, K8s API abuse) undetected | **Yes** — added 11 MITRE-aligned rules in `security/falco/custom-rules.yaml`, mirrored into ConfigMap `securerag_mitre_rules.yaml`, mounted in DaemonSet |
| HIGH | Egress allow-list too broad | Original rule had hard-coded port list with redundant entries | False negatives on C2 / data exfiltration | **Yes** — refined `securerag_egress_ports` macro (53/80/443/5432/6379/8000/9000/9090/3100/9093) and added negative match rule |
| MEDIUM | No CI gate for Kustomize misconfig | Jenkinsfile validates Kyverno + ultra-hardening but no kube-score | Drift not detected pre-merge | **Yes** — `scripts/ci/validate-kube-score.sh`, fails on CRITICAL only |
| MEDIUM | Falco rules not lint-gated | Rule edits could introduce parser errors that only surface in cluster | Silent runtime regression | **Yes** — `scripts/ci/validate-falco-rules.sh` + Jenkins stage |
| MEDIUM | No alert routing wired | Falco logs only to stdout | Slow incident response | **Documented** — Falcosidekick → Loki + Alertmanager pattern in `security/falco/values.yaml`, opt-in (no auto-deploy) |
| LOW | K8s audit log forwarding optional | API server not configured to ship audit log to Loki | `Suspicious K8s API Verb` rule cannot fire on managed kind | **Documented** — runbook §4 |
| LOW | Tetragon disabled | `tetragon-optional.yaml` not in kustomization | Defense-in-depth gap | **Untouched** — out of scope this round |

No CRITICAL pre-existing gaps detected. Pod hardening already strong:
`runAsNonRoot: true`, `allowPrivilegeEscalation: false`,
`readOnlyRootFilesystem: true`, `drop: ["ALL"]`,
`seccompProfile: RuntimeDefault`, requests/limits, all probes,
`automountServiceAccountToken: false`, NetworkPolicy default-deny baseline.

## 3. Pre-deploy hardening (shift-left) added this round

- `scripts/ci/validate-kube-score.sh` — renders Kustomize overlays
  (`demo`, `production`), runs `kube-score`, fails CI on CRITICAL.
- `scripts/ci/validate-falco-rules.sh` — Falco rules linter with
  Docker container path (preferred) and Python YAML fallback.
- `Jenkinsfile` — both gates wired into the existing
  `CI_K8S_POLICY` stage with archive of new artefacts.

No Dockerfile changes required: all 9 images already use pinned digests,
non-root user (`uid 10001`), no secrets in image, multi-stage builds,
correct `EXPOSE`, runtime root `/tmp/securerag-runtime` (RO rootfs ready).

## 4. Falco extension delivered

- `security/falco/custom-rules.yaml` — canonical MITRE rule set (11 rules).
- `security/falco/values.yaml` — opt-in Helm values (chart alternative).
- `security/falco/test-triggers.sh` — harmless verification snippets.
- `security/falco/README.md` — install/test/tune guide.
- `infra/k8s/runtime-detection/configmap-rules.yaml` — embedded
  `securerag_mitre_rules.yaml` alongside the legacy 4-rule set.
- `infra/k8s/runtime-detection/daemonset.yaml` — additional volumeMount
  so Falco loads the new rules file.

Coverage matrix (MITRE ATT&CK):

| Tactic | Technique | Rule |
|--------|-----------|------|
| Execution | T1059 | Shell, Reverse Shell, Package Manager |
| Execution | T1105 | Package Manager |
| Persistence | T1136 | User Account Mutation, Write Below Sensitive |
| Persistence | T1505 | Write Below Sensitive |
| Persistence | T1543 | Persistence Mechanism Touched |
| Privilege Escalation | T1611, T1548 | Privilege Escalation Attempt |
| Defense Evasion | T1070 | Log Tampering |
| Credential Access | T1552.001 | Sensitive / Credential File Read |
| Discovery | T1610, T1613 | Suspicious K8s API Verb |
| C2 | TA0011 | Outbound Unexpected Port (Refined) |

## 5. Post-deploy controls documented

`docs/runbooks/runtime-security-operations.md` covers: alert workflow,
Falcosidekick wiring, triage checklist, retention, audit log forwarding,
post-deploy Trivy + cosign re-verification, digest verification, rollback
plan (`kyverno-enforce-toggle.sh`, `argocd app rollback`), and quarterly
rule tuning cadence.

## 6. Validation commands (no auto-execution)

```bash
# Static lint (CI parity)
bash scripts/ci/validate-falco-rules.sh
bash scripts/ci/validate-kube-score.sh

# Existing gates
make official-scope
make kyverno-admission-tests
bash scripts/validate/validate-k8s-ultra-hardening.sh

# Cluster (operator approves before running)
kubectl apply -k infra/k8s/runtime-detection/
kubectl -n falco rollout status ds/falco --timeout=120s
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=50

# Trigger harmless rules and tail logs in parallel
bash security/falco/test-triggers.sh

# Post-deploy
bash scripts/validate/generate-final-validation-summary.sh
bash scripts/validate/generate-expert-readiness-report.sh
```

## 7. Remaining risks (not addressed this round)

- Tetragon TracingPolicy still optional — recommend enabling once Falco is stable.
- K8s audit log forwarding requires API server config (out of scope for managed kind).
- Falcosidekick disabled by default — operator must opt-in to enable PagerDuty/Slack routing.
- No automatic memory forensics on CRITICAL alerts.
- `restrict-image-references` Kyverno policy is in Audit; promote to Enforce once digest-only mode is confirmed across all overlays.
