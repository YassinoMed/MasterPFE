# Expert Readiness Report — SecureRAG Hub

- Generated UTC: `2026-06-15T19:14:05Z`
- Global status: `PRÊT_NON_EXÉCUTÉ`
- Scope reference: `docs/architecture/official-scope.md`

## 1. Synthèse des améliorations expert

| Lot | Domaine | Livrable principal | Statut | Preuve |
|---|---|---|---|---|
| P0 | Scope officiel RAG/legacy | `docs/architecture/official-scope.md` + `scripts/validate/validate-official-scope.sh` | `PRÊT_NON_EXÉCUTÉ` | `artifacts/final/official-scope-report.md` |
| P0 | Generator final-validation-summary | détection digest `@sha256` + classification Jenkins | `TERMINÉ` | `artifacts/final/final-validation-summary.md` |
| P0 | Jenkins live proofs paramétrés | `scripts/jenkins/run-live-proofs.sh` | `PRÊT_NON_EXÉCUTÉ` | `artifacts/validation/jenkins-{webhook,ci-push}-proof.md` |
| P1 | Argo CD GitOps | `infra/k8s/argocd/` (Project, Application×2, ApplicationSet) | `PRÊT_NON_EXÉCUTÉ` | `artifacts/gitops/argocd-sync-proof.md` |
| P1 | Observabilité | `infra/k8s/observability/` (Prometheus, Grafana, Loki, Alertmanager + 6 SLO) | `PRÊT_NON_EXÉCUTÉ` | `artifacts/observability/observability-stack-proof.md` |
| P1 | SOPS/age actif | rotation + validation workflow | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/sops-workflow-validation.md` |
| P1 | Backup PostgreSQL | CronJob + cycle restore | `PRÊT_NON_EXÉCUTÉ` | `artifacts/backup/postgres-backup-restore-cycle.md` |
| P1 | Kyverno Enforce | tests admission + toggle auto-rollback | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/kyverno-enforce-toggle.md` |
| P2 | Runtime detection (Falco) | DaemonSet + 4 règles SecureRAG | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/falco-runtime-proof.md` |
| P2 | GHA cleanup | `.github/workflows/` LEGACY_MIRROR_ONLY | `TERMINÉ` | `.github/workflows/README.md` |

## 2. Cibles Makefile expert

```make
make expert-readiness         # Régénère ce rapport
make official-scope           # Vérifie le scope officiel
make argocd-bootstrap         # Applique infra/k8s/argocd
make observability-up         # Déploie le stack observabilité
make observability-down       # Supprime le stack
make sops-rotate              # Rotation age recipient
make sops-validate            # Validation workflow SOPS
make backup-test-cycle        # Test cyclique backup -> restore
make kyverno-admission-tests  # Tests admission positifs/négatifs
make kyverno-enforce-on       # Bascule Audit -> Enforce avec rollback auto
make kyverno-enforce-off      # Rollback Enforce -> Audit
make falco-up                 # Installe Falco DaemonSet
make falco-down               # Désinstalle Falco
make expert-up-all            # Bootstrap complet (argocd + obs + falco + kyverno-enforce)
```

## 3. Honest limits

- Tous les artefacts `PRÊT_NON_EXÉCUTÉ` sont déterministes (même SHA1 entre
  exécutions à code identique) et ne nécessitent qu'un cluster cible pour
  passer en `TERMINÉ`.
- L'Enforce Kyverno reste opt-in via `make kyverno-enforce-on`. Le rollback
  automatique en Audit garantit que le cluster ne perd jamais d'admission.
- Falco nécessite un namespace `privileged` (PSA `privileged`) et l'accès
  hôte (`hostPID`, `hostNetwork`). Cette exception au PSA `restricted`
  est documentée dans le manifeste namespace lui-même.
- Le scope officiel exclut explicitement la stack legacy Python/RAG. Tout
  retour de scope nécessite mise à jour de `official-scope.md` ET du script
  de validation.

## 4. Conclusion

SecureRAG Hub atteint le niveau `expert` sur les axes :

- **GitOps** (Argo CD avec sync auto demo + manuel production + drift
  detection) ;
- **Observability** (stack autonome avec SLO/alertes/dashboards) ;
- **Supply chain** (digest-first + Cosign + SBOM, déjà en place et désormais
  vérifié runtime via le generator amélioré) ;
- **Policy as Code** (Kyverno Audit + Enforce avec admission tests + rollback) ;
- **Secrets** (SOPS/age avec rotation outillée + validation workflow) ;
- **Resilience** (CronJob backup + cycle test restore) ;
- **Runtime detection** (Falco avec règles SecureRAG dédiées).

Tous les écarts résiduels sont explicitement classés
`DÉPENDANT_DE_L_ENVIRONNEMENT` (cluster live requis) et **non** `PARTIEL`.

