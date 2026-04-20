# Production Readiness Roadmap - SecureRAG Hub

## 1. Audit production/HA du projet actuel

| Composant | Etat actuel | Limite production | Impact HA / securite / exploitation | Priorite | Correction recommandee |
|---|---|---|---|---:|---|
| Laravel workloads | Base et demo stables avec probes, resources, NetworkPolicies, PDB | Base/demo restent majoritairement a `replicas: 1` | HA limitee si un pod ou un noeud tombe | P0 | Utiliser `infra/k8s/overlays/production` |
| Production overlay | Overlay HA statique ajoute | Pas encore prouve runtime | HA statique prete, preuve cluster manquante | P0 | Deployer overlay production et archiver runtime evidence |
| HPA | HPA production pour cinq services | Depend de metrics-server | Scaling non exploitable sans metriques | P0 | Installer metrics-server et lancer `production-runtime-evidence` |
| PDB | PDB adaptes dans overlay production | Eviction reelle non testee ici | Maintenance mieux controlee | P1 | Tester rollout restart et drain sur cluster multi-noeud |
| Supply chain | Scripts Trivy/Syft/Cosign/digest/attestation disponibles et gates Jenkins durcis | Preuve E2E depend de Docker, registry, Trivy, Syft, Cosign et cles | Release pas encore supply-chain-ready prouvee sans evidence cible | P0 | Executer `make supply-chain-execute` puis `make supply-chain-evidence` |
| Donnees | Overlay `production-external-db`, scripts backup/restore et runbook prets | Backup/restore pas encore rejoues sans PostgreSQL externe | Donnees production credibles apres preuve de backup + restore | P1 | Creer secret DB externe, deployer overlay, lancer `make data-backup` et `make data-restore` |
| Observabilite | Snapshots et collecteurs disponibles | Pas de stack Prometheus/Loki par defaut | Exploitation possible mais limitee | P2 | Ajouter stack optionnelle apres HA runtime |
| Secrets | Bootstrap local et rotation documentes | Pas de solution prod type External Secrets activee | Gestion prod encore manuelle | P1 | Preparer SOPS/External Secrets en phase suivante |

## 2. Architecture cible production + haute disponibilite

| Couche | Cible |
|---|---|
| CI/CD | Jenkins officiel, CI/CD separees, Sonar credentialise, artefacts archives |
| Supply chain | Build unique, scan image, SBOM, Cosign sign/verify, promotion digest, no-rebuild deploy, attestation |
| Kubernetes | Overlay production, PSA restricted, RBAC, NetworkPolicies, PDB, HPA, rolling update explicite |
| Reseau | Services internes ClusterIP, exposition minimale, flux limites par NetworkPolicy |
| Workloads | `portal-web=3`, services officiels `=2`, anti-affinity, topology spread, probes robustes |
| Donnees | Base externe ou stateful backend dedie, volumes persistants, backup/restore teste |
| Observabilite | metrics-server obligatoire, HPA visibles, events/logs/top, support pack enrichi |
| Secrets | Aucun secret Git, separation dev/demo/prod, rotation, SOPS/External Secrets cible |
| SRE / runbooks | HA, incidents, SLO, modes degrades, restart/eviction/drain |
| Preuves runtime | `production-runtime-evidence.md`, support pack, supply-chain evidence, Kyverno reports |

## 3. Plan de migration vers la production

### Phase 1 - base production immediate

Etat : `TERMINÉ` statique.

- overlay `production` separe ;
- replicas HA ;
- PDB coherents ;
- anti-affinity et topology spread ;
- rolling update `maxUnavailable=0`, `maxSurge=1` ;
- HPA CPU/memoire declares ;
- validations statiques.

### Phase 2 - haute disponibilite credible

Etat : `DÉPENDANT_DE_L_ENVIRONNEMENT`.

- cluster actif, idealement multi-noeud ;
- metrics-server installe ;
- HPA avec metriques non `<unknown>` ;
- rollout restart prouve ;
- eviction/drain teste si cluster multi-noeud.

### Phase 3 - securite et supply chain expertes

Etat : `DÉPENDANT_DE_L_ENVIRONNEMENT`.

- Trivy image scan ;
- SBOM Syft ;
- Cosign sign/verify ;
- promotion digest ;
- attestation release ;
- Kyverno Audit, puis Enforce uniquement apres signatures prouvees.

### Phase 4 - observabilite / exploitation / reprise

Etat : `PRÊT_NON_EXÉCUTÉ`.

- SLO simples ;
- runbooks incidents ;
- modes degrades ;
- backup/restore donnees ;
- support pack production ;
- Dockerfiles production sans dependencies Composer dev, valides par `make production-dockerfiles` ;
- option Prometheus/Grafana/Loki.

### Phase 5 - validation finale et preuves

Etat : `DÉPENDANT_DE_L_ENVIRONNEMENT`.

- campagne Jenkins ;
- preuves cluster ;
- preuves supply chain ;
- support pack final ;
- rapport security posture.

## 4. Fichiers de reference

- `infra/k8s/overlays/production/kustomization.yaml`
- `scripts/validate/validate-production-ha.sh`
- `scripts/validate/collect-production-runtime-evidence.sh`
- `scripts/validate/run-production-readiness-campaign.sh`
- `scripts/validate/validate-production-data-resilience.sh`
- `scripts/validate/validate-production-dockerfiles.sh`
- `infra/k8s/overlays/production-external-db/kustomization.yaml`
- `docs/runbooks/production-ha.md`
- `docs/runbooks/data-resilience.md`
- `artifacts/security/production-ha-readiness.md`
- `artifacts/security/production-dockerfiles.md`

## 5. Validation

Non destructif :

```bash
kubectl kustomize infra/k8s/overlays/production >/tmp/securerag-production.yaml
bash scripts/validate/validate-production-ha.sh
bash scripts/validate/validate-k8s-resource-guards.sh
bash scripts/validate/validate-k8s-ultra-hardening.sh
make production-dockerfiles
make production-data-resilience
make lint
```

Runtime lecture seule :

```bash
make production-runtime-evidence
make production-readiness-campaign
make kyverno-runtime-proof
```

Runtime mutatif :

```bash
bash scripts/deploy/install-metrics-server.sh
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=production \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/production \
bash scripts/deploy/deploy-kind.sh
```

Runtime supply chain et donnees :

```bash
make supply-chain-execute
make supply-chain-evidence
make release-attestation
make data-backup
make data-restore
```

## 6. Tableau final global

| Bloc | Tache | Etat | Priorite | Action restante |
|---|---|---:|---:|---|
| A | Kubernetes HA statique | TERMINÉ | P0 | Deployer sur cluster actif |
| B | Runtime scaling | DÉPENDANT_DE_L_ENVIRONNEMENT | P0 | Installer metrics-server et archiver HPA |
| C | Securite prod statique | TERMINÉ | P0 | Prouver Kyverno runtime |
| D | Supply chain prod | DÉPENDANT_DE_L_ENVIRONNEMENT | P0 | Executer Trivy/Syft/Cosign/digest |
| E | Resilience donnees | PRÊT_NON_EXÉCUTÉ | P1 | Externaliser DB et tester backup/restore |
| F | Observabilite runtime | DÉPENDANT_DE_L_ENVIRONNEMENT | P1 | Collecter runtime evidence et support pack |
