# Kyverno fixtures tests — Status: `PARTIEL`

_Generated UTC: 2026-06-18T12:52:02Z_

**6 cas, 1 échec(s).**

| Result | Expected | Actual | Fixture | Detail |
|:------:|:--------:|:------:|---------|--------|
| ❌ FAIL | ACCEPT | REJECT | `tests/admission/positive/01-conformant-pod.yaml` | Error from server: error when creating "tests/admission/positive/01-conformant-pod.yaml": admission webhook "mutate.kyverno.svc-fail" denied the request:  |
| ✅ PASS | REJECT | REJECT | `tests/admission/negative/01-privileged-pod.yaml` | - |
| ✅ PASS | REJECT | REJECT | `tests/admission/negative/02-hostpath-volume.yaml` | - |
| ✅ PASS | REJECT | REJECT | `tests/admission/negative/03-unsigned-image.yaml` | - |
| ✅ PASS | REJECT | REJECT | `tests/admission/negative/04-image-latest-tag.yaml` | - |
| ✅ PASS | REJECT | REJECT | `tests/admission/negative/05-cleartext-password.yaml` | - |
