# Argumentaire soutenance — SecureRAG Hub

> **Objectif :** préparer les réponses claires et défendables aux questions
> probables du jury, avec preuves à portée de main.

## Phrase d'ouverture recommandée

> « Le cahier des charges initial prévoyait une architecture microservices
> Python / FastAPI. Au cours de l'implémentation, l'équipe a retenu Laravel
> comme runtime principal afin de consolider une plateforme **plus stable,
> testable et intégrable** avec l'environnement DevSecOps. Les services
> Python sont donc conservés comme **piste expérimentale**, tandis que
> Laravel représente la **version officielle démontrable** de SecureRAG Hub. »

## Points clés à mémoriser

### 1. Ce qui est *réellement* implémenté et démontrable

| Composant | Implémentation | Localisation | Preuve |
|-----------|----------------|--------------|--------|
| Portal web + Gateway interne | Laravel | `platform/portal-web` | tests PHPUnit, déployé K8s |
| Auth + utilisateurs + RBAC | Laravel + Sanctum | `services-laravel/auth-users-service` | 26 tests PHP |
| Gestion documents + RAG | Laravel + Qdrant | `services-laravel/chatbot-manager-service` | id |
| Conversations + chat sécurisé | Laravel + WebSockets | `services-laravel/conversation-service` | id |
| Audit sécurité + détection | Laravel | `services-laravel/audit-security-service` | id |
| Pipeline CI Jenkins | Multi-stage | `Jenkinsfile` (10 stages) | `artifacts/security/quality-gate-summary.md` |
| Pipeline CD Jenkins | Build → scan → sign → deploy | `Jenkinsfile.cd` (16 stages) | `artifacts/release/*` |
| Cosign signature | Key-based + verify obligatoire | `scripts/release/sign-images.sh` | `verify-summary.txt` |
| Kyverno policies | 7 policies (Audit mode prêt Enforce) | `infra/k8s/policies/kyverno/` | `kyverno-fixtures-tests.md` |
| Pod Security strict | Tous les workloads | `infra/k8s/base/*/deployment.yaml` | `audit-pod-security.sh` |
| NetworkPolicies | Default-deny + per-service | `infra/k8s/base/networkpolicy-*.yaml` | `audit-networkpolicies.sh` |
| Observabilité | Prometheus + Grafana + Loki + Alertmgr | `infra/k8s/observability/` | dashboards JSON livrés |
| Runtime detection | Falco + falcosidekick | `infra/k8s/runtime-detection/` | rules YAML signées |
| MITRE ATT&CK mapping | 37 techniques cataloguées | `docs/security/mitre-attack-k8s-mapping.md` | 68% couverts |
| Secrets management | SOPS + age | `.sops.yaml`, runbook rotation | `scripts/secrets/rotate-and-verify.sh` |
| Backup / restore drill | CronJob + script isolé | `infra/k8s/backup/`, `scripts/backup/` | `restore-drill.sh` |
| Chaos lite | Pod-delete + preuve self-heal | `scripts/chaos/pod-delete-and-prove.sh` | id |

### 2. Ce qui reste comme perspective

| Item | Statut | Raison |
|------|--------|--------|
| Implémentation Python complète | Perspective | Effort 2-3 semaines · runtime déjà choisi |
| Vault / External Secrets Operator | Perspective | SOPS+age suffit pour la soutenance |
| Cosign keyless via OIDC | Perspective | Key-based fonctionne, migration cosmétique |
| Mesh service (Linkerd / Istio) | Perspective | NetworkPolicies suffisent pour ce périmètre |
| Drift detection alertes Slack live | Perspective | Config présente, webhook non testé en démo |

## Questions probables du jury + réponses

### Q1 : « Pourquoi avez-vous abandonné FastAPI ? »

> Nous n'avons pas abandonné FastAPI au sens absolu — les squelettes sont
> conservés sous `services/` comme référence du cahier des charges initial.
> En revanche, nous avons **priorisé** Laravel pour la démonstration finale
> parce que :
>
> 1. **L'implémentation Laravel était significativement plus avancée** au
>    moment de la décision (~10 000 lignes de code applicatif + 26 fichiers
>    de tests PHPUnit, contre des squelettes vides côté Python).
> 2. **Le pipeline DevSecOps complet** (Jenkins + Trivy + Cosign + Kyverno +
>    Argo CD) était déjà configuré et passait sur le runtime Laravel.
> 3. **Le risque soutenance** : présenter un produit qui marche réellement
>    est plus solide qu'un prototype non livré.
>
> La décision est formalisée comme ADR-001 et tracée dans le repo.

### Q2 : « Le cahier des charges parlait de microservices Python. Vous avez fait du monolithe ? »

> Non. L'architecture reste **microservices**, mais en stack Laravel :
>
> - 1 frontend / API gateway interne : `platform/portal-web`
> - 4 services métier indépendants : `services-laravel/{auth-users,
>   chatbot-manager, conversation, audit-security}`
> - Communication inter-services via HTTP ClusterIP, isolée par
>   NetworkPolicy
> - Chaque service a son propre Dockerfile, son propre Deployment K8s,
>   son propre HPA, sa propre RBAC, sa propre signature Cosign
>
> Donc on respecte **l'esprit du CDC** (architecture distribuée et
> isolée) en changeant seulement le langage d'implémentation.

### Q3 : « Comment garantissez-vous qu'un LLM ne hallucine pas avec une donnée non autorisée ? »

