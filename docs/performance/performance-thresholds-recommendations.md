# Performance Thresholds — Recommended Configuration

> SecureRAG Hub — Performance Engineering Guide

## Quality Gate Thresholds (Pipeline-Blocking)

These thresholds are enforced by the `performance-quality-gate.sh` script and the `performanceGate.groovy` Jenkins shared library. **If any gate is breached, the pipeline fails.**

| Gate | Threshold | Rationale |
|---|---|---|
| **p95 Latency** | < 200ms | Industry standard for responsive applications (Google RAIL model) |
| **Error Rate** | < 1% | Ensures 99%+ success rate for end-user requests |
| **Availability** | > 99% | Derived from error rate; aligns with SLO targets |

## Per-Test Type Thresholds

### Smoke Tests (Validation)

| Metric | Threshold | Purpose |
|---|---|---|
| p95 Latency | < 200ms | Verify baseline performance after deploy |
| p99 Latency | < 500ms | Catch outlier regressions |
| Error Rate | < 1% (0.01) | Confirm no deployment-induced errors |
| VUs | 1 | Minimal load, just connectivity |
| Duration | 30s | Quick validation |

### Load Tests (Steady-State)

| Metric | Threshold | Purpose |
|---|---|---|
| p95 Latency | < 200ms | Performance under expected production traffic |
| p99 Latency | < 500ms | Tail latency under normal load |
| Error Rate | < 1% (0.01) | Stability under sustained load |
| VUs | 25–50 | Simulates typical concurrent users |
| Duration | 5min | Enough for statistical significance |

### Stress Tests (Beyond Capacity)

| Metric | Threshold | Purpose |
|---|---|---|
| p95 Latency | < 500ms | Graceful degradation under stress |
| p99 Latency | < 1000ms | Acceptable tail latency at limits |
| Error Rate | < 5% (0.05) | System should not crash |
| VUs | 50 → 300 | Progressive ramp beyond capacity |
| Duration | 7min | Enough to identify breaking points |

### Spike Tests (Burst Traffic)

| Metric | Threshold | Purpose |
|---|---|---|
| p95 Latency | < 2000ms | Acceptable during sudden burst |
| p99 Latency | < 3000ms | Worst-case during spike |
| Error Rate | < 10% (0.10) | Some errors acceptable during spike |
| VUs | 0 → 1000 → 0 | Sudden burst simulation |
| Duration | 2min | Short, sharp load |

### Endurance/Soak Tests (Long-Running Stability)

| Metric | Threshold | Purpose |
|---|---|---|
| p95 Latency | < 200ms | No latency degradation over time |
| p99 Latency | < 500ms | Detect memory leaks / GC pauses |
| Max Latency | < 5000ms | No extreme outliers |
| Error Rate | < 1% (0.01) | Consistent stability |
| Iterations | > 100 | Ensure enough samples |
| VUs | 50 | Sustained moderate load |
| Duration | 30min | Long enough to detect drift |

## Per-Service Recommendations

| Service | p95 Target | p99 Target | Notes |
|---|---|---|---|
| `api-gateway` | < 150ms | < 300ms | Gateway should be fastest (proxy overhead only) |
| `portal-web` | < 200ms | < 500ms | Laravel rendering budget |
| `auth-users` | < 200ms | < 400ms | Auth operations should be fast |
| `chatbot-manager` | < 200ms | < 500ms | CRUD operations |
| `conversation-service` | < 200ms | < 500ms | CRUD operations |
| `audit-security-service` | < 200ms | < 400ms | Logging should not block |

## Environment-Specific Overrides

| Environment | p95 Gate | Error Gate | Availability Gate | Enforcement |
|---|---|---|---|---|
| **Dev/Feature** | < 500ms | < 5% | > 95% | Warning only (non-blocking) |
| **Staging/Recette** | < 200ms | < 1% | > 99% | Blocking |
| **Production** | < 200ms | < 1% | > 99% | Blocking + Rollback |

## Tuning Guidelines

### When to Relax Thresholds
- **Cold starts**: First request after deployment may exceed p95 targets. Use `setup()` in k6 to warm up.
- **AI/LLM endpoints**: If `llm-orchestrator` or `rag-service` are tested, latency will be higher (inference time). Consider separate thresholds.
- **Database-heavy operations**: Bulk exports or reporting APIs may need dedicated thresholds.

### When to Tighten Thresholds
- **After optimization**: If consistent p95 < 100ms, lower the gate to < 150ms to prevent regression.
- **Critical paths**: Auth login and token refresh should target p95 < 100ms.
- **Edge CDN**: If portal-web is behind a CDN, tighten to p95 < 50ms for cached routes.

## Configuration

Thresholds can be overridden via environment variables:

```bash
# Override in Jenkins or locally
P95_THRESHOLD_MS=300 ERROR_RATE_THRESHOLD=0.05 AVAILABILITY_THRESHOLD=95.0 \
  bash scripts/performance/performance-quality-gate.sh
```

Or in the Jenkins shared library:

```groovy
performanceGate(
  p95Threshold: 300,
  errorRateThreshold: 0.05,
  availabilityThreshold: 95.0,
  failOnBreach: false  // warning only
)
```

## References

- [Google RAIL Model](https://web.dev/rail/) — Response within 100ms, Animation 16ms, Idle 50ms, Load 1000ms
- [k6 Thresholds Documentation](https://k6.io/docs/using-k6/thresholds/)
- [Apdex Score](https://en.wikipedia.org/wiki/Apdex) — Application Performance Index
- [SRE Book — SLOs](https://sre.google/sre-book/service-level-objectives/)
