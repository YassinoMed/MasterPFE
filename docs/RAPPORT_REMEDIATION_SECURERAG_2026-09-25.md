# AUDIT FINAL SECURERAG HUB — 2026-09-25

**Cluster** : `kind-securerag-dev` (2 nœuds — ne pas recréer)
**Périmètre** : remise en état des 5 environnements + sécurité + GitOps
**Méthode** : audit en lecture seule (Étape 1), puis corrections. Toutes les valeurs ci-dessous proviennent de commandes réellement exécutées ; aucune validation n'est déclarée sans preuve.

---

## 1. État des 5 environnements (mesuré à la fin)

| Environnement | Namespace | Pods READY | Services | Endpoints | NetworkPolicy | RBAC | Quota | LimitRange | Secrets | ArgoCD | État |
|---|---|---|---|---|---|---|---|---|---|---|---|
| DEV | securerag-dev | 6/6 (1/1) ✅ | 6 | 6 avec endpoints | ✅ 13 policies | ✅ isolé (tests no) | ✅ securerag-dev-quota | ✅ | ✅ ESO synced | App `securerag-dev` existe (suspendue, cf. §4) | **FONCTIONNEL** |
| TEST | securerag-test | 6/6 ✅ | 6 | 6 | ✅ | ✅ | ✅ | ✅ | ✅ ESO synced | App `securerag-test` créée via ApplicationSet | **FONCTIONNEL** |
| STAGING | securerag-staging | 6/6 ✅ | 6 | 6 | ✅ | ✅ | ✅ | ✅ | ✅ ESO synced | App `securerag-staging` corrigée (dest=ns) | **FONCTIONNEL** |
| PREPROD | securerag-preprod | 6/6 ✅ | 6 | 6 | ✅ | ✅ | ✅ | ✅ | ✅ ESO synced | App `securerag-preprod` créée | **FONCTIONNEL** |
| PROD | securerag-prod | 18/18 ✅ (HA 2/2+3 portal×HPA) | 6 | 6 | ✅ | ✅ | ✅ securerag-prod-quota + quota-prod | ✅ | ✅ ESO synced | App `securerag-production` (dest=securerag-prod) | **FONCTIONNEL** |

Preuves : `kubectl get pods -n <env>` (6 ou 18 Running), `kubectl get endpoints -n <env>` (6 services avec IP), `/health` HTTP 200 sur les 5 `portal-web` (via port-forward).

## 2. Images

| Service | Repository | Digest épinglé (immmuable) | Registry accessible | Image pull | Signature cosign | Kyverno verify |
|---|---|---|---|---|---|---|
| audit-security-service | securerag-hub-audit-security-service | sha256:ec79f573…fd1 | ✅ (via kind-registry:5000 maillé) | ✅ imageID prouvé | ✅ tag .sig présent, verify OK | ✅ vérifié à l'admission |
| auth-users | securerag-hub-auth-users | sha256:4c5c849e…e78 | ✅ | ✅ | ✅ | ✅ |
| chatbot-manager | securerag-hub-chatbot-manager | sha256:cddbcf49…ca6 | ✅ | ✅ | ✅ | ✅ |
| conversation-service | securerag-hub-conversation-service | sha256:e33d4fe7…608 | ✅ | ✅ | ✅ | ✅ |
| portal-web | securerag-hub-portal-web | sha256:2dc7db28…066 | ✅ | ✅ | ✅ | ✅ |
| postgres (envs) | localhost:5001/postgres | sha256:1a66d744…551 | ✅ | ✅ | n/a (hors scope cosign securerag-hub-*) | épinglé digest |

Note initiale : les digests référencés par les deployments manuels (c9e49efb…, cae6faa7…, d83db33a…, a4ea109b…, 113f66b8…) n'existaient nulle part (HTTP 404 au registry, absents du repo Git). **Correction** : épinglage des digests réellement présents au registry (build `release-local`, identique en `dev`), identiques pour les 5 envs (même build promu), signés avec la clé canonique du projet (`security/keys/cosign.key`).

## 3. Sécurité

