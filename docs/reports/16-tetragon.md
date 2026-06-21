# 16 — Tetragon eBPF Security

> **Date :** 2026-06-18  
> **Verdict :** ❌ NOT DEPLOYED

---

## Résumé Exécutif

Tetragon n'est pas déployé. Les 5 TracingPolicies sont définies mais pas actives. Le CRD `tracingpolicies` n'existe pas sur le cluster.

---

## État Actuel

| Composant | Statut |
|-----------|:------:|
| Tetragon DaemonSet | ❌ Non déployé |
| TracingPolicies (5) | ✅ Définies |
| ServiceMonitor | ✅ Défini |
| Hubble UI | ❌ Non déployé |

---

## TracingPolicies Disponibles

| Policy | MITRE | Détection |
|--------|:-----:|-----------|
| `securerag-detect-kubectl-exec` | T1569 | kubectl exec |
| `securerag-detect-shell` | T1059 | Interactive + reverse shells |
| `securerag-detect-network-tools` | T1105 | curl, wget, nc, nmap |
| `securerag-detect-crypto-miners` | T1496 | XMRig, miner processes |
| `securerag-detect-privilege-escalation` | T1611 | chmod 777, kernel modules |

---

## Métriques

| Métrique | Valeur |
|----------|:------:|
| TracingPolicies | 5 définies |
| Règles de détection | ~100+ patterns |
| Événements/hour | 0 (non déployé) |
| Score | 0% |

---

## Recommandations

1. Installer Tetragon via Helm
2. Appliquer les 5 TracingPolicies
3. Configurer le ServiceMonitor pour Prometheus
4. Tester avec `scripts/tetragon/test-tetragon-policies.sh`

---

## Conclusion

Tetragon est conçu avec des politiques de détection avancées couvrant 5 techniques MITRE. Le déploiement est nécessaire pour activer la détection eBPF runtime.
