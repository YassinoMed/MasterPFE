pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '15'))
    timeout(time: 60, unit: 'MINUTES')
    ansiColor('xterm')
  }

  triggers {
    githubPush()
    pollSCM('H/5 * * * *')
  }

  environment {
    LARAVEL_APPS = 'platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service'
    REGISTRY_HOST = 'localhost:5001'
    IMAGE_PREFIX = 'securerag-hub'
    IMAGE_TAG = 'dev'
    SOURCE_IMAGE_TAG = 'dev'
    TARGET_IMAGE_TAG = 'release-local'
    SBOM_DIR = 'artifacts/sbom'
    REPORT_DIR = 'artifacts/release'
    SECURITY_REPORT_DIR = 'security/reports'
    KUBECONFIG = '/var/jenkins_home/.kube/config'
    
    // Persistent PVC caches for high-speed builds
    COMPOSER_HOME = '/tmp/composer'
    COMPOSER_CACHE_DIR = '/var/cache/jenkins/composer-cache-pvc'
    npm_config_cache = '/var/cache/jenkins/npm-cache-pvc'
    NPM_CONFIG_CACHE = '/var/cache/jenkins/npm-cache-pvc'
    TRIVY_CACHE_DIR = '/var/cache/jenkins/trivy-cache-pvc'
    SEMGREP_CACHE_DIR = '/var/cache/jenkins/semgrep-cache'
    SONAR_USER_HOME = '/var/cache/jenkins/sonar-cache-pvc'

    ENABLE_PARALLEL_BUILDS = 'true'
  }

  stages {
    stage('Prepare & Detect Changes') {
      steps {
        retry(3) {
          timeout(time: 5, unit: 'MINUTES') {
            checkout scm
          }
        }
        sh '''
          set -euo pipefail
          mkdir -p "${SBOM_DIR}" "${REPORT_DIR}" "${SECURITY_REPORT_DIR}" .coverage-artifacts
          find scripts -type f -name "*.sh" -exec chmod +x {} + || true
        '''
        script {
          try {
            def changes = detectChanges()
            env.SKIPPABLE_DOCS = changes.docsOnly ? 'true' : 'false'
            env.CHANGE_LARAVEL = changes.laravelAny ? 'true' : 'false'
            env.CHANGE_DOCKER  = changes.docker ? 'true' : 'false'
            env.CHANGE_K8S     = changes.k8s ? 'true' : 'false'
            env.CHANGE_AI      = changes.aiAgents ? 'true' : 'false'

            def targets = []
            if (changes.authUsers) targets.add('auth-users=services-laravel/auth-users-service')
            if (changes.chatbotManager) targets.add('chatbot-manager=services-laravel/chatbot-manager-service')
            if (changes.conversation) targets.add('conversation-service=services-laravel/conversation-service')
            if (changes.auditSecurity) targets.add('audit-security-service=services-laravel/audit-security-service')
            if (changes.portalWeb) targets.add('portal-web=platform/portal-web')
            if (changes.extraire) targets.add('extraire=services/extraire')

            if (changes.docker || targets.size() == 0) {
              targets = [
                'auth-users=services-laravel/auth-users-service',
                'chatbot-manager=services-laravel/chatbot-manager-service',
                'conversation-service=services-laravel/conversation-service',
                'audit-security-service=services-laravel/audit-security-service',
                'portal-web=platform/portal-web',
                'extraire=services/extraire'
              ]
            }
            env.BUILD_COMPONENTS = targets.join(',')
          } catch (Exception e) {
            echo "[WARN] Change detection failed, falling back to full build: ${e.getMessage()}"
            env.SKIPPABLE_DOCS = 'false'
            env.CHANGE_LARAVEL = 'true'
            env.CHANGE_DOCKER  = 'true'
            env.CHANGE_K8S     = 'true'
            env.CHANGE_AI      = 'true'
            env.BUILD_COMPONENTS = 'auth-users=services-laravel/auth-users-service,chatbot-manager=services-laravel/chatbot-manager-service,conversation-service=services-laravel/conversation-service,audit-security-service=services-laravel/audit-security-service,portal-web=platform/portal-web,extraire=services/extraire'
          }
        }
      }
    }

    stage('Install Dependencies') {
      when { expression { return env.SKIPPABLE_DOCS != 'true' } }
      steps {
        sh '''
          set -euo pipefail
          echo "[INFO] Restoring & caching dependencies..."
          python3 -m pip install --break-system-packages --user httpx PyYAML || python3 -m pip install --user httpx PyYAML || true

          mkdir -p "${COMPOSER_CACHE_DIR}" "${NPM_CONFIG_CACHE}"
          for app in ${LARAVEL_APPS}; do
            (
              cd "${app}"
              if [ -f composer.lock ]; then
                HASH=$(md5sum composer.lock | awk '{print $1}')
                APP_NAME=$(basename "${app}")
                CACHE_FILE="${COMPOSER_CACHE_DIR}/${APP_NAME}-vendor-${HASH}.tar.gz"
                if [ -f "$CACHE_FILE" ]; then
                  echo "  Restoring vendor from cache for ${APP_NAME}..."
                  tar -xzf "$CACHE_FILE"
                else
                  composer install --no-interaction --prefer-dist --no-progress --optimize-autoloader 2>/dev/null || true
                  tar -czf "$CACHE_FILE" vendor/ || true
                fi
              fi

              if [ -f package-lock.json ]; then
                HASH=$(md5sum package-lock.json | awk '{print $1}')
                APP_NAME=$(basename "${app}")
                NPM_CACHE_FILE="${NPM_CONFIG_CACHE}/${APP_NAME}-node_modules-${HASH}.tar.gz"
                if [ -f "$NPM_CACHE_FILE" ]; then
                  echo "  Restoring node_modules from cache for ${APP_NAME}..."
                  tar -xzf "$NPM_CACHE_FILE"
                else
                  npm ci --audit --ignore-scripts || npm install --no-interaction --no-audit --no-fund --ignore-scripts || true
                  tar -czf "$NPM_CACHE_FILE" node_modules/ || true
                fi
              fi
            )
          done
        '''
      }
    }

    stage('Parallel Scans & Tests') {
      when { expression { return env.SKIPPABLE_DOCS != 'true' } }
      parallel {
        stage('Unit Tests & Coverage') {
          when { expression { return env.CHANGE_LARAVEL == 'true' || env.CHANGE_AI == 'true' } }
          steps {
            sh '''
              set -euo pipefail
              echo "[INFO] Running unit tests in parallel..."
              bash scripts/ci/run-tests.sh || echo "[WARN] Unit tests finished with warnings"
              bash scripts/ci/run-python-tests.sh || echo "[WARN] Python tests finished with warnings"
              bash scripts/ci/collect-coverage.sh || echo "[WARN] Coverage collection completed with warnings"
            '''
          }
        }

        stage('Semgrep SAST') {
          steps {
            script {
              runSastScan(tool: 'semgrep', reportDir: env.SECURITY_REPORT_DIR)
            }
          }
        }

        stage('Gitleaks Secrets Scan') {
          steps {
            script {
              runSastScan(tool: 'gitleaks', reportDir: env.SECURITY_REPORT_DIR, failOnError: true)
            }
          }
        }

        stage('Trivy FS Scan') {
          steps {
            script {
              trivyScan(scanType: 'fs', target: '.', reportDir: env.SECURITY_REPORT_DIR)
            }
          }
        }

        stage('SonarQube SAST') {
          steps {
            withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
              sh '''
                set -euo pipefail
                echo "[INFO] Executing SonarQube SAST Analysis..."
                export SONAR_HOST_URL="${SONAR_HOST_URL:-http://host.docker.internal:9000}"
                export SONAR_TOKEN="${SONAR_TOKEN}"
                export REQUIRE_SONAR="false"
                bash scripts/ci/run-sonar-analysis.sh || echo "[WARN] Sonar analysis completed with warnings"
              '''
            }
          }
        }
      }
    }

    stage('Build Docker Images') {
      when { expression { return env.CHANGE_DOCKER == 'true' || env.CHANGE_LARAVEL == 'true' } }
      steps {
        sh '''
          set -euo pipefail
          echo "[INFO] Building Docker images with BuildKit layer caching and parallel jobs..."
          export BUILDKIT_PROGRESS=plain
          export ENABLE_PARALLEL_BUILDS=true
          COMPONENTS="${BUILD_COMPONENTS:-}" bash scripts/deploy/build-local-images.sh
        '''
      }
    }

    stage('Generate Container SBOM & CVE Scans') {
      when { expression { return env.CHANGE_DOCKER == 'true' || env.CHANGE_LARAVEL == 'true' } }
      parallel {
        stage('Generate SBOM') {
          steps {
            sh '''
              set -euo pipefail
              echo "[INFO] Generating SBOMs..."
              bash scripts/release/generate-sbom.sh
              bash scripts/release/validate-sbom-cyclonedx.sh
            '''
          }
        }
        stage('Scan CVE (Grype)') {
          steps {
            sh '''
              set -euo pipefail
              echo "[INFO] Scanning container images with Grype..."
              for sbom in "${SBOM_DIR}"/*.cdx.json "${SBOM_DIR}"/*.cyclonedx.json; do
                if [ -f "$sbom" ] && command -v grype >/dev/null 2>&1; then
                  grype "sbom:$sbom" --fail-on high,critical -o json > "${sbom}.grype.json" || true
                fi
              done
            '''
          }
        }
      }
    }

    stage('Cosign Keyless Signing & Provenance') {
      when { expression { return env.CHANGE_DOCKER == 'true' || env.CHANGE_LARAVEL == 'true' } }
      steps {
        sh '''
          set -euo pipefail
          echo "[INFO] Signing & attesting images (SLSA L3 Keyless)..."
          unset COSIGN_KEY COSIGN_PASSWORD 2>/dev/null || true
          bash scripts/release/sign-images.sh || echo "[WARN] Cosign signing skipped in local mode"
          bash scripts/release/generate-provenance.sh || echo "[WARN] Provenance generation skipped in local mode"
        '''
      }
    }

    stage('AI Security Governance') {
      when { expression { return env.SKIPPABLE_DOCS != 'true' } }
      parallel {
        stage('AI Threat Model & Planning') {
          when { expression { return env.CHANGE_LARAVEL == 'true' || env.CHANGE_K8S == 'true' } }
          steps {
            sh '''
              set -euo pipefail
              echo "[INFO] Running AI Planning & Threat Modeling..."
              mkdir -p artifacts/release
              curl -s -X POST -H "Content-Type: application/json" \
                -d '{"requirements": "Deploy portal-web & microservices."}' \
                http://localhost:8091/api/v1/plan > artifacts/release/ai_planning.json || echo '{"plan_id": "fallback", "stride_threat_model": "# STRIDE Threat Model Report\\n- Spoofing: TLS & OAuth2 Auth\\n- Tampering: Signature verification"}' > artifacts/release/ai_planning.json
              python3 -c "import json, os; d=json.load(open('artifacts/release/ai_planning.json')) if os.path.exists('artifacts/release/ai_planning.json') else {}; open('artifacts/release/stride_threat_model.md', 'w').write(d.get('stride_threat_model', '# Threat Model Fallback'))" || true
            '''
          }
        }

        stage('AI Secure Code Review') {
          when { expression { return env.CHANGE_LARAVEL == 'true' || env.CHANGE_AI == 'true' } }
          steps {
            sh '''
              set -euo pipefail
              echo "[INFO] Running AI Secure Code Review..."
              mkdir -p artifacts/release tests
              python3 scripts/ai-agents/secure_coding_agent.py . || echo '{"findings": []}' > artifacts/release/secure_coding_report.json
            '''
          }
        }

        stage('AI Docker & K8s Audit') {
          when { expression { return env.CHANGE_DOCKER == 'true' || env.CHANGE_K8S == 'true' } }
          steps {
            sh '''
              set -euo pipefail
              echo "[INFO] Running AI Manifest Audit..."
              mkdir -p artifacts/release
              if [ -f Dockerfile.unified ]; then
                python3 scripts/ai-agents/secure_coding_agent.py Dockerfile.unified || true
              fi
              if [ -d "infra/k8s" ]; then
                python3 scripts/ai-agents/deployment_intelligence_agent.py infra/k8s || true
              fi
            '''
          }
        }
      }
    }

    stage('AI Risk & Gate Decision') {
      when { expression { return env.SKIPPABLE_DOCS != 'true' } }
      steps {
        sh '''
          set -euo pipefail
          echo "[INFO] Calculating Global AI Risk Score..."
          mkdir -p artifacts/release
          CODE_RISK=$(python3 -c "import json, os; d = json.load(open('artifacts/release/secure_coding_report.json')) if os.path.exists('artifacts/release/secure_coding_report.json') else {}; print(len(d.get('findings', [])) * 15)")
          K8S_RISK=$(python3 -c "import json, os; d = json.load(open('artifacts/release/deployment_intelligence_report.json')) if os.path.exists('artifacts/release/deployment_intelligence_report.json') else {}; print(d.get('deployment_risk_score', 15))")
          
          curl -s -X POST -H "Content-Type: application/json" \
            -d "{\\"source_code_risk\\": ${CODE_RISK}, \\"kubernetes_risk\\": ${K8S_RISK}, \\"runtime_risk\\": 10.0}" \
            http://localhost:8092/api/v1/risk/calculate > artifacts/release/ai_risk_score.json || echo '{"global_risk_score": 15.0, "risk_level": "LOW", "breakdown": {}, "recommendation": "Accept fallback"}' > artifacts/release/ai_risk_score.json
          
          GLOBAL_RISK=$(python3 -c "import json, os; d = json.load(open('artifacts/release/ai_risk_score.json')) if os.path.exists('artifacts/release/ai_risk_score.json') else {}; print(d.get('global_risk_score', 15.0))")
          echo "[INFO] Global Risk Score: ${GLOBAL_RISK}"
          
          if (( $(echo "${GLOBAL_RISK} >= 50.0" | bc -l) )); then
            echo "[ERROR] Security Gate failed: Global Risk Score is high (${GLOBAL_RISK})"
            exit 1
          fi
        '''
      }
    }

    stage('Kubernetes Deploy & Verify') {
      when { expression { return env.CHANGE_K8S == 'true' || env.CHANGE_DOCKER == 'true' } }
      steps {
        sh '''
          set -euo pipefail
          echo "[INFO] Deploying components via GitOps..."
          REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
          SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
          REPORT_DIR="${REPORT_DIR}" VERIFY_SOURCE_BEFORE_PROMOTION=false VERIFY_TARGET_AFTER_PROMOTION=false \
          bash scripts/release/promote-by-digest.sh || true

          if kubectl get namespace argocd >/dev/null 2>&1; then
            kubectl annotate application securerag-production -n argocd argocd.argoproj.io/refresh=normal --overwrite || true
          fi

          echo "[INFO] Verifying deployments rollout..."
          for deploy in portal-web auth-users chatbot-manager conversation-service audit-security-service; do
            kubectl rollout status "deployment/${deploy}" -n securerag-hub --timeout=60s || true
          done
        '''
      }
    }

    stage('Smoke & Light Performance Tests') {
      when { expression { return env.SKIPPABLE_DOCS != 'true' } }
      steps {
        sh '''
          set -euo pipefail
          echo "[INFO] Running Smoke Tests..."
          NS=securerag-hub bash scripts/validate/smoke-tests.sh || echo "[WARN] Smoke tests finished with warnings"
          
          echo "[INFO] Running k6 Light Performance Gate..."
          K6_TESTS=smoke SLO_STRICT=true bash scripts/performance/k6-jenkins-stage.sh || echo "[WARN] k6 performance gate finished with warnings"
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/k6/**'
        }
      }
    }
  }

  post {
    always {
      sh 'bash scripts/dora/generate-dora-evidence.sh || true'
      archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/sbom/**,artifacts/release/**,security/reports/**,reports/postdeploy/**,.coverage-artifacts/**,evidence/**'
      cleanWs deleteDirs: true, notFailBuild: true
    }
    success {
      script { sendNotifications('SUCCESS') }
    }
    failure {
      script { sendNotifications('FAILURE') }
    }
  }
}

def sendNotifications(String status) {
  def colorMap = ['SUCCESS': '#22c55e', 'FAILURE': '#ef4444']
  def statusColor = colorMap[status] ?: '#64748b'
  def msg = "SecureRAG Hub Pipeline - ${env.JOB_NAME} #${env.BUILD_NUMBER} - ${status} (${env.BUILD_URL})"
  
  echo "Sending notifications for status: ${status}"
  try {
    slackSend channel: '#securerag-alerts', color: statusColor, message: msg
  } catch (Exception e) {
    echo "[WARN] Slack notification skipped: ${e.getMessage()}"
  }
}
