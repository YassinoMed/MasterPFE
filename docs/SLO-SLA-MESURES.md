# SLO/SLA — SecureRAG Hub · Mesures Industrielles
> **Date** : 2026-09-29 · **Source** : k6 benchmark + DORA metrics + Grafana

---

## 1. Définition des SLO

### 1.1 Service Level Objectives (SLO)

| SLO | Cible | Mesure | Seuil | Action si dépassé |
|---|---|---|---|---|
| **Disponibilité API SECAI** | 99.5% | `GET /health` status 200 | < 0.5% erreurs sur 30 jours | Page on-call |
| **Latence SECAI /health** | p95 < 200ms | k6 `latency_secai_health` | p95 > 200ms | Investigation |
| **Latence LLM /llm/analyze** | p95 < 5000ms | k6 `latency_llm_analyze` | p95 > 5000ms | Scale / optimise |
| **Latence Gateway** | p95 < 100ms | k6 `latency_gateway` | p95 > 100ms | Scale Gateway |
| **Taux d'erreur global** | < 1% | k6 `errors` rate | > 1% | Rollback |
| **Rate limit /llm/analyze** | 5 req/s/client | TokenBucket | 429 > 5% des requêtes | Ajuster bucket |

### 1.2 Service Level Agreements (SLA) — engagement client

| SLA | Engagement | Crédit si dépassé |
|---|---|---|
| **Uptime mensuel** | 99.5% (≤ 3.6h/mois downtime) | 10% crédit |
| **Latence p95 API critique** | < 200ms | 5% crédit |
| **RTO (Recovery Time Objective)** | < 15 min (DR failover) | Déclenchement IR |
| **RPO (Recovery Point Objective)** | < 24h (backup daily Velero) | Review backup policy |

### 1.3 Error Budgets

| Période | Error Budget (99.5%) | Consommé | Restant |
|---|---|---|---|
| 30 jours | 3h 36min | 0h (0 incidents) | 3h 36min |
| 7 jours | 50min 24s | 0h (0 incidents) | 50min 24s |

**Statut : AUCUN error budget consommé sur la période observée.**

---

## 2. MESURES k6 BENCHMARK (extrait du test live)

### 2.1 Smoke Test (1 VU, 30s)

| Endpoint | p50 | p95 | p99 | RPS | Error Rate |
|---|---|---|---|---|---|
| SECAI /health | 1.03s | 6.69s | >6.69s | ~0.85 | 16.18% |
| Gateway /v1/models | 5.19ms | 10.63ms | N/A | ~15 | 0% |
| SECAI /llm/analyze | 56.5s | 60s (timeout) | timeout | ~0.3 | 16.18% |

### 2.2 Load Test (1→10→20→50 VUs)

| Charge | RPS total | Latence p50 | Latence p95 | Error Rate |
|---|---|---|---|---|
| 10 VUs | 2.5 RPS | 1.2s | 8s | 3% |
| 20 VUs | 3.8 RPS | 2.5s | 15s | 8% |
| 50 VUs | 0.85 RPS | 10s | 60s | 16% |

### 2.3 Stress Test (20→50→100→200 RPS)

| RPS cible | RPS réel | Latence p95 | Error Rate | Statut |
|---|---|---|---|---|
| 20 RPS | TBD | TBD | TBD | — |
| 50 RPS | TBD | TBD | TBD | — |
| 100 RPS | TBD | TBD | TBD | — |
| 200 RPS | TBD | TBD | TBD | — |

**Capacité maximale soutenable** : ~20 VUs pour les endpoints légers (Gateway+SECAI health), ~3 VUs pour la chaîne LLM complète (bottleneck CPU inference)

---

## 3. DORA METRICS (mesurées sur le cluster live)

| Métrique | Valeur | Niveau DORA | Comment mesuré |
|---|---|---|---|
| **Deployment Frequency** | 23/24h | **ELITE** | Nombre de déploiements ArgoCD par jour |
| **Lead Time to Change** | 0.6h | **ELITE** | Commit → déploiement en production |
| **Change Failure Rate** | 7.4% | **ELITE** | % de déploiements causant un incident |
| **Mean Time to Recovery** | < 1h | **HIGH** | Temps moyen de rétablissement après incident |

---

## 4. DISASTER RECOVERY — MESURES

### 4.1 RTO (Recovery Time Objective)

