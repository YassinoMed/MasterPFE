# Démonstration SecureRAG Hub - scénario expert 5 à 7 minutes

## Objectif

Présenter SecureRAG Hub comme une plateforme de chatbots métiers sécurisés, construite autour d'un socle DevSecOps démontrable, d'un portail Laravel Blade, de microservices métier Laravel et d'une chaîne Kubernetes locale.

## Séquence recommandée

### 1. Positionnement du projet - 40 secondes

Message à porter :

- SecureRAG Hub n'est pas seulement une interface de chatbot.
- C'est une plateforme sécurisée de gouvernance des chatbots métiers.
- Le scénario officiel est `demo`, volontairement stable pour la soutenance.
- Le mode IA réelle reste une extension optionnelle.

Preuve à afficher :

```bash
make final-summary
```

### 2. Portail métier Blade - 70 secondes

Montrer :

- `/app` pour l'espace utilisateur.
- `/admin` pour la supervision plateforme.
- `/admin/users` et `/admin/roles` pour le RBAC.
- `/chatbots` pour le catalogue métier.
- `/chat`, `/history`, `/security` pour les usages conversation et sécurité.

Message à porter :

- Le portail fonctionne avec fallback mock/API.
- En mode `auto`, il reste démontrable même si un service métier est temporairement indisponible.
- En mode `api`, les erreurs d'intégration sont visibles et assumées.

Preuve à afficher :

```bash
make portal-service-proof
```

### 3. Microservices Laravel et contrats API - 60 secondes

Montrer :

- `services-laravel/auth-users-service`
- `services-laravel/chatbot-manager-service`
- `services-laravel/conversation-service`
- `services-laravel/audit-security-service`
- `docs/openapi/*.yaml`

Message à porter :

- Les services métier sont persistants et testables.
- Les contrats OpenAPI stabilisent l'intégration avec le portail.
- La logique IA reste simulée par contrat, sans prétendre développer un vrai moteur RAG.

Preuve à afficher :

```bash
make laravel-test
```

### 4. DevSecOps officiel Jenkins / Kubernetes - 90 secondes

Montrer :

- Jenkins comme autorité CI/CD.
- GitHub Actions comme historique.
- Kustomize `demo` et `dev`.
- Namespace `securerag-hub`.
- PDB, NetworkPolicies, quotas et limites.

Message à porter :

- La démo est stable et reproductible.
- Les chemins mutatifs sont protégés par variables d'environnement.
- Les limites environnementales sont documentées au lieu d'être cachées.

Preuve à afficher :

```bash
make devsecops-final-proof
```

### 5. Supply chain et preuves - 70 secondes

Montrer :

- `artifacts/release/supply-chain-evidence.md`
- `artifacts/release/release-attestation.md`
- `artifacts/support-pack/*.tar.gz`

Message à porter :

- La chaîne est digest-first et no-rebuild ready.
- L'attestation locale distingue ce qui est présent de ce qui dépend du mode `execute`.
- Cosign, Syft et promotion par digest sont prêts à être exécutés quand l'environnement est complet.

Preuve à afficher :

```bash
make release-attestation
make supply-chain-evidence
```

### 6. Observabilité, SRE et sécurité cluster - 60 secondes

Montrer :

- `artifacts/observability/observability-snapshot.md`
- `docs/runbooks/sre-incident-response.md`
- `docs/security/secrets-management-hardening.md`
- `docs/runbooks/kyverno-install.md`

Message à porter :

- Le projet va au-delà du déploiement : il prépare l'exploitation.
- Metrics-server, HPA et Kyverno sont traités comme preuves runtime dépendantes de l'environnement.
- L'IA assistée analyse et recommande, mais ne remplace pas les contrôles déterministes.

Preuve à afficher :

```bash
make observability-snapshot
```

## Conclusion orale

SecureRAG Hub est démontrable aujourd'hui en mode `demo`, avec un socle DevSecOps structuré, un portail métier Blade, des microservices Laravel, des contrats API et un pack de preuves. Les éléments encore dépendants de l'environnement sont explicitement identifiés : webhook GitHub public, supply chain `execute`, metrics-server, Kyverno runtime et preuves cloud finales.
