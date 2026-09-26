# GUIDE D'IMPLÉMENTATION — 25 Phases Step by Step

**Plateforme SecureRAG Hub** · Point de départ : `CURRENT_STATE.md` (audit) · Référence : `ROADMAP-MATURITE-DEVSECOPS.md` (stratégie)

---

## PHASE 0 — AUDIT INITIAL ✅ FAIT

Livré : `CURRENT_STATE.md`. Compter les Applications ArgoCD, les ApplicationSets, les overlays, les policies. Vérifier que tous les overlays build.

---

## PHASE 1 — STABILISER KUSTOMIZE ET GITOPS

**Objectif** : Chaque environnement s'auto-suffit.

### Étape 1.1 : Inventaire des ressources par overlay
```bash
# Pour chaque env, liste ce qui change :
for env in dev demo recette staging production dr; do
  echo "■ $env"
  kubectl kustomize infra/k8s/overlays/$env | grep -E "^kind:|name:" | grep -A1 "Namespace\|Deployment" | head -20
done
```

### Étape 1.2 : Vérifier `base/` ne contient QUE le commun
```bash
grep -rn "namespace:\|NodePort\|securerag-hub\|APP_ENV" infra/k8s/base/ | grep -v "^#" | head -20
# Si un namespace ou une variable d'env APP_ENV est dans base → déplacer vers l'overlay
```

### Étape 1.3 : Déplacer les éléments spécifiques
- Namespace → overlay kustomization (`namespace:`)
- ResourceQuota/LimitRange → `overlays/_hub-foundation/`
- APP_ENV/APP_DEBUG → overlay `configMapGenerator`
- NodePort → overlay service patch

### Étape 1.4 : Validation
```bash
for env in dev demo recette staging production dr; do
  kubectl kustomize infra/k8s/overlays/$env >/dev/null && echo "$env: OK"
done
```

### Étape 1.5 : Commit
```bash
git add infra/k8s/base/ infra/k8s/overlays/
git commit -m "fix(kustomize): isolate environments — move env-specific resources out of base"
```

---

## PHASE 2 — TRIVY OPERATOR

### Étape 2.1 : Créer l'Application ArgoCD
```bash
mkdir -p infra/k8s/argocd
cat > infra/k8s/argocd/securerag-trivy-operator.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: securerag-trivy-operator
  namespace: argocd
spec:
  project: securerag-hub
  source:
    repoURL: https://aquasecurity.github.io/trivy-operator
    chart: trivy-operator
    targetRevision: 0.29.0
    helm:
      values: |
        trivy: { ignoreUnfixed: true }
        serviceMonitor: { enabled: true }
        scanner: { replicas: 2 }
  destination:
    server: https://kubernetes.default.svc
    namespace: trivy-system
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true]
EOF
```

### Étape 2.2 : Autoriser dans AppProject
```bash
# Ajouter à infra/k8s/argocd/project.yaml :
# sourceRepos: - https://aquasecurity.github.io/trivy-operator
# destinations:   - server: https://kubernetes.default.svc
#                 namespace: trivy-system
```

### Étape 2.3 : Ajouter à la kustomization
```bash
# Sous infra/k8s/argocd/kustomization.yaml :
#   - securerag-trivy-operator.yaml
```

### Étape 2.4 : Déployer
```bash
git add infra/k8s/argocd/securerag-trivy-operator.yaml infra/k8s/argocd/project.yaml infra/k8s/argocd/kustomization.yaml
git commit -m "feat(security): deploy trivy-operator via ArgoCD"
git push origin main
argocd app sync securerag-trivy-operator --timeout 300
```

### Étape 2.5 : Valider
```bash
kubectl get pods -n trivy-system
kubectl get vulnerabilityreports -A | head -5
kubectl get configauditreports -A | head -3
kubectl get configauditreports -A --no-headers | wc -l
```

### Étape 2.6 : Grafana dashboard
Créer un dashboard "Trivy Vulnerabilities" alimenté par les métriques `trivy_`. Chercher sur grafana.com/dashboards ID **16202**.

---

## PHASE 3 — VAULT PRODUCTION

### Étape 3.1 : Sauvegarder (Phase 0 requis)
```bash
kubectl exec -n vault securerag-vault-0 -- vault kv list -format=json securerag/ > /tmp/vault-backup.json
# ou binaire complet :
kubectl exec -n vault securerag-vault-0 -- sh -c 'vault operator raft snapshot save /tmp/vault.snap' 2>&1 || true
```

