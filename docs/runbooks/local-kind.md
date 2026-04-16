# Local kind Runbook — SecureRAG Hub

## Objectif
Fournir une procédure reproductible pour lancer SecureRAG Hub sur un cluster `kind` local, avec registre OCI local, déploiement Kustomize et validations post-déploiement.

Pour une campagne officielle de soutenance, completer ce runbook avec :

- `docs/runbooks/demo-checklist.md`
- `docs/runbooks/environment-freeze.md`
- `docs/runbooks/final-campaign.md`

## Pré-requis
- Docker opérationnel
- `kind`
- `kubectl`
- `cosign` si la chaîne de vérification est utilisée localement

## Étape 1 — Créer le cluster et le registre local
```bash
bash scripts/deploy/create-kind.sh
kind get clusters
kubectl cluster-info --context kind-securerag-dev
kubectl get nodes
```

Si le cluster a été créé avant l’ajout du mapping `localhost:8081 -> NodePort 30081`, le recréer :
```bash
kind delete cluster --name securerag-dev
bash scripts/deploy/create-kind.sh
```

## Étape 2 — Préparer les secrets locaux
```bash
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh
```

## Étape 3 — Construire les images de travail
```bash
REGISTRY_HOST=localhost:5001 IMAGE_TAG=dev bash scripts/deploy/build-local-images.sh
docker images | grep securerag-hub
```

Le build officiel cible uniquement les composants Laravel listés dans `scripts/deploy/build-local-images.sh`.

## Étape 4 — Déployer sur l’overlay `dev`
```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
bash scripts/deploy/deploy-kind.sh
```

## Étape 5 — Valider le runtime
```bash
bash scripts/validate/smoke-tests.sh
bash scripts/validate/security-smoke.sh
bash scripts/validate/e2e-functional-flow.sh
bash scripts/validate/security-adversarial-advanced.sh
bash scripts/validate/generate-validation-report.sh
bash scripts/validate/collect-runtime-evidence.sh
cat artifacts/validation/validation-summary.md
```

## Mode `demo`
Pour la soutenance, utiliser l’overlay `demo` :
```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=demo \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/demo \
bash scripts/deploy/deploy-kind.sh
```

Cet overlay déploie le même périmètre Laravel officiel avec `imagePullPolicy: IfNotPresent`.

## Vérifications utiles
```bash
kubectl get all -n securerag-hub
kubectl get pvc -n securerag-hub
kubectl get networkpolicy -n securerag-hub
kubectl get pods -n securerag-hub -o wide
curl http://localhost:8081/health
bash scripts/validate/validate-k8s-ultra-hardening.sh
```

## Addons optionnels du cluster

### Installer Kyverno
```bash
bash scripts/deploy/install-kyverno.sh
kubectl get clusterpolicy
```

Pour passer la policy Cosign en `Enforce` :
```bash
KYVERNO_POLICY_MODE=enforce bash scripts/deploy/install-kyverno.sh
```

### Installer metrics-server
```bash
bash scripts/deploy/install-metrics-server.sh
kubectl top nodes
kubectl top pods -n securerag-hub
kubectl get hpa -n securerag-hub
```

Si ces commandes repondent, les `HPA` ne devraient plus rester avec `cpu: <unknown>`.

## Preuves à conserver
```bash
kubectl get all -n securerag-hub > artifacts/validation/k8s-get-all.txt
kubectl get pvc -n securerag-hub > artifacts/validation/k8s-pvc.txt
kubectl get networkpolicy -n securerag-hub > artifacts/validation/k8s-networkpolicy.txt
kubectl get pods -n securerag-hub -o wide > artifacts/validation/k8s-pods.txt
kubectl describe deploy portal-web -n securerag-hub > artifacts/validation/portal-web-describe.txt
kubectl describe deploy conversation-service -n securerag-hub > artifacts/validation/conversation-service-describe.txt
kubectl describe deploy audit-security-service -n securerag-hub > artifacts/validation/audit-security-service-describe.txt
```

## Points d’attention sécurité
- ne pas désactiver les `NetworkPolicy` pour “faire passer” un test sans documenter l’écart
- conserver les `securityContext` non root et `readOnlyRootFilesystem` là où ils sont déjà compatibles
- exécuter `verify-and-deploy-kind.sh` pour une démo orientée supply chain, pas seulement `deploy-kind.sh`
- les policies Kyverno sont livrées séparément dans `infra/k8s/policies/kyverno` et nécessitent un moteur Kyverno installé dans le cluster
- le namespace est en Pod Security Admission `restricted`; les pods de validation utilisent `sa-validation` et des overrides de sécurité compatibles avec ce niveau
