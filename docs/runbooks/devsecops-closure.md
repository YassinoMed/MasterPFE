# DevSecOps Closure Runbook - SecureRAG Hub

## Objectif

Fermer proprement les derniers écarts DevSecOps du périmètre officiel sans
surpromettre et sans casser le mode `demo`.

Le point d’entrée recommandé est :

```bash
make devsecops-closure
```

Le runner associé orchestre les blocs suivants :

- Bloc A — runtime final ;
- Bloc B — sécurité post-déploiement ;
- Bloc C — supply chain ;
- Bloc D — Kyverno ;
- Bloc E — données ;
- Bloc F — secrets, Jenkins, source de vérité et support pack.

## Principe de fonctionnement

Par défaut, le runner reste prudent :

- lecture seule pour les preuves runtime, sécurité, Kyverno, secrets et Jenkins ;
- pas de déploiement digest mutatif tant que `RUN_DIGEST_DEPLOY=true` n’est pas
  fourni explicitement ;
- pas de backup/restore PostgreSQL tant que les variables `DB_*` ne sont pas
  présentes ;
- la supply chain complète ne s’exécute qu’en mode `auto` si Docker, Trivy,
  Syft, Cosign et les clés Cosign sont réellement disponibles.

## États autorisés

- `TERMINÉ` : preuve présente et cohérente ;
- `PARTIEL` : preuve rejouée mais incomplète, échouée ou contradictoire ;
- `PRÊT_NON_EXÉCUTÉ` : dépôt prêt, campagne live non rejouée ;
- `DÉPENDANT_DE_L_ENVIRONNEMENT` : cluster, Jenkins, registry ou DB externe
  absents.

## Ordre recommandé

### 1. Runtime final

```bash
make runtime-image-proof
make production-runtime-evidence
make portal-service-proof
```

Preuves attendues :

- `artifacts/validation/runtime-image-rollout-proof.md`
- `artifacts/validation/production-runtime-evidence.md`
- `artifacts/application/portal-service-connectivity.md`

### 2. Sécurité post-déploiement

```bash
make runtime-security-postdeploy
make k8s-resource-guards
make k8s-ultra-hardening
make security-posture
```

Preuves attendues :

- `artifacts/security/runtime-security-postdeploy.md`
- `artifacts/security/k8s-resource-guards.md`
- `artifacts/security/k8s-ultra-hardening.md`
- `artifacts/security/security-posture-report.md`

### 3. Supply chain

Validation non destructive :

```bash
make release-attestation
make release-provenance
make release-proof-strict
```

Exécution complète uniquement si l’environnement est prêt :

```bash
RUN_SUPPLY_CHAIN=true \
SOURCE_IMAGE_TAG=production \
TARGET_IMAGE_TAG=release-local \
make devsecops-closure
```

Déploiement digest immuable strict uniquement sur cluster cible stable :

```bash
RUN_DIGEST_DEPLOY=true \
TARGET_IMAGE_TAG=release-local \
REQUIRE_DIGEST_DEPLOY=true \
make devsecops-closure
```

### 4. Kyverno

```bash
make kyverno-runtime-proof
make kyverno-enforce-readiness
```

Preuves attendues :

- `artifacts/validation/kyverno-runtime-report.md`
- `artifacts/validation/kyverno-enforce-readiness.md`
- `artifacts/validation/kyverno-local-registry-enforce-blocker.md`

### 5. Données

Validation statique :

```bash
make production-data-resilience
```

Preuve live uniquement avec une DB PostgreSQL externe :

```bash
DB_HOST='<postgres-host>' \
DB_PORT=5432 \
DB_DATABASE='portal_web' \
DB_USERNAME='<postgres-user>' \
DB_PASSWORD='<mot-de-passe-fort>' \
make data-resilience-proof
```

### 6. Secrets, Jenkins, support pack

```bash
make secrets-management
make final-source-of-truth
make final-summary
bash scripts/validate/generate-devsecops-closure-matrix.sh
make support-pack
```

Jenkins webhook en lecture seule si le serveur est joignable :

```bash
JENKINS_URL=http://127.0.0.1:8085 \
make jenkins-webhook-proof
```

Preuve SCM push uniquement après un vrai `git push` :

```bash
EXPECTED_COMMIT="$(git ls-remote origin refs/heads/main | awk '{print $1}')" \
JENKINS_URL=http://127.0.0.1:8085 \
JENKINS_USER=admin \
JENKINS_TOKEN="$(tr -d '\r\n' < infra/jenkins/secrets/jenkins-admin-password)" \
make jenkins-ci-push-proof
```

## Commande compacte

Rejeu complet prudent :

```bash
make devsecops-closure
```

Rejeu avec supply chain complète et support pack :

```bash
RUN_SUPPLY_CHAIN=true \
RUN_SUPPORT_PACK=true \
make devsecops-closure
```

## Artefacts finaux à lire

- `artifacts/final/devsecops-closure-latest.md`
- `artifacts/final/devsecops-closure-matrix.md`
- `artifacts/final/security-final-status.md`
- `artifacts/final/production-final-status.md`
- `artifacts/final/release-final-status.md`
- `artifacts/final/final-validation-summary.md`

## Règle de soutenance

Ne dire `TERMINÉ` que si l’artefact correspondant existe et prouve réellement
la campagne visée. Tout le reste doit rester `PARTIEL`,
`PRÊT_NON_EXÉCUTÉ` ou `DÉPENDANT_DE_L_ENVIRONNEMENT`.
