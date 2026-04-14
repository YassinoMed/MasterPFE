# Security Status Source Of Truth — SecureRAG Hub

## Objectif
Ce document sert de source de vérité sécurité pour éviter les écarts entre documentation, scripts, captures de soutenance et état runtime réel.

## États utilisés
- `TERMINÉ` : le contrôle est implémenté et une preuve locale ou runtime existe.
- `PARTIEL` : le contrôle est implémenté ou scripté, mais la preuve complète n’est pas encore disponible.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` : le contrôle dépend d’un environnement actif comme Docker, kind, Jenkins, Syft, Cosign, Kyverno ou metrics-server.
- `PRÊT_NON_EXÉCUTÉ` : le contrôle est prêt à être exécuté mais n’a pas encore été rejoué dans l’environnement final.

## Contrôles à ne pas surdéclarer
- SBOM Syft : terminé seulement si `artifacts/release/sbom-summary.txt` et les fichiers `artifacts/sbom/*-sbom.cdx.json` existent.
- Cosign sign : terminé seulement si `artifacts/release/sign-summary.txt` contient des lignes `PASS`.
- Cosign verify : terminé seulement si `artifacts/release/verify-summary.txt` contient des lignes `PASS`.
- Promotion digest : terminée seulement si `artifacts/release/promotion-digests.txt` existe et référence les digests promus.
- Kyverno Audit : terminé seulement si `kubectl get clusterpolicies` et `kubectl get policyreports -A` répondent sur le cluster cible.
- metrics-server/HPA : terminé seulement si `kubectl top pods -n securerag-hub` fonctionne.

## Commande de synthèse
```bash
make security-posture
sed -n '1,220p' artifacts/security/security-posture-report.md
```

## Lecture soutenance
La bonne formulation est :

> Le socle sécurité est implémenté et validé pour la démonstration. Les contrôles avancés de supply chain et d’admission Kubernetes deviennent pleinement prouvés après exécution sur l’environnement final avec les binaires, clés et accès runtime requis.
