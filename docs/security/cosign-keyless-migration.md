# Migration Cosign Keyless (OIDC) — SecureRAG Hub

## Statut : ROADMAP

Ce document décrit la stratégie de migration de la signature d'images Cosign basée sur une paire de clés (key-pair) vers le mode **keyless** utilisant OpenID Connect (OIDC) via Sigstore Fulcio/Rekor.

---

## 1. Problème Actuel

L'infrastructure actuelle utilise une **clé privée Cosign** stockée comme Jenkins credential (`cosign-private-key` + `cosign-password`). Cette approche présente des risques :

| Risque | Impact | Probabilité |
|--------|--------|-------------|
| Compromission de la clé privée Jenkins | L'attaquant peut signer des images malveillantes acceptées par Kyverno | Moyen |
| Rotation complexe | Nécessite mise à jour de Jenkins + toutes les policies Kyverno + re-signature des images existantes | Élevé |
| Pas d'attribution d'identité | La signature prouve l'intégrité mais pas *qui* a signé (n'importe quel détenteur de la clé) | Élevé |

## 2. Solution : Cosign Keyless via OIDC

### Principe

En mode keyless, Cosign utilise un **certificat éphémère** émis par Fulcio (Sigstore CA) basé sur l'identité OIDC du signataire (GitHub Actions, Jenkins OIDC, Google Workload Identity). La preuve de signature est enregistrée dans **Rekor** (transparency log).

```
Pipeline CI/CD ──▶ OIDC Provider ──▶ Fulcio (certificat éphémère)
                                         │
                                         ▼
                                    Cosign sign ──▶ Rekor (log de transparence)
                                         │
                                         ▼
                                   OCI Registry (signature attachée)
```

### Avantages

- **Pas de clé privée à gérer** : élimine le risque de compromission
- **Attribution d'identité** : la signature est liée à l'identité OIDC (ex: `https://github.com/YassinoMed/MasterPFE/.github/workflows/build-sign.yml`)
- **Traçabilité** : chaque signature est enregistrée dans Rekor (audit trail public)
- **Rotation automatique** : certificats éphémères, pas de rotation manuelle

## 3. Plan de Migration

### Étape 1 : Signature Keyless dans GitHub Actions (déjà supporté)

Le workflow `.github/workflows/build-sign.yml` utilise déjà `cosign sign --yes` qui active le mode keyless quand `id-token: write` est configuré.

```yaml
# .github/workflows/build-sign.yml (existant)
permissions:
  id-token: write    # ← Active OIDC pour Cosign keyless
```

```bash
# Commande de signature keyless (déjà en place)
cosign sign --yes \
  "${REGISTRY}/${IMAGE}@${DIGEST}"
```

### Étape 2 : Signature Keyless dans Jenkins

Jenkins supporte OIDC via le plugin [OIDC Provider](https://plugins.jenkins.io/oidc-provider/). Configuration :

```groovy
// Jenkinsfile.cd — futur stage de signature keyless
stage('Sign Images (Keyless)') {
    steps {
        withCredentials([
            string(credentialsId: 'sigstore-oidc-token', variable: 'SIGSTORE_ID_TOKEN')
        ]) {
            sh '''
              set -euo pipefail
              export COSIGN_EXPERIMENTAL=1

              for svc in portal-web auth-users chatbot-manager conversation-service audit-security-service; do
                cosign sign --yes \
                  --fulcio-url=https://fulcio.sigstore.dev \
                  --rekor-url=https://rekor.sigstore.dev \
                  "${REGISTRY_HOST}/${IMAGE_PREFIX}-${svc}@$(crane digest ${REGISTRY_HOST}/${IMAGE_PREFIX}-${svc}:${IMAGE_TAG})"
              done
            '''
        }
    }
}
```

### Étape 3 : Mise à jour de la Policy Kyverno

Remplacer la vérification par clé publique par une vérification par identité OIDC :

```yaml
# infra/k8s/policies/kyverno/verify-cosign-images.yaml — version keyless
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: securerag-verify-cosign-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-securerag-signed-images
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [securerag-hub]
      verifyImages:
        - imageReferences:
            - "ghcr.io/*/securerag-hub-*"
          required: true
          mutateDigest: true
          verifyDigest: true
          attestors:
            - entries:
                - keyless:
                    issuer: "https://token.actions.githubusercontent.com"
                    subject: "https://github.com/YassinoMed/MasterPFE/.github/workflows/*"
                    rekor:
                      url: "https://rekor.sigstore.dev"
```

### Étape 4 : Vérification Manuelle

```bash
# Vérifier une image signée en keyless
cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity-regexp "^https://github.com/YassinoMed/MasterPFE/" \
  ghcr.io/yassinomed/securerag-hub-portal-web@sha256:abc123...
```

## 4. Prérequis

- [ ] Accès à un registre public/privé avec TLS (pas `localhost:5001`)
- [ ] Plugin Jenkins OIDC Provider ou migration vers GitHub Actions comme CI/CD principal
- [ ] Kyverno ≥ 1.10 (support `keyless` attestors)
- [ ] Connectivité réseau vers `fulcio.sigstore.dev` et `rekor.sigstore.dev`

## 5. Timeline

| Phase | Durée | Dépendance |
|-------|-------|------------|
| Signature keyless dans GitHub Actions | ✅ Déjà prêt | — |
| Test Kyverno keyless en mode Audit | 1 semaine | Registre TLS |
| Migration Jenkins → OIDC | 2 semaines | Plugin Jenkins OIDC |
| Passage Kyverno keyless en Enforce | 1 semaine | 14j zero-violation |

---

*Document créé dans le cadre de l'audit DevSecOps — amélioration P2*