> Trois lignes de défense en profondeur :
>
> 1. **RBAC en amont du vectorstore** : la recherche vectorielle Qdrant
>    filtre par `allowed_roles` / `sensitivity_level` au niveau métadonnées —
>    le LLM ne reçoit jamais de chunk auquel l'utilisateur n'a pas droit.
> 2. **Security Auditor** : avant ET après génération, le prompt et la
>    réponse sont scorés (0-100). Un score ≥ 70 bloque la réponse, 40-69 la
>    marque `FLAGGED`. Voir `services-laravel/audit-security-service/`.
> 3. **Audit logs JSON** : timestamp, session_id, user_id, role, audit_score,
>    action, **prompt_hash + response_hash uniquement** (jamais le contenu
>    brut). Stockés append-only + collectés par Loki.

### Q4 : « Vos images sont signées comment, avec quelle confiance ? »

> Cosign **key-based** (clé privée stockée en Jenkins credential
> `cosign-private-key`, jamais en clair). Vérification obligatoire en CD
> avant promotion, et **Kyverno verifyImages** refuse à l'admission tout
> Pod dont l'image n'est pas signée par la clé attendue.
>
> Migration **keyless / Sigstore OIDC** prévue post-soutenance (perspective).
> Le mode key-based actuel est documenté et testable.

### Q5 : « Vous parlez de Kyverno en mode Audit. Pourquoi pas Enforce ? »

> Les 7 policies sont en mode Audit pour la phase d'observation. La
> bascule vers Enforce est **prête et séquencée** via
> `scripts/deploy/kyverno-enforce-sequenced.sh` qui :
>
> 1. Vérifie absence de violation par policy
> 2. Passe en Enforce une policy à la fois
> 3. Auto-rollback si une violation post-Enforce apparaît
>
> En soutenance, je peux **basculer en Enforce live** sur le namespace de
> démo et montrer un refus d'admission immédiat sur un Pod non conforme.

### Q6 : « Si demain quelqu'un push un secret en clair, que se passe-t-il ? »

> Trois barrières :
>
> 1. **Gitleaks** dans le CI bloque le merge (stage `CI_SECURITY_STATIC`).
> 2. **Trivy fs** scanne aussi les patterns de secret.
> 3. **Kyverno** policy `audit-cleartext-env-values` détecte les ENV
>    suspects à l'admission Pod.
>
> Si malgré tout un secret passe (cas hypothétique), la procédure de
> rotation est documentée : `docs/runbooks/secret-rotation.md`, avec
> drill testable `scripts/secrets/rotate-and-verify.sh`.

### Q7 : « Que se passe-t-il si un pod meurt en production ? »

> Démonstration live possible : `make chaos-pod-delete`.
>
> 1. Kubernetes ReplicaSet recrée le pod immédiatement (PDB protège
>    contre la double-suppression involontaire).
> 2. Probes readiness/liveness garantissent qu'il n'est dans le pool de
>    service qu'une fois sain.
> 3. Le script de chaos sonde l'endpoint HTTP toutes les secondes :
>    self-heal < 60 s, taux d'erreur < 10 % = PASS, archivé dans
>    `artifacts/validation/chaos-pod-delete-*.md`.

### Q8 : « Vous avez parlé de MITRE ATT&CK. Concrètement ? »

> 37 techniques cataloguées dans
> `docs/security/mitre-attack-k8s-mapping.md` ; pour chacune, un mapping
> vers un contrôle SecureRAG + l'artefact de preuve.
>
> **Exemple** : technique `T1611 Privileged container` →
> contrôle Kyverno `require-pod-security` + preuve
> `tests/admission/negative/01-privileged-pod.yaml` (Pod refusé à l'admission).
>
> Couverture actuelle : **68 % en 🟢, 32 % en 🟡, 0 % en 🔴**. Le plan vers
> 90 % est documenté avec 4 PR identifiées.

## Démo live recommandée (10 min)

```bash
# 1. État GitOps (30s)
argocd app list
argocd app get securerag-production

# 2. Quality Gate qui PASS (30s)
make quality-gate

# 3. Quality Gate qui FAIL (montrer la régression bloquée) (1min)
# (modifier un Pod pour ajouter privileged: true puis re-render)

# 4. Kyverno refuse une image non signée (1min)
kubectl apply -f tests/admission/negative/03-unsigned-image.yaml
# → AdmissionReview denied

# 5. Chaos pod-delete avec probe HTTP continue (2min)
make chaos-pod-delete

# 6. Restore drill PG (3min)
make restore-drill

# 7. Falco déclenche un événement de test → Grafana (1min)
kubectl exec -n securerag-hub -it deploy/portal-web -- sh
# → alerte "Terminal shell in container" visible dans Grafana
```

## En cas d'imprévu en démo

Si une commande échoue en live, **rester transparent** :

> « Cette commande dépend d'un composant cluster qui n'est pas levé dans
> cet environnement de présentation. La preuve archivée est disponible
> dans `artifacts/validation/<file>.md` — je peux vous montrer le rapport
> directement. »

Ne **jamais** prétendre qu'une commande non rejouée a réussi. La source
de vérité reste `docs/security/security-status-source-of-truth.md`.

## Documents à avoir ouverts pendant la démo

1. `docs/architecture/decision-001-laravel-as-official-runtime.md`
2. `docs/security/security-readiness-report.md`
3. `docs/security/mitre-attack-k8s-mapping.md`
4. `artifacts/security/quality-gate-summary.md`
5. Ce fichier (`docs/soutenance-argumentaire.md`)
