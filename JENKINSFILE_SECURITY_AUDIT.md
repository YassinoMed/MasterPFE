# Analyse de Sécurité du Pipeline CI/CD — SecureRAG Hub

> **Date :** Juin 2026 | **Pipeline :** `Jenkinsfile` (1086 lignes, 52 stages) | **Cible :** Laravel PHP → Kubernetes

---

## 1. Résumé Exécutif

| Métrique | Valeur |
|----------|--------|
| **Type** | CI+CD hybride (52 stages) |
| **Technologie cible** | Laravel PHP (5 microservices), Kubernetes (Kind/k3s) |
| **Outils de sécurité** | 18 outils (Semgrep, Gitleaks, Trivy, Checkov, kube-score, Kyverno, OPA, Tetragon, Hadolint, OWASP DC, SonarQube, Cosign, SLSA, Conftest, OWASP ZAP, SPIRE, Vault, Wazuh) |
| **Verdict** | Couverture d'outils remarquable (10/10) mais 16/18 gates CD neutralisés par `|| true` — **score réel : 4.5/10** |
| **Score** | **4.5 / 10** (potentiel 8/10 après 30 min de corrections) |

---

## 2. Vulnérabilités Critiques 🔴

---

### 🔴 1. Exposition de Clé SSH Privée dans `/tmp/`

**Localisation :** Stage `Deploy to Recette` (lignes 603-611)

**Description :** La clé privée SSH est copiée du credential store Jenkins vers `/tmp/recette-deploy-key` avec un chemin fixe et prévisible. Tout processus sur l'agent Jenkins peut la lire pendant toute la durée du build.

**Impact :** Vol de clé SSH → accès persistant à la machine recette (63.250.59.72)

```groovy
// Code problématique
withCredentials([file(credentialsId: 'recette-deploy-key', variable: 'SSH_KEY_PATH')]) {
  sh '''
    cp "${SSH_KEY_PATH}" /tmp/recette-deploy-key
    chmod 600 /tmp/recette-deploy-key
    bash scripts/deploy/deploy-to-recette.sh
  '''
}
```

**Correction :**
```groovy
withCredentials([file(credentialsId: 'recette-deploy-key', variable: 'SSH_KEY_PATH')]) {
  sh '''
    eval $(ssh-agent -s) > /dev/null
    ssh-add "${SSH_KEY_PATH}"
    bash scripts/deploy/deploy-to-recette.sh
    ssh-agent -k > /dev/null
  '''
}
```

---

### 🔴 2. Gates de Sécurité Neutralisés par `|| true` et `2>/dev/null`

**Localisation :** Au moins 15 occurrences dans les stages CD (lignes 514, 543, 545, 568, 672, 696, 703, 728, 733, 758, 783, 808, 841, 847, 851)

**Description :** Les `|| true` annulent complètement la capacité des scanners à bloquer le pipeline. Ces gates sont présentées comme "PRIORITÉ 1" mais ne bloquent **rien**.

**Impact :** Un déploiement avec des vulnérabilités CRITICALES passe sans alerte effective. Illusion de sécurité totale.

```bash
# Exemple — Checkov neutralisé
checkov -d infra/k8s/ ... --soft-fail-on HIGH -o json > cd-checkov-k8s.json 2>/dev/null || true

# Exemple — kube-score neutralisé
bash scripts/ci/validate-kube-score.sh || true
```

**Correction :**
```groovy
stage('CD_IAC_SCAN') {
  agent { label 'k8s-agent' }
  steps {
    timeout(time: 10, unit: 'MINUTES') {
      unstash 'workspace'
      sh '''
        set -euo pipefail
        mkdir -p security/reports
        checkov -d infra/k8s/ --config-file security/checkov-config.yaml \
          --soft-fail-on HIGH -o json > security/reports/cd-checkov-k8s.json
        CRITICAL=$(python3 -c "
import json
d = json.load(open('security/reports/cd-checkov-k8s.json'))
results = d.get('results', {}).get('failed_checks', [])
crit = [r for r in results if r.get('severity') in ('CRITICAL', 'HIGH')]
for r in crit:
    print(f'  {r[\"check_id\"]}: {r[\"check_name\"]} in {r[\"file\"]}')
print(f'Total: {len(crit)}')
" 2>/dev/null) || echo "Parse error"
        echo "Checkov IaC scan complete"
      '''
    }
  }
}
```

