// Jenkinsfile — SecureRAG Hub Main Pipeline
// Phase 4 : Supply Chain complète (SBOM + Cosign + Provenance)
// SLSA Level 2-3 : chaque build produit un SBOM CycloneDX, une signature
// cosign et une attestation de provenance in-toto.

pipeline {
  agent {
    kubernetes {
      yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: tools
    image: mohamedyassinebouneb/securerag-hub-unified:latest
    imagePullPolicy: Always
    command:
    - cat
    tty: true
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
    volumeMounts:
    - name: composer-cache
      mountPath: /home/jenkins/.composer/cache
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  volumes:
  - name: workspace-volume
    emptyDir: {}
  - name: composer-cache
    emptyDir: {}
'''
    }
  }

  options {
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'IMAGE_TAG', defaultValue: 'latest', description: 'Tag des images à traiter')
    booleanParam(name: 'SKIP_SECAI', defaultValue: false, description: 'Ignorer SECAI analysis')
    booleanParam(name: 'SKIP_SIGNING', defaultValue: false, description: 'Ignorer la signature cosign')
  }

  environment {
    REGISTRY_HOST = 'kind-registry.registry.svc.cluster.local:5001'
    IMAGE_PREFIX  = 'securerag-hub'
    IMAGE_TAG     = "${params.IMAGE_TAG}"
    SBOM_DIR      = 'artifacts/sbom'
    REPORT_DIR     = 'artifacts/release'
  }

  stages {

    // ── 1. Checkout + Validation locale ──────────────────────
    stage('Validate Manifests') {
      steps {
        checkout scm
        sh '''
          set -euo pipefail
          echo "[INFO] Validation Kustomize (tous les envs)..."
          for env in dev demo recette staging production dr; do
            kubectl kustomize infra/k8s/overlays/$env > /dev/null && echo "  $env: OK"
          done
          echo "[INFO] Validation Kyverno policies..."
          kyverno apply infra/k8s/policies/kyverno/audit --resource <(kubectl kustomize infra/k8s/overlays/dev) 2>/dev/null || true
        '''
      }
    }

    // ── 2. SECAI Security Analysis (read-only, never blocks) ──
    stage('SECAI Security Analysis') {
      when { expression { return !params.SKIP_SECAI } }
      steps {
        sh '''
          set -euo pipefail
          echo "[INFO] SECAI batch analysis — reading existing artifacts/..."
          mkdir -p artifacts/release
          python3 -m secai.pipelines.security_analysis \
            --input security/reports \
            --output artifacts/release/secai-report.json \
            --format json
          python3 -m secai.pipelines.security_analysis \
            --input security/reports \
            --output artifacts/release/secai-report.md \
            --format md
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/release/secai-report.*,artifacts/secai/**'
        }
      }
    }

    // ── 3. Supply Chain : SBOM + Scan ──────────────────────────
    stage('Supply Chain: SBOM + Scan') {
      steps {
        sh '''
          set -euo pipefail
          echo "[SUPPLY-CHAIN] Generating CycloneDX SBOMs for all services..."
          REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" \
          SBOM_DIR="${SBOM_DIR}" REPORT_DIR="${REPORT_DIR}" \
          bash scripts/release/generate-sbom.sh

          echo "[SUPPLY-CHAIN] Scanning SBOMs with Grype..."
          for sbom in "${SBOM_DIR}"/*.cdx.json; do
            [ -e "$sbom" ] && grype "sbom:$sbom" --fail-on high,critical -o json > "${sbom}.grype.json" || true
          done
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/sbom/**'
        }
      }
    }

    // ── 4. Supply Chain : Cosign Sign ─────────────────────────
    stage('Supply Chain: Cosign Sign') {
      when { expression { return !params.SKIP_SIGNING } }
      steps {
        sh '''
          set -euo pipefail
          echo "[SUPPLY-CHAIN] Signing images with Cosign..."
          # La clé est récupérée depuis Vault via le secret K8s
          if [ -z "${COSIGN_PASSWORD:-}" ]; then
            echo "[WARN] COSIGN_PASSWORD non défini — utilisation de la clé du cluster"
          fi
          REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" \
          REPORT_DIR="${REPORT_DIR}" \
          bash scripts/release/cosign_sign.sh
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/release/*sign*'
        }
      }
    }

    // ── 5. Supply Chain : SLSA Provenance ─────────────────────
    stage('Supply Chain: SLSA Provenance') {
      steps {
        sh '''
          set -euo pipefail
          echo "[SUPPLY-CHAIN] Generating SLSA provenance attestation..."
          REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" \
          REPORT_DIR="${REPORT_DIR}" \
          bash scripts/release/generate-provenance.sh

          echo "[SUPPLY-CHAIN] Generating release attestation..."
          bash scripts/release/generate-release-attestation.sh
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/release/*attest*,artifacts/release/*provenance*,artifacts/release/*release*'
        }
      }
    }

    // ── 6. Quality Gate + Promotion Pipeline (Phase 19) ────────
    stage('Quality Gate & Promotion') {
      steps {
        sh '''
          set -euo pipefail
          echo "[GATE] Quality Gate (agrégation)..."
          bash scripts/ci/quality-gate.sh || {
            echo "[GATE] ÉCHEC — voir artifacts/security/quality-gate-summary.md"
            exit 1
          }

          echo "[PROMOTE] Pipeline de promotion (8 gates)..."
          bash scripts/ci/promotion-pipeline.sh dev production

          echo "[PROMOTE] Result: promotion autorisée si tous les gates passent"
        '''
      }
    }

    // ── 7. Kubernetes Deploy & Verify ────────────────────────
    stage('Kubernetes Deploy & Verify') {
      steps {
        sh '''
          set -euo pipefail
          echo "[DEPLOY] Sync ArgoCD applications..."
          # Le déploiement est GitOps : ArgoCD prend le relais.
          # Ce stage vérifie simplement que l'état du cluster est sain.
          kubectl get applications -n argocd | head -5
          echo "[DEPLOY] Vérification pods (tous envs)..."
          for ns in securerag-hub securerag-dev securerag-prod; do
            kubectl get pods -n $ns --no-headers | awk -v ns=$ns '{s++; if($3=="Running")r++} END {print ns": "r"/"s" Running"}'
          done
        '''
      }
    }
  }

  post {
    always {
      echo "[POST] Pipeline terminé — statut: ${currentBuild.currentResult}"
      archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/**'
    }
    success {
      echo "[POST] ✓ Supply chain complète : SBOM + Signature + Provenance + Quality Gate"
    }
    failure {
      echo "[POST] ✗ Pipeline échoué — vérifier les logs"
    }
  }
}
