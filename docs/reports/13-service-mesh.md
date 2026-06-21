# 13 — Service Mesh

> **Date :** 2026-06-18  
> **Verdict :** ❌ NOT DEPLOYED

---

## Résumé Exécutif

Istio n'est pas déployé sur le cluster. Aucun pod dans `istio-system`. Pas d'injection sidecar, pas de mTLS, pas de VirtualServices actifs.

---

## État Actuel

| Composant | Statut |
|-----------|:------:|
| Istio control plane (istiod) | ❌ Non déployé |
| Ingress gateway | ❌ Non déployé |
| Sidecar injection | ❌ Non actif |
| mTLS | ❌ Non actif |
| Kiali | ❌ Non déployé |

---

## Manifests Disponibles

| Fichier | Description |
|---------|-------------|
| `infra/k8s/istio/operator.yaml` | IstioOperator (161 lines) |
| `infra/k8s/istio/ingress-gateway.yaml` | Gateway + VirtualService (143 lines) |
| `infra/k8s/istio/virtual-services.yaml` | Per-service VS with canary (194 lines) |
| `infra/k8s/istio/destination-rules.yaml` | Traffic policies |
| `infra/k8s/istio/peer-authentication.yaml` | mTLS config |
| `infra/k8s/istio/telemetry.yaml` | OpenTelemetry config |

---

## Recommandations

1. Déployer Istio via `kubectl apply -k infra/k8s/istio/`
2. Activer l'injection sidecar sur le namespace securerag-hub
3. Passer mTLS de PERMISSIVE à STRICT
4. Configurer le canary (5% → 50% → 100%)

---

## Conclusion

Le service mesh est entièrement conçu (6 manifests, 500+ lignes) mais pas déployé. C'est le plus gros gap avec un score de 0%.
