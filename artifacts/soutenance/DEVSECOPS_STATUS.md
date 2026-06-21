# État de l'Art DevSecOps : SecureRAG Hub (Bloc A & B Validés)

Ce document atteste de la maturité de la chaîne d'intégration et de livraison continue de l'infrastructure SecureRAG Hub.

## 1. Intégration Continue (CI)
* **Déclencheur (Trigger)** : Automatique 🟢 (Webhook GitHub connecté via polling SCM ou tunnel).
* **Preuve d'exécution** : `jenkins-runtime-evidence.json` disponible dans les artifacts de release.
* **Scan Statique (SAST/Secrets)** : Outils complets via Semgrep & Gitleaks insérés statiquement en stage Jenkins.

## 2. Sécurisation Supply Chain (Release)
* **SBOM (Software Bill of Materials)** : Analyse et génération de nomenclatures (`.cdx.json`) complétées.
* **Signature & Vérification** : Cryptographie asymétrique via Cosign avec *Verify* strict conditionnant la promotion.
* **Promotion Immuable** : La promotion d'un environnement (dev) à l'autre (release) repose exclusivement sur le digest SHA256 testé, empêchant le "tag drift".

## 3. Livraison Continue (CD)
* **No-Rebuild Deployment** : Empêchement strict par configuration Kustomize et digests de rebuild de l’image une fois validée.
* **Release Attestation** : Regroupement systématique et signature finale au sein du "Support Pack" des livrables garantissant une chaîne de confiance SLSA type 3 minimaliste.

**Conclusion DevSecOps : OPÉRATIONNELLEMENT PROBABILISÉ.** L'intégration des best-practices s'étend bien au-delà de configurations isolées pour converger sur un process de *Trusted Software Supply Chain*.
