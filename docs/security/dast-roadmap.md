# DAST Roadmap — SecureRAG Hub

## Statut : PERSPECTIVE

Ce document décrit la stratégie d'intégration de tests de sécurité dynamiques (DAST) dans la chaîne DevSecOps SecureRAG Hub.

---

## 1. Rôle du DAST

Le **Dynamic Application Security Testing** (DAST) analyse une application *en cours d'exécution* pour détecter des vulnérabilités exploitables depuis l'extérieur, sans accès au code source.

| Aspect | SAST (actuel) | DAST (perspective) |
|--------|---------------|-------------------|
| **Quand** | Avant le build | Après le déploiement |
| **Comment** | Analyse du code source | Requêtes HTTP sur l'application live |
| **Détecte** | Injections, mauvaises pratiques, secrets | XSS, CSRF, headers manquants, misconfigurations HTTP |
| **Outils** | Semgrep, Gitleaks, Trivy | OWASP ZAP, Nuclei, Burp Suite |
| **Faux positifs** | Élevés (contexte limité) | Faibles (vulnérabilité confirmée runtime) |
| **Couverture** | Code statique uniquement | Comportement runtime réel |

## 2. Pourquoi le DAST n'est pas activé dans la version actuelle

1. **Scope PFE** : le pipeline CI/CD est déjà dense (SAST Semgrep + Gitleaks + Trivy FS + Trivy Image + Cosign + Kyverno). Ajouter un DAST alourdirait la démonstration sans apporter de valeur immédiate dans un cluster local kind.

2. **Pas d'endpoint public stable** : le déploiement cible est un cluster kind local avec accès via NodePort `localhost:8081`. OWASP ZAP nécessite un endpoint réseau accessible depuis le runner.

3. **Temps d'exécution** : un scan ZAP baseline prend 2-5 minutes, un scan complet 15-30 minutes. Cela rallongerait significativement le pipeline CD.

4. **Prérequis** : ZAP nécessite un conteneur Docker dédié ou un agent Jenkins avec ZAP installé.

## 3. Outil recommandé : OWASP ZAP

### Pourquoi OWASP ZAP

- Open source, maintenu par l'OWASP Foundation
- Image Docker officielle `ghcr.io/zaproxy/zaproxy`
- Mode baseline (rapide) et full scan (complet)
- Génère des rapports HTML, JSON, XML
- Intégrable dans Jenkins via le plugin ZAP ou en ligne de commande

### Scan baseline (recommandé pour le pipeline)

```bash
docker run --rm -v "$(pwd)/artifacts/dast:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
  -t http://portal-web.securerag-hub.svc.cluster.local:8000 \
  -r dast-baseline-report.html \
  -J dast-baseline-report.json \
  -l WARN
```

### Scan full (pour audits ponctuels)

```bash
docker run --rm -v "$(pwd)/artifacts/dast:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable zap-full-scan.py \
  -t http://portal-web.securerag-hub.svc.cluster.local:8000 \
  -r dast-full-report.html \
  -J dast-full-report.json
```

## 4. Plan d'intégration Jenkins

### Stage futur dans Jenkinsfile.cd

```groovy
stage('DAST - OWASP ZAP Baseline') {
    when {
        expression { return params.RUN_DAST ?: false }
    }
    steps {
        sh '''
          set -euo pipefail
          mkdir -p artifacts/dast

          # Résoudre l'URL du portail dans le cluster kind
          PORTAL_URL="http://$(kubectl get svc portal-web -n securerag-hub \
            -o jsonpath='{.spec.clusterIP}'):8000"

          docker run --rm --network host \
            -v "$(pwd)/artifacts/dast:/zap/wrk:rw" \
            ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
            -t "${PORTAL_URL}" \
            -r dast-baseline-report.html \
            -J dast-baseline-report.json \
            -l WARN || true
        '''
    }
    post {
        always {
            archiveArtifacts allowEmptyArchive: true,
              artifacts: 'artifacts/dast/**'
        }
    }
}
```

### Prérequis

- [ ] Jenkins runner avec accès au réseau du cluster kind
- [ ] Image ZAP disponible (`docker pull ghcr.io/zaproxy/zaproxy:stable`)
- [ ] Portail Laravel accessible via ClusterIP ou port-forward
- [ ] Paramètre `RUN_DAST` ajouté au Jenkinsfile.cd

### Target Makefile (préparée)

```makefile
dast-baseline: ## Run OWASP ZAP baseline scan against the deployed portal
	@mkdir -p artifacts/dast
	@docker run --rm --network host \
	  -v "$$(pwd)/artifacts/dast:/zap/wrk:rw" \
	  ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
	  -t "http://localhost:8081" \
	  -r dast-baseline-report.html \
	  -J dast-baseline-report.json \
	  -l WARN || true
```

## 5. Vulnérabilités ciblées par le DAST

| Catégorie | Exemples | Détectable par SAST ? | Détectable par DAST ? |
|-----------|----------|----------------------|----------------------|
| XSS réfléchi/stocké | `<script>alert(1)</script>` dans un champ | Partiellement | ✅ Oui |
| CSRF | Absence de token CSRF | Non | ✅ Oui |
| Headers de sécurité | CSP, HSTS, X-Frame-Options manquants | Non | ✅ Oui |
| Information disclosure | Stack traces, versions serveur | Non | ✅ Oui |
| Open redirects | Redirections non validées | Partiellement | ✅ Oui |
| Injection SQL runtime | Requêtes malformées exploitables | Partiellement | ✅ Oui |

## 6. Conclusion

Le DAST complète le SAST sans le remplacer. Son intégration est prévue comme amélioration post-soutenance, lorsque l'environnement de déploiement sera stabilisé avec un endpoint accessible de manière fiable.

---

*Document créé dans le cadre de la finalisation DevSecOps — branche `devsecops-final-hardening`*
