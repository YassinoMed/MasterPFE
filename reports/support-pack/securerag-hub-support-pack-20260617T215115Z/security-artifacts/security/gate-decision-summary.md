# Security Gate Decision Report

**Date:** 2026-06-17T11:37:20Z
**Engine:** gate-decision-engine.sh v1.0
**Classifier:** security-classifier.sh v1.0

## Gate Status: **PASS**

## Scope Summary

| Scope | CRITICAL | HIGH | MEDIUM | Total |
|:---|---:|---:|---:|---:|
| **PRODUCTION** | 0 | 0 | 0 | 0 |
| **NON_PROD** (warning) | - | - | - | 0 |
| **LEGACY** (ignored) | - | - | - | 0 |
| **VENDOR** (ignored) | - | - | - | 0 |

## Scan Summary

| Scan | Findings | Scope |
|:---|---:|:---|
| Trivy (Vulnerabilities) | 0 | Scope-aware |
| Semgrep (SAST) | 0 | Scope-aware |
| Gitleaks (Secrets) | 0 | Scope-aware |

## Decision Rules

| Rule | Condition | Action |
|:---|---|:---|
| PROD CRITICAL/HIGH found | prod_critical > 0 OR prod_high > 0 | ❌ **FAIL pipeline** |
| PROD MEDIUM only | prod_medium > 0 | ⚠️ WARNING |
| NON_PROD findings only | nonprod_total > 0 | ⚠️ WARNING |
| LEGACY/VENDOR only | Only legacy/vendor findings | ✅ IGNORE (passed) |
| No findings | All scans clean | ✅ **PASS** |
