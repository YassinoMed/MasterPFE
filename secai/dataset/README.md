# SECAI Dataset — Tests annotés de détection de vulnérabilité

## Labelling rules

- `positive` : contient une vulnérabilité exploitable (cat 1-20)
- `negative` : contient du code sécuritaire (nulipsum)
- `borderline` : probable vulnérabilité mais non-exploitable (jeu evaluation)

Ce fichier est utilisé par `secai/pipelines/evaluation.py` pour mesurer TP/TN/FP/FN
et produire `metrics.json`.

**Politique** : si le modèle dit `VULNERABILITÉ` alors que label = negative → FP.
Si le modèle dit `N/V` alors que label = positive → FN (pire).
Taux de faux négatifs = FN / (TP+FN)
