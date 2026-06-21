# Ratify Admission Control — SecureRAG Hub

## Architecture

```
┌──────────────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐     ┌──────────────┐
│   Cosign     │────▶│   Rekor   │────▶│  Ratify   │◀────│  Kyverno  │────▶│  Kubernetes  │
│  (signature) │     │ (transp.) │     │ (verify)  │     │ (webhook) │     │  (admit pod) │
└──────────────┘     └───────────┘     └───────────┘     └───────────┘     └──────────────┘
       │                    │                 │                  │
       ▼                    ▼                 ▼                  ▼
  OCI Registry     Public Ledger      Config/Policy       Admission Review
```

**Flux d'admission :**
1. Développeur signe l'image avec Cosign → Rekor (transparence)
2. Pod est créé → Kyverno intercepte l'admission
3. Kyverno délègue la vérification à Ratify (attesteur externe)
4. Ratify valide : signature Cosign, SBOM CycloneDX, attestation SLSA
5. Résultat retourné à Kyverno → admission acceptée ou refusée

---

## Déploiement

### Via Kustomize
```bash
kubectl apply -k infra/k8s/ratify/
```

### Via ArgoCD
L'application `securerag-ratify` est déployée via ArgoCD (sync-wave 30) :
```bash
kubectl apply -f infra/k8s/argocd/application-ratify.yaml
```

### Via Helm
```bash
helm repo add ratify https://deislabs.github.io/ratify
helm upgrade --install ratify ratify/ratify \
  --namespace ratify --create-namespace \
  --set replicaCount=2
```

---

## Politiques de Vérification

### Cosign — Signature cryptographique
- Vérifie les signatures d'images signées avec Cosign
- Trust store CA : `securerag-root`
- Niveau strict : échoue si signature invalide ou absente

### SBOM — CycloneDX
- Vérifie la présence d'un SBOM CycloneDX dans le registre
- `nestedVerification` : analyse Trivy avec score minimum de 7/10
- Garantit que seules les images avec SBOM de qualité sont déployées

### SLSA — Attestation de provenance
- Valide les attestations SLSA v2 (provenance build)
- Vérifie la chaîne de construction (builder ID, matériel source)

---

## Intégration Supply Chain

| Étape | Outil | Rôle |
|-------|-------|------|
| Build | GitHub Actions + Cosign | Signer l'image et pousser la signature |
| Transparence | Rekor | Journal public des signatures |
| Scan | Trivy | Analyser vulnérabilités du SBOM |
| Vérification | Ratify | Valider signatures + attestations |
| Admission | Kyverno | Bloquer les images non conformes |
| Monitoring | Prometheus + Grafana | Métriques de vérification |

---

## Dépannage

### Logs Ratify
```bash
kubectl logs -n ratify deployment/ratify -f
```

### Tester la configuration
```bash
# Vérifier que Ratify répond
kubectl exec -n ratify deploy/ratify -- wget -qO- http://localhost:6001/health

# Vérifier la politique Kyverno
kubectl describe clusterpolicy securerag-ratify-verification
```

### Problèmes courants

| Symptôme | Cause possible | Solution |
|----------|---------------|----------|
| Les pods sont bloqués | Image non signée | Signer l'image avec `cosign sign` |
| Ratify ne répond pas | Config invalide | Vérifier `ratify-config` ConfigMap |
| Timeout admission | Registry inaccessible | Vérifier network policy / registry |
| Erreur de certificat | Trust store manquant | Ajouter CA dans `verificationCerts` |

### Métriques Prometheus
Ratify expose les métriques sur `/metrics` port 6001, scrapées par le ServiceMonitor dans `securerag-monitoring`.
