# CI Quality Gate — FAIL

_Generated: 2026-09-25T05:16:54Z_

| Check | Status | Required | Details |
|-------|:------:|:--------:|---------|
| `unit-tests` | ✅ PASS | true | 5 suite(s), 0 failure |
| `coverage` | ✅ PASS | true | 98% ≥ 95% |
| `semgrep-sast` | ✅ PASS | true | 0 finding |
| `gitleaks` | ❌ FAIL | true | 5 leak(s) detected |
| `trivy-fs` | ✅ PASS | true | 0 CRITICAL, 4 HIGH |
| `dependency-audit` | ✅ PASS | true | all audits passed successfully |
| `kube-score` | ✅ PASS | true | no thresholds exceeded |
| `kyverno-static` | ⚠️ PARTIEL | false | kyverno CLI absent (non-strict) |
| `owasp-zap-dast` | ✅ PASS | true | 0 DAST alerts (baseline pass) |
| `ai-security-testing` | ✅ PASS | true | 0 critical LLM vulnerability |

**Verdict global :** `FAIL` — au moins une vérification requise échoue. Voir détails ci-dessus.
