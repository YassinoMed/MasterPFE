# Intégration du Security Backlog (GitHub Issues)

Ce document décrit comment configurer Jenkins pour qu'il ouvre automatiquement une issue (ticket) dans le dépôt GitHub en cas d'échec des barrières de sécurité (Quality Gates) de la CI.

## 1. Principe de fonctionnement

1. Si la pipeline CI (`Jenkinsfile`) échoue (ex: échec Semgrep, Gitleaks, Trivy, ou Kube-score), le bloc `post { failure }` est déclenché.
2. Le script `scripts/ci/notify-security-backlog.sh` est exécuté.
3. Il utilise l'API REST de GitHub pour créer une nouvelle issue dans le projet, labellisée `security` et `bug`.
4. Le corps de l'issue contient les informations de l'échec et le lien direct vers le build Jenkins pour investigation.

## 2. Création du Token d'Accès Personnel (PAT) GitHub

Pour que Jenkins puisse créer des issues, il a besoin d'un token d'accès :
1. Sur GitHub, allez dans vos **Settings** de profil > **Developer settings** > **Personal access tokens** > **Tokens (classic)** (ou Fine-grained).
2. Cliquez sur **Generate new token**.
3. Nommez-le (ex: `Jenkins Security Backlog Bot`).
4. Cochez les permissions : `repo` (Full control of private repositories) pour pouvoir créer des issues.
5. Générez le token et copiez-le. **Attention, il ne sera visible qu'une seule fois**.

## 3. Configuration dans Jenkins (Credentials)

Le token ne doit jamais être en clair dans le code. Il doit être stocké de manière sécurisée dans Jenkins :
1. Allez sur **Jenkins** > **Manage Jenkins** > **Credentials**.
2. Sélectionnez le store **System** puis le domaine **Global credentials (unrestricted)**.
3. Cliquez sur **Add Credentials**.
4. Remplissez le formulaire :
   - **Kind** : `Secret text`
   - **Scope** : `Global`
   - **Secret** : *(Collez votre Token GitHub généré précédemment)*
   - **ID** : `github-token-secret` (⚠️ C'est l'ID utilisé dans le `Jenkinsfile`, il doit correspondre exactement).
   - **Description** : Token d'accès GitHub pour la création d'issues de sécurité.
5. Sauvegardez.

Le pipeline utilisera la fonction `withCredentials` pour injecter ce token en tant que variable d'environnement (`GITHUB_TOKEN`) au moment de l'exécution du script bash.