### Étape 3.2 : Modifier `application-vault.yaml`
```yaml
server:
  datastorage: { enabled: true, size: 10Gi }
  ha:
    enabled: true
    replicas: 3
    raft: { enabled: true, setNodeId: true }
  autoUnseal:
    enabled: true
    kms: { region: us-east-1, keyId: "<KMS_KEY_ID>" }
  auditStorage:
    enabled: true
  ingress:
    enabled: false
injector:
  enabled: true
ui:
  enabled: true
  serviceType: ClusterIP
```

### Étape 3.3 : Autoriser le PVC + KMS
```bash
# project.yaml : destinations + whitelist PersistentVolumeClaim/StatefulSet
# AWS : créer la clé KMS
aws kms create-key --description "Vault auto-unseal" --region us-east-1
```

### Étape 3.4 : Déployer
```bash
argocd app sync securerag-vault --timeout 300
kubectl get pods -n vault -w &
sleep 60; kubectl get pods -n vault
```

### Étape 3.5 : Initialiser et unseal
```bash
kubectl exec -n vault securerag-vault-0 -- vault operator init -key-shares=5 -key-threshold=3
# Noter les clés et le root token (ne jamais les commiter)
kubectl exec -n vault securerag-vault-0 -- vault operator unseal <KEY1>
kubectl exec -n vault securerag-vault-0 -- vault operator unseal <KEY2>
kubectl exec -n vault securerag-vault-0 -- vault operator unseal <KEY3>
```

### Étape 3.6 : Migrer les secrets
```bash
kubectl exec -n vault securerag-vault-0 -- vault kv put securerag/auth_users password=<nouveau_mdp_db>
# etc. pour chaque secret
```

### Étape 3.7 : Enable database dynamic secrets
```bash
kubectl exec -n vault securerag-vault-0 -- sh << 'VAULT_EOF'
vault secrets enable database
vault write database/config/postgres-auth \
  plugin_name=postgresql-database-plugin \
  allowed_roles=auth-users \
  connection_url="postgresql://{{username}}:{{password}}@postgres-auth:5432/auth_users" \
  username=securerag password=<ADMIN_PASSWORD>
vault write database/roles/auth-users \
  db_name=postgres-auth \
  default_ttl=1h \
  max_ttl=4h
VAULT_EOF
```

### Étape 3.8 : Valider
```bash
kubectl exec -n vault securerag-vault-0 -- vault read database/creds/auth-users
kubectl exec -n vault securerag-vault-0 -- vault status | grep -E "HA Mode|Sealed"
```

### Étape 3.9 : Vault audit + métriques
```bash
# + vault audit enable file file_path=/var/log/vault-audit.log
# + ConfigMap prometheus-sidecar dans vault pour les métriques
```

### Commit
```bash
git add infra/k8s/argocd/application-vault.yaml Scripts/
git commit -m "feat(vault): production Raft+HA+KMS auto-unseal + dynamic DB creds"
```

---

## PHASE 4 — SUPPLY CHAIN : SBOM + PROVENANCE + KEYLESS

### Étape 4.1 : Modifier le `Jenkinsfile`
```groovy
stage('Trivy + SBOM') {
  steps {
    sh 'trivy image --format cyclonedx --output sbom.json ${IMAGE}'
    sh 'trivy image --exit-code 1 --severity CRITICAL ${IMAGE}'
    sh 'cosign attest --predicate sbom.json --type cyclonedx ${IMAGE}'
  }
}
stage('Provenance') {
  steps {
    sh '''
      cat > provenance.json << EOF
{"builder":{"id":"jenkins/securerag/${BUILD_NUMBER}"},"buildType":"https://slsa.dev/provenance/v1","materials":[{"uri":"${GIT_URL}"}]}
EOF
      cosign attest --predicate provenance.json --type slsaprovenance ${IMAGE}
    '''
  }
}
```

### Étape 4.2 : Keyless Cosign
```bash
# Vérifier le script existant :
head -30 scripts/export-cosign-key-age.sh
# Basculement progressif :
# cosign sign --yes --oidc-issuer=https://token.actions.githubusercontent.com ... ${IMAGE}
# ou jenkins avec plugin OIDC : identity="jenkins@securerag.local"
```

### Étape 4.3 : Vérifier la policy Kyverno cosign-demo
```bash
kubectl get clusterpolicy securerag-verify-cosign-images -o yaml | grep -A20 verifyImages
# Ajouter attestors + fetch certification path
```

### Validation
```bash
cosign verify-attestation --type slsaprovenance \
  --certificate-identity=jenskins@securerag.local --certificate-oidc-issuer=<issuer> \
  <image_digest>
```

---

## PHASE 5 — RATIFY / ADMISSION

