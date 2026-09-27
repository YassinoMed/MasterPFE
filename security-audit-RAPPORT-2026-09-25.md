# DIAGNOSTIC SÉCURITÉ COMPLET — CLUSTER SECURERAG
**Date** : 2026-09-25 20:34 UTC · **Méthode** : skill 007 (6 phases, read-only) · **Cluster** : kind-securerag-dev (v1.33.1, 1 control-plane + 2 workers) · **Hôte** : EC2 52.90.18.246
**Preuves brutes** : `security-audit-securerag-2026-09-25_20-34-13.txt`

---

## 1. RÉSUMÉ DU SYSTÈME

Cluster kind hébergeant 5 environnements (dev/test/staging/preprod/prod) + plate-forme complète : ArgoCD (GitOps), Kyverno (admission), Falco (runtime), Vault+ESO (secrets), Harbor+Trivy (registry/scan), Velero+etcd-backup (sauvegarde), cert-manager, Prometheus/Grafana/Loki/Alertmanager, Jenkins (CI). Audit **100 % read-only** : aucune modification, l'application et la recherche CIN restent fonctionnelles.

## 2. CARTE DE LA SURFACE D'ATTAQUE

| Frontière | Point d'entrée | État |
|---|---|---|
| Internet → Hôte | SSH :22 (clé seule) | ✅ OK |
| Internet → Hôte | **9080→30080 / 9443→30443 = ArgoCD** | 🔴 **OUVERT publiquement (HTTP 200 vérifié)** |
| Internet → Hôte | 8069/8080/8085/9000/50000/9081 (odoo, pgadmin, jenkins, sonar) | ✅ Bloqués par le SG AWS (test = timeout) |
| Hôte → Cluster | API 6445 (127.0.0.1 uniquement), registry 5001 (127.0.0.1) | ✅ Local seulement |
| Cluster interne | 5 envs isolés par NetPol default-deny + RBAC + PSA restricted | ✅ Solide |

## 3. VULNÉRABILITÉS (priorisées)

| # | Sév. | Vulnérabilité | Vecteur / Preuve | Impact | Correction |
|---|---|---|---|---|---|
| 1 | 🔴 CRITIQUE | **ArgoCD exposé sur Internet** (NodePort 30080/30443 mappés 0.0.0.0:9080/9443) + **secret initial admin jamais roté** (vérifié présent, 3j23h) | `curl https://52.90.18.246:9443 → HTTP 200`. Mot de passe initial lisible dans le secret | Prise de contrôle GitOps → déploiement de manifests arbitraires = **RCE sur tout le cluster** | 1) Restreindre le SG AWS : entrée 9080/9443 uniquement vers ton IP 2) Rotater le mot de passe ArgoCD 3) `kubectl -n argocd delete secret argocd-initial-admin-secret` |
| 2 | 🟠 HAUTE | **Audit logging Kubernetes désactivé** (aucun flag `--audit-*` dans kube-apiserver) | Manifest kube-apiserver sans config d'audit | Aucune traçabilité des actions API (Repudiation) → incident indétectable/irréproducible | Activer via patch kubeadm kind (snippet §5) — indispensable pour un PFE sécurité |
| 3 | 🟡 MOYENNE | Secrets non chiffrés au repos (pas de `--encryption-provider-config`) | Secrets stockés en base64 clair dans etcd | Lecture de tous les secrets si accès etcd/backup | Activer EncryptionConfiguration (aescbc/kms) |
| 4 | 🟡 MOYENNE | Namespaces outils sans NetworkPolicy : monitoring, loki, jenkins, vault, harbor, external-secrets (0 policy) | `kubectl get netpol -n <ns>` = 0 | Pod compromis n'importe où dans le cluster → atteinte Vault/Grafana/registry | Étendre le modèle default-deny aux ns outils |
| 5 | 🟡 MOYENNE | PSA absent sur ns outils (jenkins, monitoring, harbor, vault, kyverno…) + `securerag-monitoring` en **privileged** | Labels PSA vides ; monitoring=privileged | Pods privilégiés admis dans ces namespaces | Labelliser `restricted`/`baseline` sauf exception justifiée (falco, backup) |
| 6 | 🟡 MOYENNE | `automountServiceAccountToken=true` sur 56 pods (toutes les apps + ArgoCD) | Scan pods | Token de SA exposé à tout pod compromis (compromission possible du SA argocd-application-controller) | `automountServiceAccountToken: false` sur SA/deployments n'appelant pas l'API |
| 7 | 🟡 MOYENNE | Applicative : **falco-talon Degraded** (ArgoCD) — réponse runtime partielle ; securerag-secrets/observability/velero/backup Degraded ou OutOfSync | `kubectl get applications -n argocd` | Détection d'incident runtime amoindrie | Réparer/synchroniser les 4 apps concernées |
| 8 | 🟢 BASSE | NodePorts multiples en HTTP sans Ingress/TLS (Grafana 30030, Prometheus 30090, Alertmanager 30093, Jenkins 30085) — bloqués par SG aujourd'hui, fragile | Liste svc NodePort | Si le SG change → données de monitoring exposées en clair | Ingress + cert-manager (déjà installé) |
| 9 | 🟢 BASSE | Version nœud **kindest/node v1.33.1** (≥15 mois de retard de patchs ; CVE-2025-1767 volumes gitRepo connue sur cette ligne — à vérifier sur le flux CVE officiel) | `kubectl version` | Vulnérabilités corrigées dans les patchs suivants | Upgrade image kind vers dernier patch supporté |
| 10 | 🟢 BASSE | Durcissement partiel : `readOnlyRootFilesystem` absent sur 28 conteneurs (Harbor…) ; fail2ban absent ; registry locale sans auth (127.0.0.1) ; pgadmin `:latest` sur l'hôte ; conteneurs hétérogènes (odoo/pgadmin/sonar) sur l'hôte du cluster | Scan + `docker ps` | Réduction de la profondeur défensive | Snapshots rootfs en read-only, fail2ban, séparer les workloads hors-K8s |

