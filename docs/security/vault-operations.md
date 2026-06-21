# Vault Operations — SecureRAG Hub

## Initialisation

```bash
bash scripts/secrets/initialize-vault.sh
```

Cette commande :
1. Initialise Vault (5 keys, threshold 3)
2. Unseal avec les 3 premières clés
3. Active KV v2 engine à `secret/`
4. Active Kubernetes auth
5. Crée les politiques `eso-reader` et `jenkins-reader`
6. Crée les rôles Kubernetes `eso-cluster-role` et `jenkins-role`
7. Seed les secrets initiaux

## Déploiement

```bash
bash scripts/deploy/deploy-vault-and-eso.sh
```

Cette commande :
1. Applique `kubectl apply -k infra/k8s/vault/`
2. Attend le pod vault-0 Ready
3. Execute initialize-vault.sh
4. Installe External Secrets Operator
5. Configure ClusterSecretStore → Vault
6. Crée les ExternalSecrets

## Opérations quotidiennes

### Unseal (après restart)
```bash
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>
```

### Ajouter un secret
```bash
kubectl exec -n vault vault-0 -- vault kv put secret/securerag/<path> <key>=<value>
```

### Lister les secrets
```bash
kubectl exec -n vault vault-0 -- vault kv list secret/securerag/
```

### Vault UI (port-forward)
```bash
kubectl port-forward -n vault vault-0 8200:8200
# http://localhost:8200
```

## Politiques

### eso-reader
```hcl
path "secret/data/*"          { capabilities = ["read", "list"] }
path "secret/metadata/*"      { capabilities = ["list"] }
path "database/creds/*"       { capabilities = ["read"] }
```

### jenkins-reader
```hcl
path "secret/data/securerag/jenkins/*" { capabilities = ["read", "list"] }
path "database/creds/*"                { capabilities = ["read"] }
```

## Dépannage

### Vault sealed
```bash
kubectl exec -n vault vault-0 -- vault status | grep Sealed
# Si "true", exécuter les 3 commandes unseal ci-dessus
```

### ExternalSecret not syncing
```bash
kubectl describe externalsecret <name> -n <namespace>
kubectl logs -n external-secrets -l app.kubernetes.io/instance=external-secrets
```

### Vault log
```bash
kubectl logs -n vault vault-0
```