### Étape 5.1 : Créer l'Application Ratify
```yaml
# infra/k8s/argocd/securerag-ratify.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: securerag-ratify
  namespace: argocd
spec:
  project: securerag-hub
  source:
    repoURL: https://ratify-project.github.io/helm-chart/ratify
    chart: ratify
    targetRevision: 0.17.0
    helm:
      values: |
        policy:
          type: CRD
        notation:
          enabled: false
        cosign:
          enabled: true
          key: <public_key_path>
  destination: { server: https://kubernetes.default.svc, namespace: ratify }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true]
```

### Étape 5.2 : Migration contrôlée
```bash
# 1. Kyverno policy reste Enforce pour cosign (fallback)
# 2. Ratify en "probe" → logs uniquement : ratifyProbe createPolicy
# 3. Une fois Ratify stable : Kyverno verify-cosign → mode Audit
# 4. Ratify → Enforce
```

---

## PHASE 6 — FALCO / TALON / TETRAGON + DETECTION DRILL

### Étape 6.1 : Deployer Tetragon
```bash
# infra/k8s/argocd/securerag-tetragon.yaml (helm iso tetragon)
# + scripts/tetragon/ a déjà des ébauches
```

### Étape 6.2 : Créer le detection drill
```bash
mkdir -p scripts/security
cat > scripts/security/detection-drill.sh << 'DRILL_EOF'
#!/bin/bash
echo "Detection Drill - $(date)"
NAMESPACE="securerag-test"   # ← NE PAS utiliser prod
POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=auth-users -o name | head -1)
echo "[1] Trigger: cat /etc/shadow dans $POD"
kubectl exec -n $NAMESPACE $POD -- cat /etc/shadow 2>&1
sleep 5
echo "[2] Falco detection:"
kubectl logs -n falco -l app.kubernetes.io/name=falco --since=30s | grep -i "sensitive\|shadow"
echo "[3] Talon response:"
kubectl logs -n falco -l app.kubernetes.io/name=falco-talon --since=30s | grep -iE "isolate|delete|terminate"
echo "[4] Pod status:"
kubectl get pod -n $NAMESPACE $POD -o jsonpath='{.metadata.name} status={.status.phase}'
DRILL_EOF
chmod +x scripts/security/detection-drill.sh
```

### Étape 6.3 : Valider
```bash
kubectl exec -n securerag-hub $(kubectl get pod -n securerag-hub -l app.kubernetes.io/name=auth-users -o name|head -1) -- cat /etc/shadow
kubectl logs -n falco -l app.kubernetes.io/name=falco --since=10s | grep -i shadow
kubectl logs -n falco falco-talon --since=10s | grep -i "terminate\|isolate"
```

### Commit
```bash
git add scripts/security/detection-drill.sh infra/k8s/tetragon/
git commit -m "feat(security): tetragon enforcement + detection drill script"
```

---

## PHASE 7 — CILIUM (nouveau cluster de test !)

### Étape 7.1 : Créer le cluster de test
```bash
kind create cluster --name securerag-cilium-test --config - << 'KIND_EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking: { disableDefaultCNI: true, kubeProxyMode: none }
nodes:
- role: control-plane
KIND_EOF
```

### Étape 7.2 : Installer Cilium + Hubble
```bash
cilium install --set kubeProxyReplacement=true
cilium hubble enable --ui
```

### Étape 7.3 : Déployer les namespaces + NetworkPolicies identiques
```bash
for ns in securerag-hub securerag-dev; do
  kubectl create ns $ns
  # Appliquer les NetPols de l'overlay correspondant
done
```

### Étape 7.4 : CiliumNetworkPolicy L7
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: nginx-http-only
spec:
  endpointSelector: { matchLabels: { app.kubernetes.io/name: chatbot-manager } }
  ingress:
  - toPorts: [{ ports: [{ port: "80", protocol: TCP }] }]
```

---

## PHASE 9 — DR MULTI-CLUSTER

### Étape 9.1 : Créer le 2ème cluster kind
```bash
kind create cluster --name securerag-dr-cluster
# → kubeconfig context ajouté
```

### Étape 9.2 : Enregistrer le cluster dans ArgoCD
```bash
argocd cluster add securerag-dr-cluster
```

### Étape 9.3 : ApplicationSet multi-cluster
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata: { name: securerag-multicluster }
spec:
  generators:
    - clusters: { selector: { matchLabels: { securerag: "true" } } }
  template:
    spec:
      destination: { server: '{{server}}', namespace: securerag-hub-dr }
```

### Étape 9.4 : Test DR
```bash
# Simuler : maintenir le contexte primaire
kubectl config use-context kind-securerag-dr-cluster
# Vérifier : apps déployées, RDS up, services disponibles
kubectl get pods -n securerag-hub-dr
```

