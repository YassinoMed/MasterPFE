# 29 — Chaos Engineering

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ NOT DEPLOYED

---

## Résumé Exécutif

Chaos Mesh n'est pas déployé. Les 6 expériences sont définies (pod-kill, network-latency, cpu-stress, memory-stress, dns-failure, postgres-outage) mais pas exécutées.

---

## Expériences Définies

| Expérience | Type | Schedule | Statut |
|-----------|:------|:--------:|:------:|
| pod-kill | PodChaos | Cron | ⚠️ Défini |
| network-latency | NetworkChaos | Cron | ⚠️ Défini |
| cpu-stress | StressChaos | Cron | ⚠️ Défini |
| memory-stress | StressChaos | Cron | ⚠️ Défini |
| dns-failure | DNSChaos | Cron | ⚠️ Défini |
| postgres-outage | PodChaos | Cron | ⚠️ Défini |

---

## Scripts Disponibles

| Script | Lignes | Description |
|--------|:------:|-------------|
| `scripts/chaos/run-chaos-pipeline.sh` | 399 | Pipeline complet |
| `scripts/chaos/chaos-engineering.sh` | ~200 | Script principal |
| `scripts/chaos/chaos-smoke-test.sh` | ~80 | Test rapide |
| `scripts/chaos/chaos-report.sh` | ~100 | Génération rapport |
| `scripts/chaos/pod-delete-and-prove.sh` | ~150 | Pod delete + auto-réparation |

---

## Matrice de Résilience

| Scénario | Auto-Réparation | Mesuré |
|----------|:---------------:|:------:|
| Pod failure | ✅ Kubernetes | Non mesuré |
| CPU stress | ✅ HPA | Non mesuré |
| Network latency | ❌ Chaos Mesh requis | Non testé |
| DNS failure | ❌ Chaos Mesh requis | Non testé |
| PostgreSQL outage | ❌ Chaos Mesh requis | Non testé |

---

## Recommandations

1. Déployer Chaos Mesh : `kubectl apply -k infra/k8s/chaos/`
2. Exécuter `pod-delete` d'abord (le plus sûr)
3. Automatiser les expériences en CI (nightly)
4. Mesurer MTTR et disponibilité

---

## Conclusion

Les expériences sont conçues mais pas exécutées. Score Chaos : 100% (conception) × 0% (exécution) = 0%.
