# Secure Quality Gate — FAIL
_Generated: 2026-06-17T21:50:00Z_

| Check | Status | Details |
|-------|:------:|---------|
| `unit-tests` | ✅ PASS | 5/5 suites, 0 failures |
| `coverage` | ✅ PASS | 87.09% >= 85% |
| `semgrep` | ✅ PASS | 0 findings |
| `gitleaks` | ✅ PASS | 0 leaks |
| `trivy-fs` | ✅ PASS | 0 CRITICAL, 1 HIGH |
| `trivy-image` | ⏭️ SKIP | trivy-image.json not available (CD stage) |
| `dependency-audit` | ❌ FAIL | Vulnerabilities found |
| `checkov` | ❌ FAIL | No Checkov reports found |
| `kube-score` | ✅ PASS | All thresholds met |
| `sonarqube` | ✅ PASS | Quality gate passed |
| `falco` | ✅ PASS | 0 CRITICAL alerts |
| `tetragon` | ✅ PASS | 0 kubectl exec violations |
| `cosign` | ⏭️ SKIP | CD artifacts not present |

**Verdict: FAIL** — 4 check(s) failed.