---

## PHASE 10 — VELERO RESTORE TEST

### Script
```bash
cat > scripts/backup/velero-restore-test.sh << 'VEL_EOF'
#!/bin/bash
BACKUP=$(kubectl get backups -n velero --sort-by=.metadata.creationTimestamp -o name | tail -1)
echo "Test de restauration depuis: $BACKUP"
kubectl create ns securerag-restore-test
kubectl -n velero create restore --from-backup $BACKUP --restore-volumes=true --include-namespaces securerag-hub --namespace securerag-restore-test --wait
sleep 30
kubectl get pods -n securerag-restore-test
kubectl get pvc -n securerag-restore-test
kubectl get secrets -n securerag-restore-test | grep -v default
# Rapport
echo "Restauration OK rapport: $(date)" > /tmp/velero-restore-$(date +%Y%m%d).txt
kubectl delete ns securerag-restore-test
VEL_EOF
chmod +x scripts/backup/velero-restore-test.sh
```

---

## PHASE 11 — CHAOS ENGINEERING (test ns uniquement)

```bash
# Déployer chaos-mesh dans chaos-testing
helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-testing
# Créer : scripts/chaos/pod-kill.yaml
# Lancer : kubectl apply -f scripts/chaos/pod-kill.yaml
# Vérifier : pods se recréent, SLO maintenu
```

---

## PHASE 12 — DORA

### Étape 12.1 : Exporter
```bash
mkdir -p scripts/dora
cat > scripts/dora/exporter.py << 'DORA_EOF'
# DORA: deployment_frequency.py, lead_time.py, etc.
# Sources : GitHub API, ArgoCD API, Alertmanager
# Export : /metrics endpoint
DORA_EOF
```

### Étape 12.2 : Dashboard Grafana
Créer `infra/k8s/monitoring/dashboards/dora.json` avec les 4 cartes.

---

## PHASE 13 — FINOPS (OpenCost)

```bash
# infra/k8s/argocd/securerag-opencost.yaml
# kubectl port-forward svc/opencost 9003:9003 -n opencost
```

---

## PHASE 14 — KYVERNO → ValidatingPolicy CEL

Pour chaque ClusterPolicy existante :
1. Exporter : `kubectl get clusterpolicy X -o yaml > /tmp/x.yaml`
2. Réécrire en `ValidatingPolicy` CEL (annexe A4 de la roadmap)
3. Tester avec `kyverno test` ou `cel` expression
4. Mettre l'ancienne en `audit` puis `enforce` la nouvelle
5. Documenter

---

## PHASE 15 — POLICY EXCEPTIONS

Pour chaque exception (PostgreSQL NodePort, etc.) :
```yaml
# infra/k8s/policies/exceptions/postgres-auth-nodeport.yaml
apiVersion: kyverno.io/v2alpha1
kind: PolicyException
metadata:
  name: postgres-auth-nodeport
  namespace: securerag-hub
spec:
  exceptions:
  - policyName: securerag-restrict-service-exposure
    ruleNames: ["allow-nodeport-only-for-portal-web"]
  match:
    any:
    - resources:
        kinds: ["Service"]
        names: ["postgres-auth"]
  # raison, propriétaire, expiration à documenter ici
```

---

## PHASE 18 — APPSET GIT GENERATOR

### Structure cible
```bash
mkdir -p infra/k8s/environments/{dev,demo,recette,staging,production,dr}
# Chaque env a son fichier "config.yaml" propre :
```

### ApplicationSet git-generator
```yaml
spec:
  generators:
    - git:
        repoURL: https://github.com/YassinoMed/MasterPFE.git
        revision: main
        directories: [{ path: 'infra/k8s/environments/*' }]
  template:
    metadata: { name: 'securerag-{{path.basename}}' }
    spec: { source: { path: 'infra/k8s/overlays/{{path.basename}}' } }
```

---

## PHASE 20 — NOTIFICATIONS RÉELLES

```bash
# Créer le secret Slack (jamais commiter le webhook !)
kubectl create secret generic slack-webhook -n argocd \
  --from-literal=url="https://hooks.slack.com/services/TXXX/BXXX/XXXX"
# Configurer argocd-notifications-cm.yaml
# → routes: sync failed/degraded → #securerag-alerts
```

---

##### PHASE 24 — GIT SÉCURE : checklist avant chaque commit
```bash
git status --short                      # TOUJOURS avant add
git diff --name-only
git add <fichier-spécifique>            # JAMAIS "git add ."
git diff --cached --stat
git commit -m "type(scope): message"
```
---

*Écrit par l'agent d'audit du 2026-09-26 · À exécuter phase par phase avec validation à chaque étape.*
