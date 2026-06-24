# Gouvernance des Policies (SecureRAG Hub)

Ce document décrit la structure unifiée de gestion des politiques de sécurité au sein du cluster Kubernetes.

## Hiérarchie des Policies

La sécurité est appliquée selon le modèle de Défense en Profondeur (Defense in Depth) via deux outils distincts mais complémentaires : **Pod Security Admission (PSA)** et **Kyverno**.

### 1. Pod Security Admission (PSA) - Le Socle (Baseline)
PSA est une fonctionnalité native de Kubernetes.
- **Rôle** : Rejet strict des comportements système les plus dangereux (escalade de privilèges, accès au réseau hôte `hostNetwork`, accès au PID de l'hôte, montage de dossiers hôtes `hostPath`).
- **Application** : Il est appliqué globalement sur les namespaces via des labels (voir `infra/k8s/policies/psa/securerag-hub-psa.yaml`).
- **Niveau Configuré** : `enforce: baseline`. Le niveau `restricted` est configuré en mode `audit` pour générer des avertissements natifs.

### 2. Kyverno - Les Règles Avancées (Advanced)
Kyverno est un moteur de politiques (Policy Engine) utilisé pour des règles que PSA ne peut pas gérer nativement (ex: signatures d'images) ou pour obtenir une granularité fine avec des rapports (PolicyReports).
- **Rôle** : Valider les signatures Cosign, forcer l'usage d'utilisateurs non-root, forcer la présence de probes, etc.
- **Application** : Déployé via GitOps depuis `infra/k8s/policies/kyverno`.

## Structure du Dépôt

```
infra/k8s/policies/
├── psa/                    # Configuration native (labels sur Namespaces)
├── kyverno/
│   ├── audit/              # Nouvelles règles en observation (non bloquantes)
│   └── enforce/            # Règles de conformité strictes (bloquantes)
└── cilium/                 # Politiques réseaux (Zero Trust)
```

## Cycle de Vie d'une Nouvelle Politique

Pour garantir le principe du *Zero Downtime*, toute nouvelle politique suit un cycle de vie strict :
1. **Création en mode Audit** : La politique (ex: `disallow-root-containers.yaml`) est créée dans le dossier `kyverno/audit/` avec `validationFailureAction: Audit`.
2. **Déploiement GitOps** : ArgoCD déploie la règle sans impacter la production.
3. **Analyse des Reports** : Les rapports (`PolicyReport`) sont analysés dans l'interface de monitoring ou via `kubectl get polr`.
4. **Correction des Workloads** : Les déploiements non conformes sont corrigés.
5. **Passage en Enforce** : La règle est déplacée dans `kyverno/enforce/` avec `validationFailureAction: Enforce` pour bloquer les futures violations.

## Prévention des Conflits
Pour éviter que PSA et Kyverno rejettent le même conteneur avec deux messages d'erreur différents, **les règles qui relèvent du socle "Restricted" (ex: root containers, seccomp) sont déléguées à Kyverno en mode Audit**, permettant aux équipes de développement d'avoir un retour explicite de Kyverno (avec des messages personnalisés) plutôt qu'un rejet natif brutal de l'API Kubernetes.
