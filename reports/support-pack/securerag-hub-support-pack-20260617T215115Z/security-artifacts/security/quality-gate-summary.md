# CI Quality Gate — FAIL

_Generated: 2026-05-07T19:30:28Z_

| Check | Status | Required | Details |
|-------|:------:|:--------:|---------|
| `unit-tests` | ⚠️ PARTIEL | true | no junit-*.xml found in /Users/mohamedyassine/Desktop/PFE/Master/.claude/worktrees/intelligent-kirch-35c142/.coverage-artifacts |
| `coverage` | ⚠️ PARTIEL | false | no coverage-summary.txt |
| `semgrep-sast` | ⚠️ PARTIEL | true | semgrep.json missing |
| `gitleaks` | ⚠️ PARTIEL | true | gitleaks.json missing |
| `trivy-fs` | ⚠️ PARTIEL | true | trivy-fs.json missing |
| `dependency-audit` | ⚠️ PARTIEL | false | summary present but verdict unclear |
| `kube-score` | ⚠️ PARTIEL | true | binary missing (non-strict mode) |
| `kyverno-static` | ⚠️ PARTIEL | false | kyverno CLI absent (non-strict) |

**Verdict global :** `FAIL` — au moins une vérification requise échoue. Voir détails ci-dessus.