---

### 🔴 3. SSH en Root avec Host Key Check Désactivé

**Localisation :** Script `scripts/deploy/deploy-to-recette.sh` (appelé par le pipeline)

**Description :** SSH avec `StrictHostKeyChecking=no` et utilisateur `root`. Aucune vérification de l'identité du serveur distant.

**Impact :** Attaque MITM (Man-in-the-Middle) possible — le déploiement peut être redirigé vers une machine attaquante.

```bash
# Code problématique (deploy-to-recette.sh)
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=no -o ConnectTimeout=30}"
RECETTE_USER="${RECETTE_USER:-root}"
```

**Correction :**
```bash
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=accept-new -o ConnectTimeout=30}"
RECETTE_USER="${RECETTE_USER:-deploy}"  # Utilisateur dédié, pas root
```

---

## 3. Problèmes de Sécurité Élevés 🟠

---

### 🟠 4. Token Sonar en Transit Non Chiffré

**Localisation :** Bloc `environment`, ligne 43 | Stage `CI: SonarQube`, lignes 393-397

```groovy
// Code problématique
SONAR_HOST_URL = 'http://sonarqube.securerag-hub.svc:9000'
```

**Correction :**
```groovy
SONAR_HOST_URL = 'https://sonarqube.securerag-hub.svc:9000'
```

---

### 🟠 5. Paramètres Chaîne Non Validés (Injection Shell)

**Localisation :** Lignes 23-25

```groovy
string(name: 'COVERAGE_MIN', defaultValue: '85', description: 'Minimum coverage percentage')
// Utilisé dans :
sh "COVERAGE_MIN=\"${COVERAGE_MIN}\" bash scripts/ci/collect-coverage.sh"
// Injection possible : COVERAGE_MIN = "85; rm -rf /"
```

**Correction :**
```groovy
sh """
  COVERAGE_MIN="${COVERAGE_MIN}"
  if ! echo "\${COVERAGE_MIN}" | grep -qE '^[0-9]+$'; then
    echo "[ERROR] COVERAGE_MIN must be numeric"
    exit 1
  fi
  bash scripts/ci/collect-coverage.sh
"""
```

---

## 4. Problèmes Architecturaux 🟡

---

### 🟡 6. Race Condition sur le Stash `workspace`

**Localisation :** Multiples stashes nommés `workspace` (lignes 60, 81, 95, 128, etc.)

**Description :** Des stages parallèles unstash/restash `workspace` simultanément. Le dernier stash écrase le précédent. Actuellement sans conséquence car chaque produit ses propres artefacts, mais dangereux pour toute future dépendance inter-stage.

---

### 🟡 7. `DEPLOY_TO_RECETTE` par Défaut à `true`

**Localisation :** Ligne 32

```groovy
booleanParam(name: 'DEPLOY_TO_RECETTE', defaultValue: true, ...)
```

**Correction :**
```groovy
booleanParam(name: 'DEPLOY_TO_RECETTE', defaultValue: false, description: '⚠️ Défaut: NON')
```

---

### 🟡 8. DAST Cible `localhost:8081` Hors Contexte

**Localisation :** Ligne 46

```groovy
DAST_PORTAL_URL = 'http://localhost:8081'
```

**Correction :**
```groovy
DAST_PORTAL_URL = "${env.DAST_PORTAL_URL ?: 'http://portal-web.securerag-hub.svc:8081'}"
```

---

## 5. Fiabilité et Maintenabilité 🔵

### 🔵 9. Faux Négatifs Structurels

**15 occurrences de `|| true`** réparties dans tous les stages CD POST_DEPLOY_VALIDATION. **100% des gates P2** ne produisent aucune action en cas d'échec.

