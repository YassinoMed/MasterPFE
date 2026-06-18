# 24 — Secret Rotation

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

Les CronJobs de rotation sont définis mais pas exécutés. Aucune rotation de secrets n'a eu lieu sur ce cluster.

---

## CronJobs Définis

| CronJob | Schedule | Fonction | Statut |
|---------|----------|----------|:------:|
| `rotate-jenkins-credentials` | Every 3 months (1st @06:00) | Rotation credentials Jenkins | ⚠️ Défini |
| `rotate-database-credentials` | Every 15 days @08:00 | Rotation PostgreSQL | ⚠️ Défini |
| `dynamic-secret-renewer` | Every 30 min | Renouvellement leases Vault | ✅ Créé |

---

## Scripts de Rotation

| Script | Fonction |
|--------|----------|
| `scripts/vault/rotate-dynamic-credentials.sh` | Rotation credentials dynamiques |
| `scripts/vault/enable-dynamic-secrets.sh` | Activation engine DB |
| `scripts/secrets/rotate-all-credentials.sh` | Rotation complète |

---

## Recommandations

1. Vérifier que les CronJobs sont appliqués sur le cluster
2. Tester la rotation manuellement
3. Valider que les nouveaux credentials fonctionnent après rotation
4. Documenter la procédure d'urgence si la rotation échoue

---

## Conclusion

Les CronJobs de rotation sont configurés mais le déploiement d'ESO et l'activation des dynamic secrets sont des prérequis.
