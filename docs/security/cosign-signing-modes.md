# Modes de signature Cosign — SecureRAG Hub

## Résumé

Le pipeline accepte **deux modes** de signature selon l'environnement :

| Mode | SLSA | Usage | Activation |
|---|---|---|---|
| `keyless` | L3 (OIDC/Fulcio/Rekor) | Production | via defaults sign-images.sh |
| `key-pair` | L1 (équivalent GPG) | Dev local / offline | `COSIGN_KEY=<fichier>` |

## Mode Keyless (SLSA L3) — Production

Prérequis :
- Cluster déployé via `make platform-up` (déploie Keycloak/Fulcio/Rekor via sigstore-stack si provisionné) ;
- OIDC_TOKEN issu d'OIDC (GitHub Actions, GitLab CI, Keycloak) ;
- Pas de clés persistantes (juste un jeton OIDC).

Activation (par défaut) :
```bash
cosign sign --yes --fulcio-url=... --rekor-url=... --oidc-issuer=... <image>
```

## Mode Key-Pair (L1) — Dev/Offline

Motive : stack Sigstore pas déployée sur le cluster kind de soutenance.

```bash
COSIGN_KEY=security/keys/cosign.key \
COSIGN_PASSWORD=... \
COSIGN_PUBLIC_KEY=security/keys/cosign.pub \
make sign verify
```

⚠️ Non-SLSA L3 : la clé privée persiste sur disque — acceptable uniquement pour dev/offline.

## Migration vers keyless en prod

```bash
# 1. Déployer la stack Sigstore (helm chart sigstore/stack) ou utiliser sigstore.dev public
# 2. Cosign avec OIDC_TOKEN :
export COSIGN_EXPERIMENTAL=1
cosign sign --yes <image>
cosign verify --certificate-oidc-issuer https://... <image>
# 3. Passer Kyverno en mode enforce pour n'accepter que les images certificat-OIDC conformes.
```