**Justifiés/information** : kube-proxy privileged, node-exporter hostPID (standard), etcd-backup privileged+hostPath pki (nécessaire au snapshot etcd, ns dédié privileged), velero SA cluster-admin (rôle produit), kubeadm:cluster-admins.

## 4. THREAT MODEL (STRIDE — synthèse)

| Composant | S | T | R | I | D | E |
|---|---|---|---|---|---|---|
| ArgoCD public | 🔴 admin initial | 🟠 manifests | 🔴 pas d'audit-log | 🟠 repo/creds | 🟠 API publique | 🔴 **cluster-admin effectif** |
| kube-apiserver | 🟢 RBAC strict | 🟢 TLS | 🔴 pas d'audit | 🟡 etcd non chiffré | 🟢 local | 🟢 bindings propres |
| Workloads 5 envs | 🟡 SA tokens montés | 🟢 cosign digest | 🟡 | 🟡 | 🟢 netpol+quota | 🟢 PSA restricted |
| Registry locale | 🟡 sans auth | 🟢 cosign bloque | 🟡 | — | 🟢 localhost | 🟢 |
| Jenkins CI | 🟡 pwd statique | 🟡 pipeline | 🟡 | 🟢 durci (non-root, ro-rootfs) | 🟢 SG fermé | 🟢 ns isolé (à netpol-ler) |

**Scénario red team n°1 (réaliste, facile)** : attaquant Internet → ArgoCD :9443 → login admin (secret initial jamais roté) → `argocd app sync` d'un manifest malveillant (pod privileged) → RCE total du cluster. **Détection : nulle** (pas d'audit-log). C'est le chemin critique à fermer en premier.

## 5. CORRECTIONS PRIORITAIRES (commandes)

**P0 — Fermer l'exposition ArgoCD (aujourd'hui)**
```bash
# Option A : fermer dans le Security Group AWS (entrées 9080, 9081, 9443) ou restreindre à ton IP
# Option B (si exposition volontaire pour la soutenance) : au minimum rotater le mot de passe :
kubectl -n argocd delete secret argocd-initial-admin-secret   # après rotation via UI/CLI
```

