# SecureRAG Hub - DevSecOps Expert Evolution Roadmap

## Diagnostic

SecureRAG Hub possède un bon socle DevSecOps de soutenance : Jenkins officiel, kind, Kustomize, contrôles qualité/sécurité, support pack et runbooks. Le passage vers un niveau plus expert ne consiste pas à ajouter des outils au hasard, mais à renforcer la chaîne de preuve, l'observabilité, la gestion des secrets et les pratiques SRE.

## Vision cible

- CI/CD : Jenkins vérifié au push GitHub, artefacts archivés, fallback assumé.
- Supply chain : build unique, SBOM, signature, vérification, promotion digest-first, attestation.
- Sécurité cluster : metrics-server, HPA observables, Kyverno Audit puis Enforce.
- Observabilité : snapshots reproductibles, puis Prometheus/Grafana/Loki optionnels.
- Secrets : placeholders en Git, secrets réels hors dépôt, stratégie SOPS/Vault documentée.
- SRE : SLO simples, runbooks incidents, preuves de récupération.
- IA assistée : synthèse et recommandation uniquement, jamais décision critique autonome.

## Feuille de route

### Niveau 1 - Gain rapide

- Générer une attestation locale de release.
- Générer un snapshot observabilité.
- Ajouter le tableau de maturité DevSecOps.
- Régénérer le support pack.

### Niveau 2 - Pro crédible

- Valider webhook GitHub avec Jenkins réellement exposé.
- Exécuter supply chain en mode `execute`.
- Installer metrics-server et prouver HPA.
- Installer Kyverno en Audit.
- Archiver policy reports.

### Niveau 3 - Expert moderne

- Activer Kyverno Enforce progressivement.
- Ajouter provenance Cosign attestée.
- Ajouter SOPS ou External Secrets.
- Ajouter Prometheus/Grafana/Loki si ressources suffisantes.
- Ajouter exercices de résilience documentés.

## Tableau d'évolution

| Axe | Niveau actuel | Niveau cible | État | Action restante |
|---|---|---|---:|---|
| CI/CD | Jenkins local + dry-run | Push GitHub prouvé | PARTIEL | Rejouer sur serveur Jenkins actif |
| Supply chain | Scripts prêts | Attestation + Cosign + SBOM + digest | PARTIEL | Exécuter avec images et clés |
| Cluster security | Policies prêtes | Kyverno Audit puis Enforce | PARTIEL | Installer et archiver reports |
| Observabilité | Health checks + preuves | Snapshot + metrics + dashboards optionnels | PARTIEL | Installer metrics-server |
| Secrets | Placeholders + Gitleaks | Rotation + SOPS/Vault optionnel | PARTIEL | Choisir option cible |
| SRE | Runbooks techniques | SLO + incident response | PRÊT | Rejouer les scénarios |
| IA assistée | Concept | Copilote d'analyse encadré | PRÊT | Utiliser seulement sur artefacts |
