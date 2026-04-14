# DevSecOps Remaining Validation Runbook - SecureRAG Hub

## Objective

Close the remaining DevSecOps evidence gaps without changing the stable `demo` path.

The already validated baseline remains:

- official scenario: `demo`
- Jenkins as the official CI/CD authority
- GitHub Actions as legacy
- local kind deployment
- final campaign support pack

## 1. Jenkins CI after Git push

Run:

```bash
JENKINS_URL=https://jenkins.example.invalid \
bash scripts/jenkins/validate-github-webhook.sh
```

Utiliser `http://localhost:8085` uniquement pour un Jenkins local de démonstration. Un Jenkins exposé sur un serveur cloud doit être publié derrière HTTPS.

Expected evidence:

- `artifacts/jenkins/github-webhook-validation.md`

Then push a harmless commit:

```bash
git commit --allow-empty -m "ci: validate Jenkins automatic trigger"
git push origin main
```

Expected result:

- GitHub webhook delivery reaches `/github-webhook/`.
- Jenkins starts `securerag-hub-ci`.
- If webhook delivery fails, SCM polling still starts the job within about 5 minutes.

## 2. Supply chain execute

Dry-run preflight:

```bash
SUPPLY_CHAIN_MODE=dry-run \
REGISTRY_HOST=localhost:5001 \
SOURCE_IMAGE_TAG=dev \
TARGET_IMAGE_TAG=release-local \
make supply-chain-execute
```

Full execution:

```bash
REGISTRY_HOST=localhost:5001 \
SOURCE_IMAGE_TAG=dev \
TARGET_IMAGE_TAG=release-local \
COSIGN_KEY=infra/jenkins/secrets/cosign.key \
COSIGN_PUBLIC_KEY=infra/jenkins/secrets/cosign.pub \
COSIGN_PASSWORD_FILE=infra/jenkins/secrets/cosign.password \
make supply-chain-execute
```

Expected evidence:

- `artifacts/release/sign-summary.txt`
- `artifacts/release/verify-summary.txt`
- `artifacts/release/promotion-by-digest-summary.txt`
- `artifacts/release/promotion-digests.txt`
- `artifacts/release/supply-chain-execute-summary.md`
- `artifacts/sbom/sbom-index.txt`

Environment dependencies:

- Docker daemon available.
- Local registry reachable.
- Source images already pushed.
- Cosign keys available.
- Syft and Cosign installed.

## 3. Metrics-server and HPA

Install or repair metrics-server:

```bash
make metrics-install
```

Collect proof:

```bash
make cluster-security-proof
```

Expected evidence:

- `artifacts/validation/cluster-security-addons.md`

Expected result:

- Metrics APIService exists.
- `kubectl top nodes` responds.
- `kubectl top pods -n securerag-hub` responds.
- HPA objects are visible.

## 4. Kyverno Audit / Enforce

Recommended first step:

```bash
make kyverno-install
make cluster-security-proof
```

Enforce mode only after signed images and Cosign verification are proven:

```bash
make kyverno-enforce
make cluster-security-proof
```

Expected evidence:

- `artifacts/validation/cluster-security-addons.md`
- `kubectl get clusterpolicy`
- `kubectl get policyreport,clusterpolicyreport -A`

Risk:

- Enforce mode can block pods if images are not signed or policy registry references are not aligned.

## 5. Final proof pack

Run:

```bash
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=dry-run make final-campaign
```

If all execute dependencies are present:

```bash
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=execute make final-campaign
```

Expected evidence:

- `artifacts/final/reference-campaign-summary.md`
- `artifacts/final/final-validation-summary.md`
- `artifacts/release/release-evidence.md`
- `artifacts/release/supply-chain-evidence.md`
- `artifacts/validation/cluster-security-addons.md`
- `artifacts/support-pack/*.tar.gz`
