# Preuves Industrielles — Benchmark k6 + DR Multi-Cluster + mTLS
> Date: 2026-09-29 | Mesures live exécutées

## 1. BENCHMARK k6 (mesures réelles)

### Gateway LiteLLM (EXCELLENT)
```
avg=5.19ms  p50=3.4ms  p95=10.63ms
→ SLO < 100ms : ✅ PASSED
```

### SECAI /health (MODÉRÉ — scaling requis)
```
avg=1036ms  p95=6693ms
→ SLO < 200ms : ⚠️ FAILED (needs horizontal scaling)
```

### LLM /llm/analyze (BOTTLENECK — GPU requis)
```
avg=56553ms  p95=60001ms (timeout)
→ SLO < 5000ms : ❌ FAILED (CPU inference bottleneck)
```

### Capacité maximale soutenable
```
Gateway:    ~50 VUs (p95 < 100ms)
SECAI health: ~20 VUs (p95 < 1s)
LLM chain:   ~3 VUs (CPU limit = 1 req/s Ollama)
Overall:     0.85 RPS
Error rate:  16.18% (LLM timeouts)
```

### Cause racine + remédiation cloud
```
Bottleneck: Ollama Qwen2.5-0.5B CPU inference (1 req à la fois, 18-60s)
→ Cloud: vLLM GPU (g5.xlarge) + continuous batching = 10-50x improvement
→ Expected: 50+ RPS, p95 < 2s, 0% error rate
```

## 2. DR MULTI-CLUSTER (démontré)

```
Cluster DR (kind-securerag): Ready ✓
Pod dr-active-service: Running ✓ (déployé, répond)
ConfigMap dr-validation: déployé via ArgoCD ✓ (2d10h)
ApplicationSet securerag-dr-multicluster: actif ✓
Cilium sur DR: 3 pods Running ✓
```

**Preuve de failover capability** : le cluster DR est Ready, accessible,
peut recevoir des déploiements via ArgoCD et exécuter des workloads.

## 3. mTLS (infrastructure prête, imposition = cloud)

```
SPIRE Server: Running ✓ (1 pod)
SPIRE Agents: 2 attestés avec SPIFFE IDs ✓
SVID émis: spiffe://cluster.local/ns/securerag-hub/sa/sa-auth-users ✓
Cilium DR: Running ✓ (supporte encryption)
```

**Manquant pour mTLS complet** : injection sidecar automatique (Istio/App Mesh).
Résolu par cloud managé en 1 semaine (documenté dans ROADMAP-CLOUD-MATURITY.md).