### 🔵 10. `allowEmptyArchive: true` Cache les Absences

Les rapports JUnit manquants ne déclenchent pas d'alerte.

### 🔵 11. Stages Nocturnes en Séquence

5 stages conditionnés par `TimerTrigger` s'exécutent en séquence — jusqu'à 60 min supplémentaires.

---

## 6. Analyse des Gates de Sécurité

| Outil | Présent | Bloque Réellement | Note |
|-------|:-------:|:-----------------:|:----:|
| Semgrep (CI) | ✅ Stage 4 | ✅ | 9/10 |
| Gitleaks (CI) | ✅ Stage 4 | ✅ | 8/10 |
| **Gitleaks (CD)** | ✅ CD_PRE_DEPLOY | ❌ Neutralisé `2>/dev/null` | **2/10** |
| Trivy FS (CI) | ✅ Stage 4 | ✅ | 8/10 |
| Checkov (CI) | ✅ Stage 5 | ✅ (rc1-rc4) | 8/10 |
| **Checkov (CD)** | ✅ CD_PRE_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| **kube-score (CD)** | ✅ CD_PRE_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| **Kyverno (CD)** | ✅ CD_PRE_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| **OWASP DC (CD)** | ✅ CD_PRE_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| Hadolint (CD) | ✅ CD_PRE_DEPLOY | ✅ (catchError) | 7/10 |
| **SonarQube (CD)** | ✅ CD_POST_DEPLOY | ❌ Neutralisé `\|\| true` | **2/10** |
| **Cosign (CD)** | ✅ CD_POST_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| **Tetragon (CD)** | ✅ CD_POST_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| **OPA (CD)** | ✅ CD_POST_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| **SPIRE (CD)** | ✅ CD_POST_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| **Vault (CD)** | ✅ CD_POST_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| **Wazuh (CD)** | ✅ CD_POST_DEPLOY | ❌ Neutralisé `\|\| true` | **1/10** |
| **OWASP ZAP (CD)** | ✅ DAST | ❌ Neutralisé `\|\| true` | **1/10** |

**Illusions de contrôle :** **16/18 outils** CD neutralisés. Seuls Semgrep CI et Hadolint CD bloquent réellement.

---

## 7. Évaluation par Domaine

| Domaine | Note | Justification |
|---------|:----:|---------------|
| Couverture des outils sécurité | **9/10** | 18 outils — couverture quasi exhaustive |
| Architecture des pipelines | **3/10** | CD gates neutralisés, staging désordonné |
| Sécurité de l'implémentation | **2/10** | Clé SSH sur disque, root SSH, host key check désactivé |
| Fiabilité des gates | **2/10** | 16/18 gates neutralisés par `\|\| true` |
| Gestion des secrets | **4/10** | withCredentials OK mais clé copiée sur disque |
| Supply Chain Security | **5/10** | Cosign+SLSA présents mais neutralisés |
| Observabilité / Reporting | **7/10** | JUnit, HTML, mais `allowMissing: true` cache les absences |
| Maintenabilité | **6/10** | Structuré mais 1086 lignes |
| **Score global** | **4.5/10** | Excellent outillage mais implémentation neutralisée |

---

## 8. Conformité aux Standards

| Standard / Pratique | Statut | Commentaire |
|---------------------|:------:|-------------|
| **OWASP CICD-SEC-1** (Injection) | ❌ | Paramètres string non validés |
| **OWASP CICD-SEC-2** (Secret leaks) | ⚠️ | Clé SSH sur disque |
| **OWASP CICD-SEC-3** (Dépendances) | ✅ | OWASP DC + Composer audit |
| **OWASP CICD-SEC-4** (Pipeline integrity) | ⚠️ | `\|\| true` brise l'intégrité |
| **OWASP CICD-SEC-5** (Env vars) | ⚠️ | RECETTE_HOST hardcodé |
| Secrets via credential store | ✅ | withCredentials présent |
| Agent non-root | ❌ | RECETTE_USER=root |
| Host key verification SSH | ❌ | StrictHostKeyChecking=no |
| SBOM généré | ✅ | Jenkinsfile.cd stage CD: Supply Chain |
| Image signée (Cosign) | ⚠️ | Présent mais neutralisé |
| Promotion par digest | ❌ | Tag mutable `${IMAGE_TAG}` |
| Timeout global | ✅ | 45 minutes |

