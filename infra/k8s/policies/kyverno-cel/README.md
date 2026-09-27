# Kyverno CEL Migration — Statut (Phase 14)

**Date**: 2026-09-27

## État actuel

Kyverno v1.19.1 installé supporte uniquement:
- `ClusterPolicy` (v1) — **dépréciée** mais fonctionnelle
- `ImageValidatingPolicy` (CEL) — pour la vérification d'images

Le CRD `ValidatingPolicy` (CEL général) n'est **pas disponible** dans cette version.
Il nécessite Kyverno ≥ 2.0.

## Plan de migration

| Policy v1 actuelle | Équivalent CEL | Statut |
|---|---|---|
| disallow-root-containers | ValidatingPolicy (CEL) | Créée dans ce repo, pas déployable (CRD absent) |
| disallow-host-network | ValidatingPolicy (CEL) | À créer après upgrade Kyverno |
| require-workload-controls | ValidatingPolicy (CEL) | À créer |
| restrict-image-references | ImageValidatingPolicy | **Faisable** (CRD disponible) |
| restrict-service-exposure | ValidatingPolicy (CEL) | À créer |
| restrict-volume-types | ValidatingPolicy (CEL) | À créer |
| audit-cleartext-env-values | ValidatingPolicy (CEL) | À créer |
| verify-cosign-images | ImageValidatingPolicy | **Faisable** (CRD disponible) |

## Actions requises

1. **Upgrade Kyverno ≥ 2.0** pour obtenir le CRD ValidatingPolicy
2. Les 8 policies v1 continuent de fonctionner (pas de rupture)
3. Migrer progressivement (1 policy à la fois, test, enforce, supprimer v1)
4. Le fichier `disallow-root-containers.yaml` est prêt comme template

## Détail : ce qui est faisable MAINTENANT

### ImageValidatingPolicy (disponible)
```yaml
apiVersion: policies.kyverno.io/v1
kind: ImageValidatingPolicy
metadata:
  name: securerag-cel-verify-images
spec:
  validationActions: []
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  imageRules:
    - glob: "**"
  validations:
    - expression: >-
        images.containers.map(image, image.attestations).all(a, a > 0)
      message: "Image must be signed"
```

---
*Voir ROADMAP-MATURITE-DEVSECOPS.md Phase 14 pour le plan complet*
