# SecureRAG Hub - Script de Soutenance DevSecOps 5-7 Minutes

## Objectif

Présenter la partie DevSecOps de SecureRAG Hub de manière courte, factuelle et défendable.

Ce runbook ne remplace pas les preuves. Il sert de fil conducteur pour la soutenance.

## 0:00 - 0:45 - Positionnement

Dire :

> Le scénario officiel de soutenance est le mode `demo`. Jenkins est l'autorité CI/CD officielle. GitHub Actions est conservé comme historique. Le but n'est pas seulement de montrer un chatbot, mais une plateforme sécurisée, déployable et vérifiable.

Montrer :

```bash
cat artifacts/final/final-validation-summary.md
```

Preuve attendue :

- scénario `demo` ;
- Jenkins comme CI/CD officielle ;
- distinction entre `dry-run`, `execute` et dépendances d'environnement.

## 0:45 - 1:45 - CI qualité et sécurité

Dire :

> La CI vérifie la qualité et la sécurité avant toute promotion : tests, couverture, Ruff, Semgrep, Gitleaks et Trivy.

Montrer :

```bash
ls -lh .coverage-artifacts security/reports
```

Preuves attendues :

- rapport JUnit ;
- couverture ;
- `semgrep.json` ;
- `gitleaks.json` ;
- `trivy-fs.json`.

## 1:45 - 2:45 - Jenkins et automatisation GitHub

Dire :

> Jenkins est configuré pour recevoir les événements GitHub via `/github-webhook/`. Un polling SCM reste présent comme fallback cloud si GitHub ne peut pas joindre Jenkins ou si le checkout est instable.

Montrer :

```bash
make jenkins-webhook-proof
cat artifacts/jenkins/github-webhook-validation.md
```

Preuve attendue :

- endpoint Jenkins joignable ;
- trigger `githubPush()` présent ;
- état du job Jenkins ;
- éventuel avertissement réseau clairement documenté.

Point de vigilance :

- ne pas prétendre qu'un push a déclenché Jenkins si aucun build horodaté ne le prouve.

## 2:45 - 4:00 - Supply chain

Dire :

> La supply chain avancée suit une logique digest-first : signer, vérifier, promouvoir sans rebuild, générer les SBOM et archiver les preuves.

Montrer en préflight :

```bash
SUPPLY_CHAIN_MODE=dry-run make supply-chain-execute
make supply-chain-evidence
cat artifacts/release/supply-chain-evidence.md
```

Montrer en exécution réelle uniquement si l'environnement est prêt :

```bash
make supply-chain-execute
```

Preuves attendues :

- `sign-summary.txt` ;
- `verify-summary.txt` ;
- `promotion-by-digest-summary.txt` ;
- `promotion-digests.txt` ;
- `sbom-index.txt` ;
- `supply-chain-evidence.md`.

Point de vigilance :

- l'exécution réelle dépend de Docker, du registre local, de Cosign, de Syft, des clés et des images sources.

## 4:00 - 5:15 - Kubernetes, metrics-server et Kyverno

Dire :

> Kubernetes exécute le mode demo. Les quotas, limites, NetworkPolicies, PDB et HPA sont intégrés. metrics-server rend les HPA observables. Kyverno ajoute une couche de politique d'admission, d'abord en Audit puis prudemment en Enforce.

Montrer :

```bash
kubectl get pods,svc,hpa,pdb,networkpolicy -n securerag-hub
make cluster-security-proof
cat artifacts/validation/cluster-security-addons.md
```

Preuves attendues :

- pods applicatifs ;
- HPA ;
- metrics API ;
- policies Kyverno ;
- policy reports si disponibles.

Point de vigilance :

- `Enforce` ne doit être activé que lorsque les images signées et les règles Cosign sont alignées.

## 5:15 - 6:30 - Rapport final et support pack

Dire :

> La démonstration se termine par une collecte de preuves : résumé final, readiness DevSecOps et support pack.

Montrer :

```bash
make final-summary
make devsecops-readiness
make support-pack
ls -lh artifacts/support-pack
cat artifacts/final/devsecops-readiness-report.md
```

Preuves attendues :

- `final-validation-summary.md` ;
- `devsecops-readiness-report.md` ;
- support pack `.tar.gz`.

## Conclusion orale

Dire :

> Le socle demo, Kubernetes et Jenkins est opérationnel. Les contrôles CI qualité/sécurité sont validés. Les blocs avancés supply chain, metrics-server et Kyverno sont automatisés et prouvables lorsque l'environnement fournit les prérequis. Cette distinction évite de surpromettre et rend la soutenance techniquement honnête.
