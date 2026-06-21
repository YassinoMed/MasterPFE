# Guide de Migration : Option B (Local) vers Option A (Sigstore Public)

Ce guide décrit la procédure pour migrer d'une architecture de signature sans clé locale (Option B - Keycloak, Fulcio, Rekor dans le cluster Kind) vers l'infrastructure publique globale **Sigstore.dev** (Option A) idéale pour des déploiements Cloud en production (par ex. GitHub Actions, GitLab CI).

---

## 1. Principe de la Migration

L'infrastructure publique Sigstore élimine le besoin de gérer vos propres serveurs Keycloak, Fulcio et Rekor.

```
+-------------------------------------------------------------+
|                      FLUX CLOUD EN PRODUCTION               |
|                                                             |
|   GitHub Actions (OIDC Provider)                            |
|         |                                                   |
|         v (Exchanges OIDC token)                            |
|   Fulcio Public (https://fulcio.sigstore.dev)               |
|         |                                                   |
|         v (Issues X.509 ephemeral certificate)              |
|   Cosign (signs image & uploads to Rekor Public)            |
|         |                                                   |
|         v (Transparency Log entry)                          |
|   Rekor Public (https://rekor.sigstore.dev)                 |
+-------------------------------------------------------------+
```

---

## 2. Configuration du Pipeline CI/CD (GitHub Actions)

Dans GitHub Actions, l'obtention du token OIDC est automatique. Il vous suffit d'accorder les permissions nécessaires au workflow de build.

### Étape 1 : Configurer les Permissions GitHub Actions
Ajoutez le bloc `permissions` suivant dans votre fichier de workflow `.github/workflows/release.yml` :

```yaml
permissions:
  contents: read
  id-token: write # Requis pour récupérer le jeton d'identité OIDC
  packages: write # Requis pour pousser l'image et la signature
```

### Étape 2 : Écrire le Stage de Signature dans le Workflow
Utilisez la commande Cosign classique. Cosign détectera automatiquement le jeton OIDC fourni par l'environnement GitHub Actions et utilisera par défaut l'infrastructure publique Sigstore :

```yaml
- name: Installer Cosign
  uses: sigstore/cosign-installer@v3.5.0

- name: Signer l'image Docker (Keyless)
  run: |
    cosign sign --yes ghcr.io/yassinomed/masterpfe/auth-users:latest
```

> [!NOTE]
> Le drapeau `--yes` est requis pour confirmer la publication de l'entrée de journal dans le journal de transparence public de Rekor.

---

## 3. Configuration du Pipeline CI/CD (GitLab CI)

Pour GitLab CI, l'authentification OIDC se configure via l'utilisation des jetons `id_tokens`.

Dans votre `.gitlab-ci.yml` :

```yaml
sign_image:
  stage: release
  image: 
    name: alpine/git:latest
  id_tokens:
    SIGSTORE_ID_TOKEN:
      aud: sigstore
  variables:
    COSIGN_EXPERIMENTAL: "1"
  script:
    - apk add --no-cache curl jq
    - curl -LO https://github.com/sigstore/cosign/releases/download/v2.2.3/cosign-linux-amd64
    - chmod +x cosign-linux-amd64 && mv cosign-linux-amd64 /usr/local/bin/cosign
    - cosign sign --identity-token $SIGSTORE_ID_TOKEN --yes registry.gitlab.com/yassinomed/masterpfe/auth-users:latest
```

---

## 4. Politique Kyverno de Production (Admission Control)

Dans le cluster Kubernetes de production, mettez à jour votre politique Kyverno pour utiliser les serveurs publics et valider l'identité GitHub / GitLab de votre pipeline.

### Exemple de Politique Kyverno pour GitHub Actions

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature-public-keyless
spec:
  validationFailureAction: Enforce
  background: false
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-public-keyless
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - securerag-hub
      verifyImages:
        - imageReferences:
            - "ghcr.io/yassinomed/masterpfe/*"
          attestors:
            - entries:
                - keyless:
                    # Plus besoin de spécifier url (Fulcio) ni rekor.url car les valeurs par défaut publiques sont utilisées.
                    issuer: https://token.actions.githubusercontent.com
                    subject: https://github.com/YassinoMed/MasterPFE/.github/workflows/cd.yml@refs/heads/main
```

> [!IMPORTANT]
> Le champ `subject` correspond à l'URI du workflow GitHub exécuté. Cela garantit que seules les images construites par vos propres pipelines officiels sur la branche `main` peuvent être déployées dans le cluster.
