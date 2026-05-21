# Admission Tests — Kyverno

> Fixtures lues par `scripts/validate/test-kyverno-admission.sh` (P0-9).

## Convention

- `negative/` — manifests qui **DOIVENT être refusés** par Kyverno en mode Enforce
- `positive/` — manifests qui **DOIVENT être acceptés** (workloads conformes)

Chaque fichier YAML peut contenir un seul resource pour un diagnostic précis.
Le runner exécute `kubectl apply --dry-run=server -f <file>` et vérifie le
verdict attendu via le nom du sous-dossier.

## Exécution

```bash
bash scripts/validate/test-kyverno-admission.sh
# → artifacts/security/kyverno-admission-tests.md
```

Sortie attendue : 100 % des cas dans `positive/` doivent retourner `OK`,
100 % de ceux dans `negative/` doivent retourner `REJECT`.
