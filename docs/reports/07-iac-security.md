# 07 — IaC Security

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

Checkov et kube-score ne sont pas installés sur la machine de test. Conftest policies existent mais n'ont pas été exécutées dans ce cycle. Trivy misconfig a analysé les manifests K8s avec 12 findings (11 MEDIUM, 1 HIGH).

---

## Résultats

| Outil | Statut | Findings |
|-------|:------:|:--------:|
| Checkov | ❌ Non installé | — |
| kube-score | ❌ Non installé | — |
| Conftest | ⚠️ Policies prêtes, non exécutées | — |
| Trivy misconfig | ✅ Exécuté | 12 (0 CRITICAL) |

---

## Détail Trivy Misconfig

| Sévérité | Nombre |
|:--------:|:------:|
| CRITICAL | 0 |
| HIGH | 1 (Litmus pods/exec) |
| MEDIUM | 11 (registries, tags, RBAC) |

---

## Conftest Policies Disponibles

| Fichier | Type |
|---------|------|
| `security/conftest/conftest-policies.yaml` | 7 Rego policies |

---

## Recommandations

1. Installer Checkov et kube-score dans le pipeline CI
2. Ajouter stage `CI: Policy-as-Code (Conftest)` dans Jenkins
3. Configurer Trivy misconfig en gate bloquante pour CRITICAL/HIGH
4. Documenter les exceptions Litmus et fichiers de test

---

## Conclusion

Le score IaC est limité par l'absence d'outils sur la machine de test. Les manifests sont valides (kustomize build ok, Kyverno enforce ok). L'ajout de Checkov/kube-score/Conftest dans le pipeline CI est la priorité.