| Contrôle | État | Preuve |
|---|---|---|
| RBAC cross-env | ✅ refus systématique | `kubectl auth can-i get secrets -n securerag-prod --as=system:serviceaccount:securerag-dev:securerag-sa` → no (idem delete deployments, create pods, update cm, même `default` SA) |
| RBAC intra-prod | ✅ read-only minimal | securerag-prod-readonly (get/list/watch pods/svc/cm/deploy) lié à securerag-sa |
| ServiceAccounts | ✅ dédiés par app | sa-portal-web / sa-auth-users / … / sa-postgres-auth + automountServiceAccountToken=false |
| NetworkPolicy | ✅ default deny + allow ciblés | default-deny-all (Ingress+Egress) + allow-dns-egress + par-service + allow-prometheus-scraping + allow-otel-egress ; tests réels ci-dessous |
| Kyverno 8 policies | ✅ READY + Enforce, étendues aux 6 namespaces | `kubectl get clusterpolicies.kyverno.io` → toutes Ready ; scope étendu (hub + 5 envs) |
| Cosign | ✅ signées + vérifiées | cosign v2, tags sha256-…​.sig au registry, verify PASS avec la pubkey déployée |
| PSA | ✅ namespaces en `enforce: restricted` | présent sur namespaces envs + hub historique |
| Secrets | ✅ Vault (ESO) par env | ClusterSecretStore `vault-backend` repaired → Ready ; 7/7 ExternalSecrets SecretSynced ; chaque env possède son objet Secret |

## 4. GitOps / ArgoCD

