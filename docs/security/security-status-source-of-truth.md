# Security Status Source Of Truth — SecureRAG Hub

## Objectif
Ce document sert de source de vérité sécurité pour éviter les écarts entre documentation, scripts, captures de soutenance et état runtime réel.

## États utilisés
- `TERMINÉ` : le contrôle est implémenté et une preuve locale ou runtime existe.
- `PARTIEL` : une exécution ou une preuve partielle existe, mais elle est incomplète, échouée, incohérente ou non exploitable.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` : le contrôle dépend d’un environnement actif comme Docker, kind, Jenkins, Syft, Cosign, Kyverno ou metrics-server.
- `PRÊT_NON_EXÉCUTÉ` : le contrôle est prêt à être exécuté mais n’a pas encore été rejoué dans l’environnement final.

## Contrôles à ne pas surdéclarer
- Sonar CPD scope : `TERMINÉ` seulement si `bash scripts/ci/validate-sonar-cpd-scope.sh` réussit et génère `artifacts/security/sonar-cpd-scope.md`.
- Sonar Quality Gate : `TERMINÉ` seulement si `bash scripts/ci/run-sonar-analysis.sh` a réellement exécuté `sonar-scanner` avec `SONAR_HOST_URL` et `SONAR_TOKEN`, et si le rapport `security/reports/sonar-analysis.md` indique `TERMINÉ`.
- Trivy image scan : `TERMINÉ` seulement si `artifacts/release/image-scan-summary.txt` contient une ligne `PASS` ou `WARN` par service officiel attendu, sans `FAIL` ni `SKIP`. `WARN` est acceptable uniquement pour les vulnérabilités `HIGH` non bloquantes ; `CRITICAL` reste bloquant.
- SBOM Syft : `TERMINÉ` seulement si `artifacts/release/sbom-summary.txt` contient une ligne `PASS` par service attendu, sans `FAIL` ni `SKIP`, et si `artifacts/sbom/sbom-index.txt` référence des SBOM CycloneDX valides.
- Validation SBOM CycloneDX : `TERMINÉ` seulement si `artifacts/release/sbom-cyclonedx-validation.md` annonce `Status: TERMINÉ`.
- SBOM Cosign attestation : `TERMINÉ` seulement si `artifacts/release/attest-summary.txt` contient une ligne `PASS` par service attendu, sans `FAIL` ni `SKIP`.
- Cosign sign : `TERMINÉ` seulement si `artifacts/release/sign-summary.txt` contient une ligne `PASS` par service attendu, sans `FAIL` ni `SKIP`.
- Cosign verify : `TERMINÉ` seulement si `artifacts/release/verify-summary.txt` contient une ligne `PASS` par service attendu, sans `FAIL` ni `SKIP`.
- Promotion digest : `TERMINÉ` seulement si `artifacts/release/promotion-by-digest-summary.txt` est entièrement en `PASS` et si `artifacts/release/promotion-digests.txt` référence un digest `sha256:` valide par service.
- Attestation release : `TERMINÉ` seulement si `artifacts/release/release-attestation.json` annonce `COMPLETE_PROVEN`.
- Provenance SLSA-style : `TERMINÉ` seulement si `artifacts/release/provenance.slsa.md` annonce `Status: TERMINÉ`, avec digests promus et attestation release `COMPLETE_PROVEN`.
- Gate supply chain : `TERMINÉ` seulement si `scripts/release/assert-supply-chain-evidence.sh` réussit.
- Validation Kyverno hors cluster : `TERMINÉ` seulement si `bash scripts/ci/validate-kyverno-policies.sh` exécute réellement `kyverno apply` avec le CLI Kyverno présent. Sans CLI Kyverno, l’état attendu est `PRÊT_NON_EXÉCUTÉ`, pas `TERMINÉ`.
- Kyverno Audit : `TERMINÉ` seulement si `kubectl get clusterpolicies` et `kubectl get policyreport,clusterpolicyreport -A` répondent sur le cluster cible.
- K8s ultra hardening statique : `TERMINÉ` si `bash scripts/validate/validate-k8s-ultra-hardening.sh` passe et génère `artifacts/security/k8s-ultra-hardening.md`.
- Overlay production HA : `TERMINÉ` seulement si `bash scripts/validate/validate-production-ha.sh` passe et génère `artifacts/security/production-ha-readiness.md`. Cela reste une preuve statique, pas une preuve de tolérance réelle à la perte d'un nœud.
- Preuves runtime production : `TERMINÉ` seulement si `artifacts/validation/production-runtime-evidence.md` ne contient aucun `DÉPENDANT_DE_L_ENVIRONNEMENT` et prouve deployments, pods, PDB, HPA et metrics.
- Sécurité runtime post-déploiement : `TERMINÉ` seulement si `artifacts/security/runtime-security-postdeploy.md` annonce `Status: TERMINÉ` et prouve sur les Pods actifs `runAsNonRoot`, `allowPrivilegeEscalation=false`, `readOnlyRootFilesystem=true`, `capabilities.drop=[ALL]`, `seccompProfile=RuntimeDefault`, `imageID` présent, `ServiceAccount` dédié, `NetworkPolicy`, `PDB` et `HPA`.
- Résilience données : `TERMINÉ` seulement si les images supportent une DB externe, si l'overlay/secret production n'utilise plus SQLite temporaire pour les composants critiques, et si backup + restore sont prouvés.
- Dockerfiles production : `TERMINÉ` seulement si `bash scripts/validate/validate-production-dockerfiles.sh` confirme les images de base pinées par digest, `composer install --no-dev`, l'absence de `git`, `default-mysql-client` et `postgresql-client` dans le runtime, le nettoyage APT, les drivers DB nécessaires et l'utilisateur non-root.
- HA chaos lite : `TERMINÉ` seulement si `artifacts/validation/ha-chaos-lite-report.md` prouve les checks demandés. Les tests mutatifs restent `PRÊT_NON_EXÉCUTÉ` tant que `RUN_POD_DELETE`, `RUN_ROLLOUT_RESTART` ou `RUN_NODE_DRAIN` ne sont pas explicitement activés.
- Secrets production : `TERMINÉ` seulement si `make secrets-management` passe et si `artifacts/security/production-db-secret.md` prouve que `securerag-database-secrets` a été appliqué sur le cluster cible sans exposer les valeurs.
- metrics-server/HPA : `TERMINÉ` seulement si `kubectl top nodes`, `kubectl top pods -n securerag-hub`, `kubectl get hpa -n securerag-hub` et `artifacts/validation/hpa-runtime-report.md` prouvent des HPA sans métriques `<unknown>`.
- Kyverno Enforce local registry blocker : `DÉPENDANT_DE_L_ENVIRONNEMENT` si `artifacts/validation/kyverno-local-registry-enforce-blocker.md` montre que les workloads utilisent `localhost`, `127.0.0.1` ou un autre loopback comme registry OCI pour `verifyImages`.
- Workloads Kubernetes officiels : `portal-web`, `auth-users`, `chatbot-manager`, `conversation-service`, `audit-security-service`.
- `conversation-service` et `audit-security-service` : `TERMINÉ` côté manifests/rendu Kustomize ; `DÉPENDANT_DE_L_ENVIRONNEMENT` pour la preuve de pods `Ready` et logs runtime.
- Runtime legacy Python sous `services/` : `PRÊT_NON_EXÉCUTÉ` / exclu du runtime officiel. Il ne doit pas être présenté comme build-ready tant que les sources applicatives `.py` ne sont pas restaurées.

## Commande de synthèse
```bash
make security-posture
sed -n '1,220p' artifacts/security/security-posture-report.md
```

## Gate release obligatoire
```bash
make supply-chain-execute
bash scripts/release/assert-supply-chain-evidence.sh
```

Cette validation dépend explicitement de Docker, d’un registry joignable, de Trivy, de Syft, de Cosign et des clés ou identités de signature attendues.

## Lecture soutenance
La bonne formulation est :

> Le socle sécurité est implémenté et validé pour la démonstration. Les contrôles avancés de supply chain et d’admission Kubernetes deviennent pleinement prouvés après exécution sur l’environnement final avec les binaires, clés et accès runtime requis.
