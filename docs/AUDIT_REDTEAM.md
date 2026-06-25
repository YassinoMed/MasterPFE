# Phase 11 — Red Team Attack Simulation

Ce document modélise cinq scénarios d'attaque réalistes simulant des compromissions de la chaîne DevSecOps et de l'infrastructure de la plateforme **SecureRAG Hub**. Chaque scénario détaille le chemin d'attaque, le rayon d'impact (Blast Radius) et les contre-mesures.

---

## 1. Scénario A : Compromission du Poste Développeur

### 1.1 Chemin d'Attaque
1. Un poste développeur est infecté par un malware (infostealer).
2. L'attaquant extrait les clés SSH d'accès Git et les jetons d'accès personnels (PAT).
3. L'attaquant tente de pousser du code malicieux directement sur la branche principale `main` ou de contourner les pre-commit hooks via `git commit --no-verify`.

```
  Poste Développeur (Infecté) ──> git push --no-verify ──> Dépôt Git ──> Jenkins CI/CD
```

### 1.2 Rayon d'Impact (Blast Radius) : MEDIUM
*   L'attaquant peut introduire une porte dérobée (backdoor) dans le code applicatif.
*   Cependant, le pipeline principal Jenkins s'exécute de manière autoritaire sur chaque push et applique des scans de sécurité systématiques (Semgrep SAST et Gitleaks). La porte dérobée ou l'injection de secret a de fortes chances d'être interceptée par le Quality Gate avant construction.

---

## 2. Scénario B : Compromission du Moteur CI/CD (Jenkins Host Escape)

### 2.1 Chemin d'Attaque
1. L'attaquant accède à la console d'administration Jenkins en exploitant un identifiant faible (`admin:change-me-now` par défaut dans les environnements de démo locaux).
2. L'attaquant configure un Job Jenkins malicieux exécuté sur l'agent de build Docker.
3. Le conteneur de build montant le socket Docker de la machine hôte (`/var/run/docker.sock`), l'attaquant lance un conteneur privilégié avec montage du système de fichiers de l'hôte (`docker run -v /:/host ...`).
4. L'attaquant écrit sa clé SSH dans `/host/root/.ssh/authorized_keys` et s'échappe du conteneur.

```
  Console Jenkins ──> Job Malicieux ──> Socket Docker ──> Privileged Escape ──> Root Hôte VM
```

### 2.2 Rayon d'Impact (Blast Radius) : CRITICAL
*   Compromission complète de la machine physique/VM hébergeant Jenkins et le cluster de développement Kind. Accessibilité à tous les secrets en mémoire et contrôle absolu de l'infrastructure.

---

## 3. Scénario C : Empoisonnement du Container Registry (Registry Poisoning)

### 3.1 Chemin d'Attaque
1. L'attaquant extrait les identifiants en clair du registre de conteneurs local ou Harbor présents dans le dépôt ArgoCD (`application-velero.yaml`).
2. L'attaquant s'authentifie sur le registre et pousse une image malveillante écrasant un tag existant légitime (ex. `securerag-hub/portal-web:latest`).
3. L'attaquant attend que Kubernetes redémarre le pod pour charger l'image compromise.

```
  Secrets en clair ──> Login Harbor ──> Push image empoisonnée (:latest) ──> K8s Pull
```

### 3.2 Rayon d'Impact (Blast Radius) : HIGH
*   *Sans supply chain active* : Compromission immédiate du pod applicatif concerné au redémarrage.
*   *Avec supply chain active* : **Bloqué**. La règle Kyverno `verify-cosign-images` refuse de planifier le pod car l'image poussée par l'attaquant ne dispose pas de la signature cryptographique valide associée au digest attendu (`pin-overlay-digests.sh`).

---

## 4. Scénario D : Compromission de Pod & Élévation de Privilèges dans le Cluster

### 4.1 Chemin d'Attaque
1. L'attaquant exploite une vulnérabilité applicative (ex. exécution de code PHP) sur le pod public `portal-web` pour obtenir un shell interactif.
2. Le jeton de ServiceAccount étant monté par défaut (`automountServiceAccountToken: true`), l'attaquant extrait le jeton dans `/var/run/secrets/kubernetes.io/serviceaccount/token`.
3. L'attaquant interroge l'API Kubernetes pour tenter de lister les secrets d'autres namespaces ou créer des ressources.

```
  RCE PHP (portal-web) ──> Extraction Jeton SA ──> Requêtes API Server K8s
```

### 4.2 Rayon d'Impact (Blast Radius) : LOW / MEDIUM
*   **Bloqué par RBAC** : Le ServiceAccount associé à `portal-web` dispose de privilèges très limités et ne possède pas de droits de lecture ou d'écriture globaux sur l'API Kubernetes. L'attaquant ne peut pas s'élever au niveau administrateur du cluster.
*   **Isolé par NetworkPolicies** : L'attaquant ne peut pas scanner librement le réseau interne pour attaquer d'autres services en raison du blocage default-deny appliqué au namespace.

---

## 5. Scénario E : Vol de Clés de Chiffrement Applicatives (Secrets Theft)

### 5.1 Chemin d'Attaque
1. L'attaquant récupère les 5 fichiers `.env` commis dans l'historique Git public.
2. Il extrait la variable `APP_KEY` (clé AES utilisée par Laravel pour chiffrer les sessions et cookies).
3. L'attaquant forge un cookie de session Laravel chiffré contenant l'identifiant d'un utilisateur administrateur (`user_id: 1`).
4. L'attaquant envoie la requête HTTP avec le cookie forgé et prend le contrôle complet du panneau d'administration de la plateforme sans mot de passe.

```
  Git History ──> Extraction APP_KEY ──> Signature Session Arbitraire ──> Admin Bypass
```

### 5.2 Rayon d'Impact (Blast Radius) : CRITICAL
*   Prise de contrôle complète de la couche applicative (création de chatbots malveillants, accès aux conversations confidentielles de tous les utilisateurs).