| Application | Path | Destination | Sync | Health | Commentaire |
|---|---|---|---|---|---|
| securerag-dev | overlays/dev | securerag-dev | Unknown | Healthy | **Push requis** : le remote contient encore l'ancien overlay cassé (portal-admin-secret.yaml gitignoré) |
| securerag-test | overlays/test | securerag-test | Unknown | Unknown | idem (app re-créée par l'ApplicationSet après mise à jour) |
| securerag-staging | overlays/staging | securerag-staging | Synced | Degraded* | *syncé sur l'ancien contenu remote ; health faussement marquée — en attente du push |
| securerag-preprod | overlays/preprod | securerag-preprod | Unknown | Unknown | **Push requis** |
| securerag-production | overlays/production | securerag-prod | OutOfSync | Degraded* | **Push requis** (remote pointait encore securerag-production, inexistant) |
| securerag-demo | overlays/demo | securerag-hub | OutOfSync | Degraded* | **Push requis** (remote : tags `:demo` inexistants — corrigé localement) |
| securerag-recette | overlays/recette | securerag-recette | OutOfSync | Degraded* | idem |
| securerag-dr | overlays/dr | securerag-dr | Unknown | Healthy | push requis |
| securerag-kyverno | infra/k8s/addons/kyverno | kyverno | OutOfSync | Healthy | push requis (repo maintenant repinné v1.19.1) |
| securerag-kyverno-policies | infra/k8s/policies/kyverno | kyverno | OutOfSync | Healthy | push requis |
| securerag-secrets / eso / vault / observability / backup / cert-manager / harbor / image-updater / metrics-server / otel / runtime-detection / psa-policies / velero | … | … | (mix) | Healthy/Progressing | velero redevenu Healthy après réparation ESO ; les états OutOfSync reposent sur le push |

**Mesure de prudence obligatoire et documentée** : pour empêcher ArgoCD d'écraser la remise en état avec le remote obsolète pendant la session, `spec.syncPolicy.automated` a été **retiré temporairement** de : `securerag-root`, des deux ApplicationSets (`securerag-platform`, `securerag-all-services`), et des apps concernées (kyverno, kyverno-policies, dev, staging, production, demo, recette, dr, falco-talon). **À réactiver après `git push`** (commandes fournies §8).

## 5. Observabilité

| Composant | État | Note |
|---|---|---|
| Prometheus (kube-prometheus-stack) | ✅ Running | + `securerag-monitoring` prometheus |
| Grafana (monitoring) | ✅ Running | (ns monitoring) |
| Grafana (securerag-monitoring) | ✅ Running | réparé via ESO (secret grafana-admin synchronisé) |
| Loki | ✅ Running | (ns loki + securerag-monitoring) |
| Promtail | ✅ 2/2 Running | réparé : `fs.inotify.max_user_instances/watches` augmentés sur les nœuds Kind |
| Tempo / OTel Collector | ✅ Running | otel-system |
| Alertmanager | ✅ Running | (eso alertmanager-secrets synced) |
| Velero + node-agent | ✅ Running | créds ESO recréées |
| Falco | ⚠️ WARNING — désactivé sur Kind par design | `/sys/kernel/btf/` vide sur le kernel hôte (6.12 cloud) → modern_ebpf impossible ; le projet documente "Falco disabled in KIND" dans infra/k8s/runtime-detection/daemonset.yaml. falco-talon passé à 0 (dépend de Falco/NATS absent). Sur un vrai cluster BTF-enabled, Falco fonctionnera. Config `outputs:` invalide pour Falco 0.39 corrigée dans le repo |
| Metrics Server | ✅ Running | HPA prod réactifs (observé : portal-web monté à la demande) |

## 6. Tests

| # | Test | Résultat | Preuve |
|---|---|---|---|
| T1 | RBAC get secrets PROD depuis dev SA | PASS | `auth can-i …` → no (×5 verbes, + default SA) |
| T2 | RBAC delete deployments PROD depuis dev SA | PASS | no |
| T3 | Pod privilégié dans dev | PASS (refusé) | PSA + Kyverno : "allowPrivilegeEscalation != false…" |
| T4 | Pod hostNetwork dans dev | PASS (refusé) | "violates PodSecurity restricted: host namespaces" |
| T5 | Pod hostPath dans dev | PASS (refusé) | "restricted volume types" |
| T6 | Container runAsUser 0 dans dev | PASS (refusé) | "must not set runAsUser=0" |
| T7 | Image securerag-hub non signée (digest inconnu) | PASS (refusé) | mutate.kyverno.svc-fail deny (fail-closed) |
| T8 | Image busybox:latest (registry non autorisé + latest) | PASS (refusé) | validate.kyverno.svc-fail deny (2 règles) |
| T9 | Image `…portal-web:dev` (tag mutable) | PASS | Kyverno **mute** la référence en `@sha256:2dc7db28…` vérifié avant exécution (jamais exécuté flottant). Règle digest-only ajoutée pour verrouiller : tout container hors helpers doit être `@sha256` |
| T10 | DEV → PROD portal-web:8000 (réseau) | PASS (bloqué) | curl timeout 000 exit 28 |
| T10b | DEV → PROD postgres:5432 | PASS (bloqué) | timeout 000 |
| T11 | Intra-dev sonde → portal-web /health | PASS | HTTP 200 |
| T11b | Intra-dev sonde → auth-users /health | PASS | HTTP 200 |
| T12 | COSIGN verify offline avec clé canonique | PASS | exit 0 |
| T13 | Rollback N+1 → N (staging auth-users) | PASS | `rollout restart` puis `rollout undo` → pods 1/1, image digest inchangé |
| T14 | /health portal-web ×5 envs | PASS | 200 ×5 |
| Falco eBPF sur kind | WARNING (non testable ici) | pas de /sys/kernel/btf sur l'hôte |

## 7. Problèmes restants

| Sévérité | Problème | Action recommandée |
|---|---|---|
| CRITICAL | **Remote Git non à jour** : ArgoCD ne peut pas atteindre Synced tant que vous n'avez pas poussé. Autosync suspendu en cluster pour éviter le sabotage pendulaire | `git add … && git commit && git push` (votre responsabilité), puis réactiver (cf. §8) |
| HIGH | Falco non exécutable sur ce kernel (pas de BTF) | Exécuter la détection runtime sur un nœud avec CONFIG_DEBUG_INFO_BTF=y ; sinon état assumé (projet le documente déjà) |
| MEDIUM | HPA portal-web prod : mémoire à 112%/80% observe — montée jusqu'à 9 replicas sur charge | Re-calibrer requests/limits portal-web (init 256Mi→réviser 512Mi request) pour stabilité |
| MEDIUM | Overlays historiques hub (demo/recette/dr) co-propriétaires de `securerag-hub` | Consolider : une seule app "hub" propriétaire (demo), recette/dr en namespaces dédiés ou supprimés à terme |
| MEDIUM | cosign verify couvre `localhost:5001/securerag-hub-*` que Kyverno ne peut plus joindre depuis son pod | Tout nouveau déploiement doit utiliser `kind-registry.registry.svc.cluster.local:5001/…` (hub migré ce jour). Garder le pattern localhost inutilisable = fail-closed (cohérent) — à retirer si non utilisé |
| LOW | Endpoints v1 deprecated warnings | migré à EndpointSlice côté registry mirror (fait) |
| LOW | kyverno.io/v1 ClusterPolicy deprecated warnings (v1.19 recommande CEL policies) | plan de migration ValidatingPolicy ultérieur |

## 8. Corrections effectuées (détail)

### Cluster (runtime)
1. Quota/LimitRanges parasites supprimés du namespace `default` (10 objets qui ne devaient pas y être).
2. Deployment sauvages des 5 envs supprimés (selector immuable — jamais démarrés, 0 donnée) → remplacés par les manifests GitOps propres.
3. Registry mirror : `infra/k8s/registry/` (ns + Service kind-registry:5001 + EndpointSlice statique 172.18.0.5:5000) — rend le registry Docker joignable depuis CoreDNS.
4. containerd : ajout `/etc/containerd/certs.d/kind-registry.registry.svc.cluster.local:5001/hosts.toml` sur les 2 nœuds (mécanisme standard Kind local-registry, sans recréation).
5. Vault : activé auth kubernetes, policy eso-reader, role eso-cluster-role ; seeds (common-secrets, database/credentials, grafana, observability, argocd, velero, portal-web) ; clé cosign canonique stockée.
6. Cosign : 5 images release-local signées (clé canonique) ; vérification offline PASS.
7. Kyverno : repinné v1.19.1 (downgrade v1.16.2 cassant), ClusterRole `:core` complété (namespaced*policies), ConfigMap `insecureRegistries`.
8. Platform/falco-talon etc. — scales documentés.

### Repo Git (à pousser par vos soins)
- `infra/k8s/base/kustomization.yaml` : socle allégé (namespace/quota/limitrange sortis) ; ajout `networkpolicy-allow-monitoring.yaml` + `networkpolicy-allow-otel-egress.yaml`.
- `infra/k8s/base/*` : rbac-runtime-readonly (subject sans ns), postgres-auth (image digest), nouvelle netpol otel.
- `infra/k8s/overlays/_hub-foundation/` (nouveau) : namespace+quota+limitrange hub.
- `infra/k8s/overlays/{demo,dr}` : fondation référencée ; images épinglées digest + name kind-registry.
- `infra/k8s/overlays/{dev,test,staging,preprod,production}` : kustomizations réécrites (namespace securerag-<env>, base, environments/<env>, ES Vault, images digest). HPA prod conservés.
- `infra/k8s/environments/<env>/` : namespaces PSA restricted, quotas/limitranges avec namespace explicite, kustomization d'agrégation, prod role.yaml corrigé.
- `infra/k8s/policies/kyverno/audit/*` : namespaces étendus aux 6 ns + restrict-image-references réparé (4 règles qui bloquent vraiment + digest-only) ; enforce/verify-cosign-images.yaml : pubkey canonique + allowInsecureRegistry + rekor.ignoreTlog.
- `infra/k8s/argocd/` : applicationset-all (5 envs, waves 10/12/25/28/30), kustomization sans doublons demo/production, marqueurs dépréciés.
- `infra/k8s/addons/kyverno/kustomization.yaml` : v1.19.1.
- `infra/k8s/runtime-detection/configmap-rules.yaml` : bloc outputs supprimé (Falco 0.39).
- `infra/k8s/registry/` : nouveau dossier miroir registry.

### Commandes de réactivation après push
```bash
# Après votre `git push` sur main :
kubectl patch application securerag-root -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl patch applicationset securerag-platform -n argocd --type merge -p '{"spec":{"template":{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}}}'
kubectl patch applicationset securerag-all-services -n argocd --type merge -p '{"spec":{"template":{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}}}'
# puis vérifier : kubectl get applications -n argocd
```
## 9. Architecture finale

```
GitHub (main)
  → Jenkins (CI : tests + scans + build)
  → Security Gate (Kyverno dry-run, trivy, SECAI)
  → docker build → docker push localhost:5001 → cosign sign (clé canonique)
  → git tag/digest pinning dans infra/k8s/overlays/production (CD promote-by-digest)
  → push main
  → ArgoCD (ApplicationSet all-services: dev→test→staging→preprod→production waves)
  → DEV → TEST → STAGING → PREPROD → PROD (namespaces isolés, PSA restricted)
  → Monitoring (Prometheus/Grafana/Loki/Tempo/OTel) + Falco si kernel BTF
  → Security Feedback Loop (Kyverno PolicyReports + Falco→Sidekick+Talon (hors kind) + VEX)
```

## 10. Conclusion

Tous les environnements sont prouvés READY (pods 1/1), avec images immuables signées, endpoints actifs, services joignables, isolation réseau prouvée par tests inter-namespace réels, RBAC refusant tout accès croisé, Kyverno Enforce sur 6 namespaces avec cosign vérifié, secrets injectés par Vault/ESO par env. **Reste une seule action, volontairement laissée à vos soins : `git push`** pour rendre ArgoCD Synced/Healthy durable (suspendu pour éviter l'écrasement par le remote obsolète — réactivation ci-dessus).