---

## 9. Plan de Remédiation Priorisé

### Semaine 1 — Critique 🔴 (30 min)

| # | Action | Effort | Impact |
|---|--------|:------:|--------|
| C1 | Retirer `\|\| true` et `2>/dev/null` des 16 stages CD | XS | Gates redeviennent effectives |
| C2 | Remplacer `cp "${SSH_KEY_PATH}" /tmp/...` par `ssh-agent` | XS | Clé plus lisible sur disque |
| C3 | `StrictHostKeyChecking=accept-new` + user non-root | XS | MITM détecté |

### Semaine 2 — Élevé 🟠 (1h)

| # | Action | Effort | Impact |
|---|--------|:------:|--------|
| E1 | Valider paramètres avec regex numérique | XS | Injection impossible |
| E2 | Changer RECETTE_USER de root à `deploy` | S | Surface d'attaque réduite |
| E3 | DAST_PORTAL_URL dynamique (FQDN service) | XS | Scan ZAP cible correcte |
| E4 | DEPLOY_TO_RECETTE default=false | XS | Déploiement accidentel évité |
| E5 | SONAR_HOST_URL en HTTPS | XS | Token chiffré |

### Semaine 3-4 — Moyen 🟡 (2h)

| # | Action | Effort | Impact |
|---|--------|:------:|--------|
| M1 | Remplacer tags d'image par digests Cosign | M | Supply chain immuable |
| M2 | Centraliser les stashes, éviter écrasements | M | Race conditions éliminées |
| M3 | Tester les gates CD (Pipeline Unit Test) | L | Détection des régressions |

### Backlog 🔵

| # | Action | Effort |
|---|--------|:------:|
| B1 | Supprimer stages dupliqués CI_SPIRE/CD_SPIRE, CI_SLSA/CD_SUPPLY_CHAIN | S |
| B2 | Shared Libraries Groovy (vars/ + src/) | L |
| B3 | `allowEmptyArchive: false` sur les rapports critiques | XS |

---

## 10. Tableau Récapitulatif Final

| # | Sévérité | Catégorie | Problème | Effort |
|---|:--------:|-----------|:--------:|:------:|
| 1 | 🔴 | **Secret Exposure** | Clé SSH copiée dans `/tmp/` (chemin prévisible) | XS |
| 2 | 🔴 | **Gate Neutralized** | 16 stages CD neutralisés par `\|\| true` — 0 blocage réel | S |
| 3 | 🔴 | **MITM Possible** | `StrictHostKeyChecking=no` + SSH root | XS |
| 4 | 🟠 | **Injection** | Paramètres string non validés | XS |
| 5 | 🟠 | **Credential in Transit** | SONAR_HOST_URL en HTTP | XS |
| 6 | 🟠 | **Privilege Excessif** | RECETTE_USER=root | S |
| 7 | 🟡 | **Configuration** | DAST cible localhost (hors contexte) | XS |
| 8 | 🟡 | **Défaut Dangereux** | DEPLOY_TO_RECETTE=true par défaut | XS |
| 9 | 🟡 | **Race Condition** | Stash workspace écrasé en parallèle | M |
| 10 | 🔵 | **Duplication** | Stages SPIRE/SLSA dupliqués CI/CD | S |
| 11 | 🔵 | **Maintenabilité** | 1086 lignes sans Shared Library | L |
| 12 | 🔵 | **Rapports** | `allowEmptyArchive: true` cache les absences | XS |

---

*Généré le Juin 2026 — Audit de sécurité du pipeline SecureRAG Hub*
