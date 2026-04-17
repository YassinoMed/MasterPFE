# Security Status Source Of Truth — SecureRAG Hub

## Objectif
Ce document sert de source de vérité sécurité pour éviter les écarts entre documentation, scripts, captures de soutenance et état runtime réel.

## États utilisés
- `TERMINÉ` : le contrôle est implémenté et une preuve locale ou runtime existe.
- `PARTIEL` : le contrôle est implémenté ou scripté, mais la preuve complète n’est pas encore disponible.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` : le contrôle dépend d’un environnement actif comme Docker, kind, Jenkins, Syft, Cosign, Kyverno ou metrics-server.
- `PRÊT_NON_EXÉCUTÉ` : le contrôle est prêt à être exécuté mais n’a pas encore été rejoué dans l’environnement final.

## Contrôles à ne pas surdéclarer
- Sonar CPD scope : `TERMINÉ` seulement si `bash scripts/ci/validate-sonar-cpd-scope.sh` réussit et génère `artifacts/security/sonar-cpd-scope.md`.
- Sonar Quality Gate : `TERMINÉ` seulement si `bash scripts/ci/run-sonar-analysis.sh` a réellement exécuté `sonar-scanner` avec `SONAR_HOST_URL` et `SONAR_TOKEN`, et si le rapport `security/reports/sonar-analysis.md` indique `TERMINÉ`.
- Trivy image scan : `TERMINÉ` seulement si `artifacts/release/image-scan-summary.txt` contient une ligne `PASS` par service officiel attendu, sans `FAIL` ni `SKIP`.
- SBOM Syft : `TERMINÉ` seulement si `artifacts/release/sbom-summary.txt` contient une ligne `PASS` par service attendu, sans `FAIL` ni `SKIP`, et si `artifacts/sbom/sbom-index.txt` référence des SBOM CycloneDX valides.
- SBOM Cosign attestation : `TERMINÉ` seulement si `artifacts/release/attest-summary.txt` contient une ligne `PASS` par service attendu, sans `FAIL` ni `SKIP`.
- Cosign sign : `TERMINÉ` seulement si `artifacts/release/sign-summary.txt` contient une ligne `PASS` par service attendu, sans `FAIL` ni `SKIP`.
- Cosign verify : `TERMINÉ` seulement si `artifacts/release/verify-summary.txt` contient une ligne `PASS` par service attendu, sans `FAIL` ni `SKIP`.
- Promotion digest : `TERMINÉ` seulement si `artifacts/release/promotion-by-digest-summary.txt` est entièrement en `PASS` et si `artifacts/release/promotion-digests.txt` référence un digest `sha256:` valide par service.
- Attestation release : `TERMINÉ` seulement si `artifacts/release/release-attestation.json` annonce `COMPLETE_PROVEN`.
- Gate supply chain : `TERMINÉ` seulement si `scripts/release/assert-supply-chain-evidence.sh` réussit.
- Validation Kyverno hors cluster : `TERMINÉ` seulement si `bash scripts/ci/validate-kyverno-policies.sh` exécute réellement `kyverno apply` avec le CLI Kyverno présent. Sans CLI Kyverno, l’état attendu est `PRÊT_NON_EXÉCUTÉ`, pas `TERMINÉ`.
- Kyverno Audit : `TERMINÉ` seulement si `kubectl get clusterpolicies` et `kubectl get policyreport,clusterpolicyreport -A` répondent sur le cluster cible.
- K8s ultra hardening statique : `TERMINÉ` si `bash scripts/validate/validate-k8s-ultra-hardening.sh` passe et génère `artifacts/security/k8s-ultra-hardening.md`.
- Overlay production HA : `TERMINÉ` seulement si `bash scripts/validate/validate-production-ha.sh` passe et génère `artifacts/security/production-ha-readiness.md`. Cela reste une preuve statique, pas une preuve de tolérance réelle à la perte d'un nœud.
- metrics-server/HPA : `TERMINÉ` seulement si `kubectl top nodes`, `kubectl top pods -n securerag-hub` et `kubectl get hpa -n securerag-hub` fonctionnent.
- Workloads Kubernetes officiels : `portal-web`, `auth-users`, `chatbot-manager`, `conversation-service`, `audit-security-service`.
- `conversation-service` et `audit-security-service` : `TERMINÉ` côté manifests/rendu Kustomize ; `DÉPENDANT_DE_L_ENVIRONNEMENT` pour la preuve de pods `Ready` et logs runtime.
- Runtime legacy Python sous `services/` : `PARTIEL` et exclu de la build/deploy officielle tant que les sources applicatives `.py` ne sont pas restaurées.

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
