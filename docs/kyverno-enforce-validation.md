# Sécurité Runtime : Kyverno Enforce & Validation Pre-flight

Cette documentation détaille comment le projet garantit que toutes les configurations Kubernetes déployées respectent strictement les normes de sécurité DevSecOps avant même d'atteindre le cluster de production.

## 1. Validation Pre-flight (Avant Déploiement)

Afin d'éviter tout blocage inattendu en production et de maintenir l'état Git propre, un contrôle de validation strict est effectué. Le script `scripts/security/preflight-kyverno.sh` s'assure de deux choses :

1. **Validation locale (Client-Side)** : Utilise l'outil en ligne de commande `kyverno` pour appliquer les politiques du dossier `infra/k8s/policies/kyverno` sur les manifestes générés par `kustomize build`. Cela permet de capturer les violations (ex: conteneur sans `readOnlyRootFilesystem`) sans interagir avec le cluster.
2. **Validation Serveur (Dry-Run)** : Exécute `kubectl apply --dry-run=server --validate=true`. L'API Kubernetes exécute les contrôleurs d'admission webhook (y compris Kyverno déployé sur le cluster) et rejette la commande en cas de violation d'une politique `Enforce`. 

*Note: Ce script est automatiquement exécuté par la pipeline CI/CD (`Jenkinsfile.cd`) avant de commiter les nouveaux digests GitOps.*

## 2. Bascule en mode Enforce

Par défaut, ou lors d'ajouts de nouvelles politiques, celles-se peuvent se trouver en mode `Audit` (qui alerte mais ne bloque pas). Pour aligner le cluster avec la politique Zero-Trust :

Exécutez le script d'application :
```bash
./scripts/security/enforce-kyverno-policies.sh
```

**Ce script va :**
1. Lister toutes les `ClusterPolicy` installées sur le cluster.
2. Appliquer un patch JSON `{"op": "replace", "path": "/spec/validationFailureAction", "value": "Enforce"}` sur chacune d'entre elles.
3. Afficher le nouvel état pour vérification.

### Vérification Manuelle

Pour vérifier l'état des politiques à tout moment :
```bash
kubectl get clusterpolicies -o custom-columns=NAME:.metadata.name,ACTION:.spec.validationFailureAction
```
Toutes les politiques critiques (`verify-cosign-images`, `restrict-image-references`, `require-pod-security`, etc.) doivent afficher `Enforce`.

## 3. Débogage d'une violation

Si le pipeline CI/CD échoue à l'étape "Pre-flight Kyverno" :
1. Consultez les logs Jenkins pour identifier la politique violée.
2. Reproduisez localement :
   ```bash
   kustomize build infra/k8s/overlays/production > temp.yaml
   kyverno apply infra/k8s/policies/kyverno --resource temp.yaml
   ```
3. Corrigez le manifeste source (ex: ajout de `runAsNonRoot: true`) puis relancez le pipeline.
