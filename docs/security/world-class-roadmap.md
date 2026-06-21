# World-Class DevSecOps Roadmap — SecureRAG Hub

**Objectif :** 96/100 — Niveau World-Class  
**Statut actuel :** 86/100 (post-P0) → 96/100 (cible)  
**Dernière mise à jour :** Juin 2026

---

## Score avant/après

| Catégorie | Avant (Juin) | Après P0 | Après P1 | Après P2 | Cible |
|-----------|:-----------:|:--------:|:--------:|:--------:|:-----:|
| Secrets Management | 1.5 | 8.0 | 9.0 | 10.0 | 10.0 |
| Pipeline Hardening | 7.0 | 8.5 | 9.0 | 9.5 | 10.0 |
| SAST | 9.0 | 9.0 | 9.5 | 10.0 | 10.0 |
| SCA | 6.0 | 7.5 | 8.5 | 9.5 | 10.0 |
| IaC Security | 6.0 | 8.0 | 9.0 | 9.5 | 10.0 |
| Runtime Security | 5.0 | 7.0 | 8.5 | 9.5 | 10.0 |
| Supply Chain | 7.5 | 8.5 | 9.5 | 10.0 | 10.0 |
| K8s Security | 7.5 | 8.5 | 9.0 | 9.5 | 10.0 |
| Observabilité | 8.5 | 9.0 | 9.5 | 10.0 | 10.0 |
| Backup & DR | 1.0 | 7.0 | 8.0 | 9.0 | 10.0 |
| **TOTAL** | **59** | **81** | **90** | **96** | **100** |

---

## Plan d'exécution

### P0 — Fondations (Semaine 1)

| # | Action | Responsable | Durée |
|:-:|--------|:-----------:|:-----:|
| 1 | Déployer Vault : `kubectl apply -k infra/k8s/vault/` + `bash scripts/secrets/initialize-vault.sh` | Platform | 2h |
| 2 | Déployer ESO : `bash scripts/deploy/deploy-vault-and-eso.sh` | Platform | 1h |
| 3 | Supprimer les 11 fichiers credentials de `infra/jenkins/secrets/` | Platform | 15min |
| 4 | Fixer permissions 777→700 sur le dossier secrets | Platform | 5min |
| 5 | Remplacer WAZUH_PASSWORD par variable d'environnement | Platform | 30min |
| 6 | Déployer Velero + MinIO : `bash scripts/deploy/deploy-velero.sh` | Platform | 2h |

**Score cible post-P0 : 81/100**

### P1 — Hardening (Semaine 2)

| # | Action | Responsable | Durée |
|:-:|--------|:-----------:|:-----:|
| 7 | Intégrer Falco + Tetragon dans le quality gate | Security | 1h |
| 8 | Intégrer Checkov dans le quality gate (parsing JUnit) | Security | 1h |
| 9 | Épingler tous les tags `:latest` (11+ manifests) | Platform | 2h |
| 10 | Nettoyer `COSIGN_ALLOW_INSECURE_REGISTRY` des scripts | Security | 1h |
| 11 | Documenter les 14 CVEs du `.trivyignore` | Security | 30min |
| 12 | Activer les feature flags clés (Cilium, OPA) | Platform | 1h |

**Score cible post-P1 : 90/100**

### P2 — Excellence (Semaine 3-4)

| # | Action | Responsable | Durée |
|:-:|--------|:-----------:|:-----:|
| 13 | Créer dashboards Grafana Trivy/Checkov/Semgrep | Observability | 2h |
| 14 | Ajouter Prometheus rules (VaultDown, ESOFailure, BackupFailure) | Observability | 1h |
| 15 | Créer Jenkins Shared Library (vars/*.groovy) | Platform | 2h |
| 16 | Mettre en place backup Jenkins automatique | Platform | 1h |
| 17 | Activer la rotation automatique des secrets (CronJob) | Security | 30min |
| 18 | Ajouter SLSA provenance + attestations | Security | 2h |
| 19 | Ajouter stage Backup Validation dans Jenkins (hebdo) | Platform | 1h |
| 20 | Ajouter SLO/SLI dashboards + error budget | Observability | 2h |

**Score cible post-P2 : 96/100 — WORLD-CLASS**

---

## Architecture cible

```
┌─────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                            │
│  Portal-Web  Auth-Users  Chatbot  Conversation  Audit-Security  │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│              KUBERNETES NATIVE SECURITY                          │
│  PSA: restricted │ NetworkPolicies │ Kyverno Enforce (7)        │
│  OPA Gatekeeper (6 Rego) │ runAsNonRoot │ noPrivilege           │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                RUNTIME + SUPPLY CHAIN                            │
│  Falco (13 rules) │ Tetragon (3 policies) │ Cilium/Hubble       │
│  Cosign Keyless │ SBOM CycloneDX │ Syft │ Grype                 │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│              SECRETS MANAGEMENT                                  │
│  Vault (KV v2 + Dynamic) ← ESO ← ClusterSecretStore            │
│  SOPS + age (GitOps bootstrap) │ Rotation CronJob (30-90d)     │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│              OBSERVABILITY + DR                                  │
│  Prometheus (10+ rules) │ Grafana (15 dashboards)               │
│  Velero (daily/weekly/monthly) │ MinIO S3                       │
│  Jenkins Backup (nightly) │ DR Test (weekly CI)                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Vérification

```bash
# 1. Vault
kubectl exec -n vault vault-0 -- vault status | grep -c "Sealed: false"
# Expected: 1

# 2. ESO
kubectl get externalsecret -A | grep -c READY
# Expected: 3+ (jenkins, database, grafana)

# 3. Velero
velero backup get | grep -c Completed
# Expected: 1+

# 4. Falco
kubectl get pods -n falco | grep -c Running
# Expected: 1+

# 5. Checkov dans QG
grep -c "checkov" scripts/ci/secure-quality-gate.sh
# Expected: > 0

# 6. Pas de :latest
grep -Rsn ":latest" infra/k8s/ --include='*.yaml' | grep -v '!*:latest' | grep -v 'restrict-image' | wc -l
# Expected: 0

# 7. Pas de COSIGN_ALLOW_INSECURE
grep -rn "COSIGN_ALLOW_INSECURE" scripts/release/ | wc -l
# Expected: 0

# 8. Pas de || true dans pipelines
grep -c '|| true' Jenkinsfile Jenkinsfile.cd Jenkinsfile.recette
# Expected: ≤ 3 (acceptable: kubectl annotate, sysctl, iptables)
```
