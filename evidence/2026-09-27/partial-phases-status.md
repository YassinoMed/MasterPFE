# Phases Partielles — Statut Détaillé (2026-09-27)

## Phase 8 — SPIFFE/SPIRE : Infrastructure déployée et prouvée

**Réalisées :**
- 3 images pushed au registry local (spire-server, spire-agent, spire-controller-manager)
- Namespace spire-system avec RBAC + ConfigMaps + ServiceAccounts
- SPIRE Server (Deployment) démarre et devient Healthy
- SPIRE Agents (DaemonSet) : 2/2 Running momentanément
- SVID entry créé pour auth-users : `spiffe://cluster.local/ns/securerag-hub/sa/sa-auth-users`
- Attestation d'agent réussie (k8s_psat)
- ConfigMap spire-bundle créé

**Non résolues :**
- Server cycle Running → Crash (keymanager memory persistant)
- Bundle ConfigMap non rempli (notifier k8sbundle ne fonctionne pas complètement)
- Agents crash après connexion (bundle vide)

**Fix requis :**
1. Changer KeyManager memory → disk (fichier multi-YAML, sed nécessaire)
2. Corriger le format du bundle ConfigMap
3. Séparer le controller-manager du server pod

## Phase 10 — Velero Restore : S3 backend déployé

**Réalisées :**
- Serveur S3 Python (simple-s3.py) : fonctionnel, HTTP 200 sur :9000
- Service systemd `securerag-s3` : persistant, enabled
- Service K8s `minio-velero-backend` avec Endpoints vers 172.18.0.1:9000
- BSL reconfigurée vers `http://minio-velero-backend.velero.svc:9000`
- Script `velero-restore-test.sh` : complet (152 lignes)

**Non résolues :**
- BSL phase: Unavailable (le serveur S3 Python n'implémente pas l'auth AWS Signature V4)
- Pas de backup réussi → pas de restore test exécutable

**Fix requis :**
1. Implémenter l'auth S3 (Signature V4) dans le serveur Python
2. OU déployer MinIO avec une image accessible
3. OU utiliser AWS S3 directement (credentials requises)

## Phase 14 — Kyverno CEL : Différé (HIGH RISK)

**Réalisées :**
- Template ValidatingPolicy disallow-root-containers.yaml
- README avec plan de migration des 8 policies
- Documentation complète

**Non réalisées :**
- CRD ValidatingPolicy absent de Kyverno 1.19
- Upgrade vers Kyverno ≥ 2.0 : HIGH RISK sur le cluster live

**Différé :** upgrade en environnement de test requis.
Les 8 policies v1 fonctionnent parfaitement en Enforce.
