# 23 — Vault & External Secrets Operator

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

**Vault est déployé** (vault-0, 30h uptime). **External Secrets Operator n'est pas déployé** (CRD externalsecret non trouvé). Les secrets sont gérés via un Secret Opaque Kubernetes.

---

## Vault

| Métrique | Valeur |
|----------|:------:|
| Pod | vault-0 |
| Status | Running |
| Uptime | 30h |
| Namespace | vault |
| Service | vault.vault.svc:8200 |
| Mode | Dev (Raft HA config ready) |

---

## External Secrets Operator

| Composant | Statut |
|-----------|:------:|
| ESO Controller | ❌ Non déployé |
| ClusterSecretStore | ⚠️ Config prête |
| ExternalSecrets | ⚠️ Config prête |
| CRD externalsecret | ❌ Non installé |

---

## Secrets Actuels

| Secret | Type | Data |
|--------|:----:|:----:|
| securerag-common-secrets | Opaque | 6 keys |

---

## Scripts Disponibles

| Script | Fonction | Statut |
|--------|----------|:------:|
| `scripts/deploy/deploy-vault-and-eso.sh` | Déploiement complet | ✅ Prêt |
| `scripts/secrets/seed-vault-secrets.sh` | Initialisation | ✅ Prêt |
| `scripts/vault/enable-dynamic-secrets.sh` | DB dynamic secrets | ✅ Créé |
| `scripts/vault/rotate-dynamic-credentials.sh` | Rotation | ✅ Créé |

---

## Recommandations

1. Déployer ESO : `helm upgrade --install external-secrets external-secrets/external-secrets`
2. Appliquer ClusterSecretStore
3. Créer les ExternalSecrets pour chaque service
4. Migrer les secrets du Secret Opaque vers Vault
5. Activer les dynamic secrets pour PostgreSQL

---

## Conclusion

Vault est opérationnel. L'installation d'ESO et la migration des secrets vers Vault sont les prochaines étapes pour une gestion centralisée des secrets.
