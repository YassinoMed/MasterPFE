# Workflow GitOps & Automatisation du Déploiement

Cette documentation décrit la cinématique de déploiement de SecureRAG Hub selon le paradigme GitOps, en conformité stricte avec l'architecture DevSecOps cible.

## 1. Principes Fondamentaux

- **Déploiement Déclaratif** : Plus aucun appel impératif (`kubectl apply`) n'est autorisé dans les pipelines d'intégration continue ou de déploiement (CI/CD).
- **Single Source of Truth** : Le dépôt Git (branche `main`) représente l'état désiré exact du cluster.
- **Synchronisation Automatique** : Argo CD est l'unique composant habilité à modifier l'état du cluster Kubernetes.
- **Images Immuables** : Les tags mutables (ex: `dev`, `release`) sont remplacés par des empreintes cryptographiques strictes (Digests SHA256) avant tout déploiement.

## 2. Le Pipeline CI/CD (Le "Push" Git)

Le pipeline de déploiement continu (`Jenkinsfile.cd`) a pour seul objectif de valider les artefacts, de les signer, et de demander à l'infrastructure d'utiliser ces nouveaux artefacts.

**Étapes du Pipeline :**
1. **Validation & Sécurité** : L'image candidate est scannée (Trivy), signée (Cosign), et le SBOM est généré et attesté.
2. **Génération du Digest** : Une fois vérifiée, l'image est promue dans le registre cible. Le digest SHA256 immuable de l'image est récupéré.
3. **Mise à jour Kustomize** : Le script `scripts/gitops/update-image-digest.sh` modifie le fichier `infra/k8s/overlays/production/kustomization.yaml` pour injecter le nouveau digest.
4. **Git Commit & Push** : Le script commite ce changement avec le message `gitops: update digest for <service> to <digest>` et le pousse sur la branche `main`. 
5. *Fin du pipeline Jenkins.*

## 3. Argo CD (Le "Pull" GitOps)

Argo CD observe en continu le dépôt Git.

1. **Détection de Dérive (Drift Check)** : Dès que le pipeline CD pousse le nouveau digest, Argo CD détecte une différence entre l'état de Git (le nouveau digest) et l'état du cluster (l'ancien digest).
2. **Synchronisation Automatique (Auto-Sync)** : 
   - La `syncPolicy` de l'application `application-production.yaml` est configurée avec `automated: { prune: true, selfHeal: true }`.
   - Argo CD applique (via Server-Side Apply) les nouveaux manifestes Kustomize rendus.
3. **Déploiement Kubernetes** : Le cluster Kubernetes déclenche un *Rolling Update* pour remplacer les anciens pods par les nouveaux pods utilisant le digest mis à jour.
4. **Self-Heal** : Si un administrateur tente de modifier manuellement un paramètre (ex: modifier le tag de l'image via `kubectl edit`), Argo CD corrigera immédiatement cette dérive en réappliquant l'état du Git.

## 4. Vérification de l'état

Vous pouvez vérifier le statut de la synchronisation via :
- **Interface Utilisateur Argo CD** : `https://argocd.securerag.local`
- **CLI** : `argocd app get securerag-production`
- **Kubernetes** : `kubectl get deploy -n securerag-hub -o wide`

> **Note de Sécurité** : Les contrôleurs d'admission Kyverno bloqueront toute tentative d'Argo CD ou d'un utilisateur de déployer une image si la politique `verify-cosign-images` (vérification de signature) n'est pas respectée pour le nouveau digest.