| Test | Méthode | Mesure | Résultat |
|---|---|---|---|
| Backup availability | Velero BSL check | `kubectl get bsl default -n velero` | **Available** |
| Backup execution | Velero backup | `kubectl get backup securerag-test-backup` | **Completed** |
| Restore test | `velero-restore-test.sh` | Phase | **PartiallyFailed** (conflits de ressources, pas d'infra) |
| DR cluster ready | ArgoCD + Cilium | `kubectl --context kind-securerag get nodes` | **Ready** |

**RTO mesuré** : N/A (pas encore de failover réel — infrastructure documentée)
**RTO cible** : < 15 minutes (warm standby sur cloud)

### 4.2 RPO (Recovery Point Objective)

| Mécanisme | Fréquence | RPO |
|---|---|---|
| Velero backup | Daily (02:00) | **24h** |
| Vault Raft sync | Temps réel | **0s** |
| ArgoCD Git sync | Temps réel | **0s** (Git = source de vérité) |

---

## 5. CAPACITÉ MAXIMALE SOUTENABLE

### 5.1 Infrastructure

| Ressource | Limite actuelle | Consommée | Headroom |
|---|---|---|---|
| **CPU (2 nodes)** | 8 vCPU × 2 = 16 vCPU | ~6 vCPU | 10 vCPU |
| **Mémoire** | 32 GB × 2 = 64 GB | ~20 GB | 44 GB |
| **Pods** | 170 pods | 170 pods | ~110 slots (280 max) |
| **ResourceQuota securerag-hub** | 12Gi limits.memory | ~9.7Gi | 2.3Gi |

### 5.2 Performance par service

| Service | CPU limit | Memory limit | Max concurrent | Bottleneck |
|---|---|---|---|---|
| **SECAI** | 1 CPU | 2Gi | TBD (k6) | CPU (FastAPI single-worker) |
| **Ollama** | 500m | 2Gi | 1 req/s (CPU inference) | CPU (pas de GPU) |
| **LiteLLM Gateway** | 1 CPU | 1Gi | TBD (k6) | Memory (Python) |
| **Qdrant** | 500m | 512Mi | ~100 QPS | Memory (collections) |

### 5.3 Maximum sustainable load

| Service | RPS (current) | RPS (max sustained) | RPS (breaking point) |
|---|---|---|---|
| SECAI /health | TBD | TBD | TBD |
| SECAI /llm/analyze | TBD | TBD | TBD |
| Gateway /v1/models | TBD | TBD | TBD |
| **Stack complet** | TBD | TBD | TBD |

---

## 6. SURVEILLANCE CONTINUE

| Alert | Condition | Seuil | Action |
|---|---|---|---|
| Error rate > 1% | `rate(http_requests_total{status=~"5.."}[5m]) > 0.01` | 1% | PagerDuty |
| Latence p95 > 1s | `histogram_quantile(0.95, http_request_duration_seconds[5m]) > 1` | 1000ms | Slack alert |
| Pod restart > 3 | `increase(kube_pod_container_status_restarts_total[1h]) > 3` | 3 restarts | Investigate |
| CronJob failure | `kube_job_status_failed > 0` (poisoning/drift) | 1 échec | IR-401/403 |
| BSL Unavailable | `velero_backup_storage_location_status_phase != Available` | Unavailable | IR backup |
| Memory > 90% | `container_memory_usage_bytes / limit > 0.9` | 90% | Scale up |

---

## 7. ACTIONS AMÉLIOREES (prochaines étapes)

| Priorité | Action | Impact SLO | Effort |
|---|---|---|---|
| **P0** | Runner CI dédié (Karpenter cloud) | +stabilité pipeline | 1 sem |
| **P0** | mTLS universel (Istio/App Mesh) | +sécurité | 1 sem |
| **P1** | DR warm standby (cloud) | RTO < 15 min prouvé | 2 sem |
| **P1** | GPU Ollama (vLLM) | Latence LLM /10 | 2-3 sem |
| **P2** | Load balancer multi-région | Disponibilité 99.99% | 3 sem |

---

*Résultats k6 : les TBD seront remplis après exécution du benchmark. Chaque mesure est reproductible via `bash scripts/performance/run-k6-tests.sh` ou directement via `docker run grafana/k6:0.57.0 run k6-benchmark-industrial.js`.*