**P0 — Activer l'audit logging (patch kubeadm à la création kind)**
```yaml
# kind-with-audit.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
kubeadmConfigPatches:
- |
  apiVersion: kubeadm.k8s.io/v1beta4
  kind: ClusterConfiguration
  apiServer:
    extraArgs:
      audit-log-path: /var/log/kubernetes/audit.log
      audit-log-maxage: "30"
      audit-log-maxbackup: "10"
      audit-log-maxsize: "100"
      audit-policy-file: /etc/kubernetes/audit-policy.yaml
    extraVolumes:
    - name: audit
      hostPath: /var/log/kubernetes
      mountPath: /var/log/kubernetes
      pathType: DirectoryOrCreate
```
(+ pousser un `audit-policy.yaml` level Metadata sur le nœud, puis recréer le cluster ou éditer `/etc/kubernetes/manifests/kube-apiserver.yaml` dans le conteneur control-plane.)

**P1 — Chiffrement des secrets au repos** : EncryptionConfiguration (aescbc) + `--encryption-provider-config` + `kubectl get secrets -A -o yaml | kubectl replace -f -` pour re-chiffrer.

**P1 — NetPol default-deny** pour jenkins, monitoring, loki, vault, harbor, external-secrets (réutiliser le modèle `default-deny-all` des 5 envs).

**P1 — PSA** : `kubectl label ns jenkins pod-security.kubernetes.io/enforce=baseline` (idem monitoring/harbor/vault).

**P2** : `automountServiceAccountToken: false` (SA par défaut des envs + Kyverno policy `forbid-sa-token-mount`) ; upgrade kindest/node ; rebind des port-forwards sur `127.0.0.1` au lieu de `0.0.0.0`.

## 6. POINTS FORTS (à conserver — niveau élevé pour un PFE)

- ✅ **PSA `restricted` sur les 5 environnements** (rare, excellent)
- ✅ **Kyverno : 8 ClusterPolicies en Enforce** dont `verify-cosign-images` avec clé publique (anti-supply-chain réelle)
- ✅ **NetworkPolicies default-deny + allow-listes par microservice** dans chaque env (15/env)
- ✅ **RBAC propre** : 12 tests `can-i` dev→prod tous négatifs (secrets, delete, exec, list, escalate, bind, impersonate, wildcard)
- ✅ Images épinglées par **digest sha256** obligatoire (policy Enforce)
- ✅ kubelet anonymous OFF, etcd mTLS client-cert ON, API locale uniquement
- ✅ SSH clé seule, PasswordAuthentication no
- ✅ Jenkins installé durci : runAsNonRoot, allowPrivilegeEscalation=false, readOnlyRootFilesystem
- ✅ Quotas + LimitRanges dans les 5 envs ; Velero + jobs etcd-backup ; Vault + ESO ; Harbor + Trivy

## 7. SCORING (pondéré, méthode 007)

| Domaine | Poids | Score |
|---|---|---|
| Secrets & identifiants | 20 % | 62/100 |
| Admission / validation (Kyverno, PSA, cosign) | 15 % | 85/100 |
| AuthN/AuthZ (RBAC + exposition ArgoCD) | 15 % | 55/100 |
| Protection des données (etcd, TLS) | 15 % | 45/100 |
| Résilience (quotas, backups) | 10 % | 75/100 |
| Monitoring & traçabilité (stack complète mais audit-log absent) | 10 % | 70/100 |
| Supply chain (digest, cosign, Trivy, registry insecure) | 10 % | 78/100 |
| Compliance / hygiène | 5 % | 70/100 |
| **SCORE FINAL** | | **66/100** |

## 8. VERDICT : 🟠 BLOQUÉ PARTIEL (66/100)

Cluster **remarquablement bien architecturé** (GitOps + admission Enforce + zero-trust inter-envs), **bloqué pour la production** par 2 problèmes corrigeables en moins d'une heure : l'exposition publique d'ArgoCD avec mot de passe initial non roté (CRITIQUE) et l'absence d'audit logging (HAUTE). Après correction de ces 2 points (+ netpols outils et PSA en P1), le score projeté est **≈ 78/100 — Approuvé avec réserves**.

*Audit read-only : aucune ressource modifiée. Application, manuel et recherche CIN non impactés.*
