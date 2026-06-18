# Cluster Hardening — SecureRAG Hub

## Vue d'Ensemble

Ce document détaille les mesures de durcissement (hardening) appliquées au cluster Kubernetes SecureRAG Hub. Chaque section couvre un composant spécifique avec la configuration appliquée et sa justification.

---

## 1. Encryption au Repos (Encryption at Rest)

L'API Server est configuré pour chiffrer les secrets et autres données sensibles dans etcd.

**Configuration :** `/etc/kubernetes/encryption-config.yaml`
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
      - tokens
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      - identity: {}
```

**Flag API Server :** `--encryption-provider-config=/etc/kubernetes/encryption-config.yaml`

---

## 2. Audit Logging

L'API Server enregistre toutes les requêtes API pour la détection d'intrusion et le forensic.

**Politique d'audit :** `/etc/kubernetes/audit-policy.yaml`
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets", "configmaps", "tokenreviews"]
  - level: Metadata
    resources:
      - group: ""
        resources: ["pods", "services", "deployments"]
    verbs: ["create", "update", "delete", "patch"]
  - level: Metadata
    userGroups: ["system:authenticated"]
    omitStages:
      - RequestReceived
  - level: None
    users: ["system:kube-controller-manager", "system:kube-scheduler"]
    userGroups: ["system:nodes"]
```

**Flags API Server :**
- `--audit-log-path=/var/log/kubernetes/audit.log`
- `--audit-log-maxage=30`
- `--audit-log-maxbackup=10`
- `--audit-log-maxsize=100`
- `--audit-policy-file=/etc/kubernetes/audit-policy.yaml`

---

## 3. API Server Hardening

Flags de sécurité appliqués au `kube-apiserver` :

| Flag | Valeur | Justification |
|------|--------|--------------|
| `--anonymous-auth` | `false` | Bloque les requêtes non authentifiées |
| `--profiling` | `false` | Désactive le profiling pour éviter les fuites d'information |
| `--enable-admission-plugins` | `NodeRestriction,PodSecurity,NamespaceLifecycle,ServiceAccount,DefaultStorageClass,ResourceQuota,AlwaysPullImages` | Active les plugins d'admission essentiels |
| `--disable-admission-plugins` | `AlwaysAdmit` | Empêche l'admission sans vérification |
| `--admission-control-config-file` | `/etc/kubernetes/admission-config.yaml` | Configuration avancée |
| `--tls-cert-file` / `--tls-private-key-file` | Certificats signés par CA | Chiffrement TLS mutualisé |
| `--service-account-lookup` | `true` | Valide les tokens SA |
| `--token-auth-file` | Non utilisé | Préférer les tokens bootstrap |
| `--authorization-mode` | `Node,RBAC` | Double couche d'autorisation |

---

## 4. Kubelet Hardening

Configuration de sécurité du `kubelet` :

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
readOnlyPort: 0
streamingConnectionIdleTimeout: 5m
protectKernelDefaults: true
makeIPTablesUtilChains: true
eventRecordQPS: 5
rotateCertificates: true
featureGates:
  RotateKubeletServerCertificate: true
serverTLSBootstrap: true
seccompDefault: true
allowedUnsafeSysctls: []
memoryManagerPolicy: Static
cpuManagerPolicy: static
```

**Flags critiques :**
- `--read-only-port=0` — Désactive le port 10255 non sécurisé
- `--anonymous-auth=false` — Pas d'accès anonyme
- `--protect-kernel-defaults=true` — Protège les paramètres noyau
- `--rotate-certificates=true` — Rotation automatique des certificats

---

## 5. etcd Hardening

Configuration d'etcd avec TLS mutualisé :

```yaml
# /etc/kubernetes/manifests/etcd.yaml
spec:
  containers:
    - command:
        - etcd
        - --client-cert-auth=true
        - --peer-client-cert-auth=true
        - --auto-tls=false
        - --peer-auto-tls=false
        - --cert-file=/etc/kubernetes/pki/etcd/server.crt
        - --key-file=/etc/kubernetes/pki/etcd/server.key
        - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
        - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
        - --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
        - --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

---

## 6. Scheduler Hardening

```yaml
# Flags kube-scheduler
--profiling=false
--bind-address=127.0.0.1
--secure-port=10259
--authentication-kubeconfig=/etc/kubernetes/scheduler.conf
--authorization-kubeconfig=/etc/kubernetes/scheduler.conf
```

---

## 7. Controller Manager Hardening

```yaml
# Flags kube-controller-manager
--profiling=false
--bind-address=127.0.0.1
--secure-port=10257
--use-service-account-credentials=true
--authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
--authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
--service-account-private-key-file=/etc/kubernetes/pki/sa.key
--root-ca-file=/etc/kubernetes/pki/ca.crt
```

---

## 8. Pod Security Standards

Application des standards PSS (Pod Security Standards) :

```bash
# Appliquer Restricted sur tous les namespaces
kubectl label ns --all pod-security.kubernetes.io/enforce=restricted
kubectl label ns --all pod-security.kubernetes.io/audit=restricted
kubectl label ns --all pod-security.kubernetes.io/warn=restricted
```

**Politiques Kyverno associées :** `securerag-require-pod-security`

---

## 9. Network Policies

```yaml
# Politique par défaut : tout bloquer
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: securerag-hub
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

Politiques spécifiques définies dans `infra/k8s/policies/network-policies/`.

---

## 10. RBAC Hardening

- Utilisation de comptes de service dédiés (pas de `default`)
- Principe du moindre privilège appliqué à tous les `ClusterRole` et `Role`
- Pas de `cluster-admin` pour les workloads applicatifs
- Rotation des tokens ServiceAccount
- Bindings limités au strict nécessaire

**Vérification :**
```bash
# Identifier les permissions trop larges
kubectl get clusterrolebindings -o wide | grep -v system:
kubectl get clusterroles -o json | jq '.items[] | select(.rules[].verbs[]? | contains("*")) | .metadata.name'
```

---

## Résumé de Conformité

| Domaine | Statut | Contrôle CIS |
|---------|--------|-------------|
| Encryption at Rest | ✅ Activé (AESCBC) | 1.1.7, 1.1.8 |
| Audit Logging | ✅ Activé | 1.2.22, 1.2.23 |
| API Server | ✅ Hardened | 1.2.x |
| Kubelet | ✅ Hardened | 4.2.x |
| etcd | ✅ TLS mutualisé | 2.x |
| Scheduler | ✅ Hardened | 1.4.x |
| Controller Manager | ✅ Hardened | 1.3.x |
| Pod Security | ✅ Restricted | 5.2.x |
| Network Policies | ✅ Default deny | 5.3.x |
| RBAC | ✅ Least privilege | 5.1.x |
