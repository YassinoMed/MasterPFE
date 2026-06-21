# Runbook de Réponse aux Incidents — SecureRAG Hub

Ce guide opérationnel décrit les procédures à suivre par l'équipe SecOps et DevSecOps lors de la détection d'anomalies ou d'incidents de sécurité sur la plateforme SecureRAG Hub.

---

## Scénario 1 : Shell détecté dans un Pod (Alerte Falco)

**Indicateur** : Une alerte Falco critique de type `A shell was spawned in a container` ou `Notice/Critical` est reçue dans Slack/Loki via `falcosidekick`.

### 1. Procédure d'isolation immédiate du Pod
Afin d'éviter tout mouvement latéral de l'attaquant au sein du cluster K8s, le pod suspect doit être isolé du réseau sans être supprimé (pour conserver sa mémoire vive et son état).

1. Appliquer le label d'isolation sur le pod compromis :
   ```bash
   kubectl label pod <SUSPECT_POD_NAME> -n securerag-hub security.securerag.dev/isolated=true --overwrite
   ```
2. La NetworkPolicy d'isolation bloque immédiatement tout trafic entrant/sortant vers ce pod. Vérifier l'isolation en listant les flux :
   ```bash
   kubectl describe networkpolicy isolated-deny-all -n securerag-hub
   ```
   *(La NetworkPolicy `isolated-deny-all` cible les pods ayant le label `security.securerag.dev/isolated=true` et possède des règles ingress/egress vides).*

### 2. Collecte de preuves forensiques
Ne pas détruire immédiatement le conteneur. Collecter les informations nécessaires à l'analyse post-mortem :

1. Sauvegarder les logs récents du conteneur :
   ```bash
   kubectl logs <SUSPECT_POD_NAME> -n securerag-hub --all-containers=true > forensic_logs.txt
   ```
2. Capturer la configuration courante du pod :
   ```bash
   kubectl get pod <SUSPECT_POD_NAME> -n securerag-hub -o yaml > forensic_pod_spec.yaml
   ```
3. Lancer un pod de debug éphémère attaché aux namespaces réseau/processus du pod suspect pour inspecter l'état (si le cluster le permet) :
   ```bash
   kubectl debug -it <SUSPECT_POD_NAME> -n securerag-hub --image=alpine --target=<SUSPECT_CONTAINER_NAME>
   ```
4. Prendre un snapshot du volume persistant associé (si applicable) pour analyser les fichiers créés/modifiés.

### 3. Notification des parties prenantes
1. Envoyer un rapport d'alerte initial sur le canal d'incident Slack/Teams.
2. Contacter le RSSI / CISO et les lead développeurs responsables du microservice concerné.
3. Créer un ticket Jira Sécurité qualifié de priorité "CRITICAL".

### 4. Rollback et Patch
1. Supprimer le pod compromis pour forcer le ReplicaSet à recréer un pod sain à partir de l'image de base validée par GitOps :
   ```bash
   kubectl delete pod <SUSPECT_POD_NAME> -n securerag-hub
   ```
2. Auditer le code source et le Dockerfile à l'origine du déploiement pour repérer le vecteur d'entrée (RCE, dépendance compromise, etc.).
3. Corriger et déployer une image corrigée via le pipeline Jenkins.

---

## Scénario 2 : CVE CRITICAL découverte en Production

**Indicateur** : Trivy, Renovate ou un bulletin de sécurité remonte une vulnérabilité critique (ex: CVSS score >= 9.0) sur une bibliothèque ou l'image de base Distroless utilisée en production.

### 1. Procédure de mise à jour d'urgence (Hotfix)
1. Créer une branche de correctif d'urgence à partir de `main` :
   ```bash
   git checkout -b hotfix/CVE-XXXX-XXXX
   ```
2. Mettre à jour la version de la dépendance vulnérable (par exemple dans `requirements.txt`, `package.json` ou le Dockerfile).
3. Utiliser un digest d'image de base non vulnérable (mis à jour dans le manifest ou le Dockerfile) :
   ```dockerfile
   FROM gcr.io/distroless/python3-debian12@sha256:new_safe_digest
   ```
4. Pousser la branche de hotfix pour lancer les tests CI locaux. Après validation, fusionner dans la branche principale (`main`).

### 2. Communication équipe / management
1. Envoyer un e-mail/message d'alerte d'urgence décrivant : la nature de la CVE, le score CVSS, les services impactés, et le plan d'action de remédiation.
2. Indiquer l'heure estimée de déploiement du correctif en production (ETA).

### 3. Vérification du blocage par Kyverno
Le contrôleur d'admission Kyverno doit rejeter tout déploiement utilisant l'image vulnérable non patchée.
1. Vérifier que la policy Kyverno bloque le déploiement d'images obsolètes non signées ou avec des digests non valides :
   ```bash
   kubectl get cpol verify-image-signatures -o yaml
   ```
2. Simuler un déploiement avec une ancienne image compromise pour s'assurer que Kyverno renvoie un message de refus d'admission :
   ```bash
   kubectl apply -f test-vulnerable-manifest.yaml
   # Résultat attendu : Error from server: admission webhook "validate.kyverno.svc-fail" denied the request...
   ```

---

## Scénario 3 : Fuite de secret dans le Code (Gitleaks)

**Indicateur** : Gitleaks lève une alerte bloquante lors de l'intégration continue ou du pre-commit, ou un secret est détecté après coup dans l'historique de la branche distante.

### 1. Procédure de rotation immédiate du secret
Dès qu'un secret est exposé dans Git, il doit être considéré comme compromis et révoqué immédiatement.

1. **Révocation** : Désactiver ou révoquer la clé/mot de passe compromis directement sur le service tiers (ex: base PostgreSQL, jeton API tiers, certificat).
2. **Génération** : Générer une nouvelle clé hautement entropique.
3. **Injection** : Enregistrer la nouvelle valeur dans HashiCorp Vault ou sous forme de Secret Kubernetes chiffré par SOPS :
   ```bash
   sops -e -i k8s/deployments/secrets.enc.yaml
   ```
4. Redémarrer les pods consommant ce secret pour charger la nouvelle valeur :
   ```bash
   kubectl rollout restart deployment <IMPACTED_DEPLOYMENT> -n securerag-hub
   ```

### 2. Nettoyage de l'historique Git
Le secret ne doit pas rester visible dans l'historique Git, même si le code a été modifié.

1. Utiliser l'outil `git-filter-repo` (recommandé) ou BFG Repo-Cleaner pour purger le secret de tous les commits :
   ```bash
   git filter-repo --invert-paths --path chemin/vers/fichier_secret
   # OU pour remplacer le texte du secret par un placeholder dans tout l'historique :
   git filter-repo --replace-text expressions-secrets.txt
   ```
2. Effectuer un push forcé sur la branche distante (nécessite des privilèges d'administration temporaires sur le dépôt) :
   ```bash
   git push origin main --force
   ```

### 3. Audit des accès utilisant le secret compromis
1. Extraire les logs d'accès de la base de données ou du service lié à la clé compromise pendant la fenêtre d'exposition (depuis le commit de fuite jusqu'à la révocation).
2. Identifier toute requête ou adresse IP anormale ayant consommé ce secret.
3. Si des données confidentielles médicales ont été consultées, lancer la procédure de notification de violation de données RGPD sous 72 heures.
