# Velero Restore Test Report

**Date**: 2026-09-29T09:13:42Z
**Backup testé**: securerag-test-backup
**Restore name**: restore-test-20260929-090808
**Namespace de test**: securerag-restore-test

## Résultats

| Métrique | Valeur |
|---|---|
| Phase de restauration | PartiallyFailed |
| Ressources restaurées | 0 |
| PVCs restaurés | 0 |
| Secrets restaurés | 0 |

## Verdict

✗ RESTAURATION ÉCHOUÉE — voir les logs Velero

## Vérifications de non-régression

- [ ] Namespace de production intact
- [ ] Aucune donnée perdue
- [ ] Aucun service interrompu

---
*Généré par scripts/backup/velero-restore-test.sh*
