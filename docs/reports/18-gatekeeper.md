# 18 — OPA Gatekeeper

> **Date :** 2026-06-18  
> **Verdict :** ❌ NOT DEPLOYED

---

## Résumé Exécutif

OPA Gatekeeper n'est pas déployé sur le cluster. Les manifests de configuration existent mais ne sont pas appliqués.

---

## État Actuel

| Composant | Statut |
|-----------|:------:|
| Gatekeeper controller | ❌ Non déployé |
| ConstraintTemplates | ⚠️ Définis, non appliqués |
| Constraints | ⚠️ Définis, non appliqués |

---

## Manifests Disponibles

| Fichier | Description |
|---------|-------------|
| `infra/k8s/opa-gatekeeper/deployment.yaml` | Gatekeeper controller |
| `infra/k8s/opa-gatekeeper/constraints/` | Templates et constraints |

---

## Recommandations

1. Déployer OPA Gatekeeper via Helm
2. Appliquer les ConstraintTemplates
3. Appliquer les Constraints
4. Définir des policies de réplication

---

## Conclusion

OPA Gatekeeper est conçu mais pas déployé. Kyverno couvre déjà les besoins d'admission, donc l'urgence est modérée.
