// Jenkinsfile — SecureRAG Hub CI (Distributed Edition)
// Agents spécialisés Kubernetes pour exécution parallèle.
pipeline {
  agent none

  triggers {
    githubPush()
    cron('H 2 * * *')  // Nightly at ~2 AM for backup validation + dependency updates
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 45, unit: 'MINUTES')
  }

  parameters {
    booleanParam(name: 'RUN_SONAR', defaultValue: true, description: 'Run Sonar analysis')
    booleanParam(name: 'ENFORCE_QUALITY_GATE', defaultValue: true, description: 'Run consolidated Quality Gate')
    booleanParam(name: 'DEPLOY_VAULT', defaultValue: false, description: 'Deploy Vault + External Secrets Operator')
    booleanParam(name: 'DEPLOY_VELERO', defaultValue: false, description: 'Deploy Velero + MinIO backup')
    string(name: 'COVERAGE_MIN', defaultValue: '85', description: 'Minimum coverage percentage')
    string(name: 'KUBE_SCORE_MAX_CRITICAL', defaultValue: '0', description: 'Max CRITICAL kube-score findings')
    string(name: 'KUBE_SCORE_MAX_WARNINGS', defaultValue: '0', description: 'Max WARNING kube-score findings')
    booleanParam(name: 'RUN_SPIRE_VALIDATION', defaultValue: true, description: 'Run SPIRE validation')
    booleanParam(name: 'RUN_TRIVY_OPERATOR', defaultValue: true, description: 'Run Trivy Operator scan')
    booleanParam(name: 'RUN_CIS_BENCHMARK', defaultValue: false, description: 'Run CIS benchmark (nightly only)')
    booleanParam(name: 'RUN_POLICY_AS_CODE', defaultValue: true, description: 'Run Policy-as-Code (Conftest) validation')
    booleanParam(name: 'RUN_SLSA_VERIFY', defaultValue: false, description: 'Run SLSA provenance verification')
    booleanParam(name: 'RUN_SIEM_VALIDATION', defaultValue: false, description: 'Run SIEM validation (nightly)')
    booleanParam(name: 'DEPLOY_TO_RECETTE', defaultValue: true, description: 'Deploy to recette (63.250.59.72)')
    booleanParam(name: 'RUN_CD_VALIDATION', defaultValue: true, description: 'Run CD post-deploy validation gates')
  }

  environment {
    LARAVEL_APPS = 'platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service'

    // CD Pipeline — Host & Tools
    RECETTE_HOST = '63.250.59.72'
    RECETTE_USER = 'root'
    SSH_KEY_FILE = '/tmp/recette-deploy-key'
    SONAR_HOST_URL = 'http://sonarqube.securerag-hub.svc:9000'
    VAULT_ADDR = 'http://vault.vault.svc:8200'
    WAZUH_API_URL = 'https://wazuh-dashboard.securerag-hub.svc:55000'
    DAST_PORTAL_URL = 'http://localhost:8081'
    REPORT_DIR = 'security/reports'
  }

  stages {

    // ════════════════════════════════════════════════════════════════
    //  STAGE 1 — Checkout (Controller)
    // ════════════════════════════════════════════════════════════════
    stage('Checkout') {
      agent { label 'master' }
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          checkout scm
          stash name: 'workspace', includes: '**'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 2 — Install Dependencies (any agent)
    // ════════════════════════════════════════════════════════════════
    stage('Install Dependencies') {
      agent { label 'master' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh '''
            set -euo pipefail
            find scripts -type f -name "*.sh" -exec chmod +x {} +
            mkdir -p security/reports .coverage-artifacts
            for app in ${LARAVEL_APPS}; do
              (cd "${app}" && composer install --no-interaction --prefer-dist --no-progress 2>/dev/null)
            done
          '''
          stash name: 'workspace', includes: '**'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 3 — PARALLEL: Lint + Tests + Coverage
    // ════════════════════════════════════════════════════════════════
    stage('CI: Lint & Tests') {
      parallel {
        stage('Lint') {
          agent { label 'master' }
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'make lint'
            }
          }
        }
        stage('Laravel Tests + Coverage') {
          agent { label 'test-agent' }
          steps {
            timeout(time: 15, unit: 'MINUTES') {
              unstash 'workspace'
              sh '''
                set -euo pipefail
                mkdir -p .coverage-artifacts
                COVERAGE_MIN="${COVERAGE_MIN}" ENFORCE_COVERAGE_GATE=true bash scripts/ci/run-tests.sh
              '''
              stash name: 'coverage-artifacts', includes: '.coverage-artifacts/**'
              stash name: 'junit-reports', includes: '.coverage-artifacts/junit-*.xml'
            }
            post { always { junit allowEmptyResults: true, testResults: '.coverage-artifacts/junit-*.xml' } }
          }
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 4 — PARALLEL: SAST Scans
    // ════════════════════════════════════════════════════════════════
    stage('CI: SAST & Secrets') {
      parallel {
        stage('Semgrep SAST') {
          agent { label 'security-agent' }
          steps {
            timeout(time: 15, unit: 'MINUTES') {
              unstash 'workspace'
              sh '''
                set -euo pipefail
                mkdir -p security/reports
                semgrep scan --config security/semgrep/semgrep.yml --json -o security/reports/semgrep.json --error
                semgrep scan --config security/semgrep/semgrep.yml --sarif -o security/reports/semgrep.sarif
              '''
              stash name: 'semgrep-report', includes: 'security/reports/semgrep.*'
            }
          }
        }
        stage('Gitleaks Secrets') {
          agent { label 'security-agent' }
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh '''
                set -euo pipefail
                mkdir -p security/reports
                gitleaks dir . --config .gitleaks.toml --report-format json --report-path security/reports/gitleaks.json
              '''
              stash name: 'gitleaks-report', includes: 'security/reports/gitleaks.json'
            }
          }
        }
        stage('Trivy FS') {
          agent { label 'docker-agent' }
          steps {
            timeout(time: 10, unit: 'MINUTES') {
              unstash 'workspace'
              sh '''
                set -euo pipefail
                mkdir -p security/reports
                trivy fs --config security/trivy/trivy-fs.yaml --ignorefile .trivyignore \
                  --format json --output security/reports/trivy-fs.json .
              '''
              stash name: 'trivy-fs-report', includes: 'security/reports/trivy-fs.json'
            }
          }
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 5 — PARALLEL: IaC Scans
    // ════════════════════════════════════════════════════════════════
    stage('CI: IaC Scanning') {
      parallel {
        stage('Checkov') {
          agent { label 'k8s-agent' }
          steps {
            timeout(time: 10, unit: 'MINUTES') {
              unstash 'workspace'
              sh '''
                set -euo pipefail
                mkdir -p security/reports
                set +e
                checkov -d . --config-file security/checkov-config.yaml --skip-path vendor --skip-path node_modules --hard-fail-on CRITICAL --soft-fail-on HIGH -o junitxml > security/reports/checkov-k8s.xml
                rc=$?
                touch security/reports/checkov-helm.xml security/reports/checkov-docker-platform.xml security/reports/checkov-docker-services.xml
                set -e
                if [ $rc -ne 0 ]; then
                  echo "[ERROR] Checkov scan failed."
                  exit 1
                fi
              '''
              stash name: 'checkov-reports', includes: 'security/reports/checkov-*.xml'
            }
            post { always { junit allowEmptyResults: true, testResults: 'security/reports/checkov-*.xml' } }
          }
        }
        stage('kube-score + Kyverno') {
          agent { label 'k8s-agent' }
          steps {
            timeout(time: 10, unit: 'MINUTES') {
              unstash 'workspace'
              sh '''
                set -euo pipefail
                mkdir -p artifacts/security
                bash scripts/validate/validate-k8s-ultra-hardening.sh
                REQUIRE_KYVERNO_CLI=true bash scripts/ci/validate-kyverno-policies.sh
                STRICT_KUBE_SCORE=true KUBE_SCORE_MAX_CRITICAL="${KUBE_SCORE_MAX_CRITICAL:-0}" KUBE_SCORE_MAX_WARNINGS="${KUBE_SCORE_MAX_WARNINGS:-0}" bash scripts/ci/validate-kube-score.sh
              '''
              stash name: 'k8s-reports', includes: 'artifacts/security/*.md,artifacts/security/kube-score-*'
            }
          }
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 5b — Platform Tools + OPA Gatekeeper + Tetragon
    // ════════════════════════════════════════════════════════════════
    stage('CI: Platform Tools Validation') {
      parallel {
        stage('OPA Gatekeeper') {
          agent { label 'k8s-agent' }
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/validate-opa-gatekeeper.sh'
            }
          }
        }
        stage('Tetragon Policies') {
          agent { label 'k8s-agent' }
          steps {
            timeout(time: 3, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/validate-tetragon-policies.sh'
            }
          }
        }
        stage('Platform Tools') {
          agent { label 'k8s-agent' }
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh '''
                set -euo pipefail
                mkdir -p artifacts/security
                bash scripts/ci/validate-platform-tools.sh
              '''
            }
          }
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 6 — Coverage Merge + Dependency Audit
    // ════════════════════════════════════════════════════════════════
    stage('CI: Coverage Gate') {
      agent { label 'test-agent' }
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          unstash 'workspace'
          unstash 'coverage-artifacts'
          sh '''
            set -euo pipefail
            COVERAGE_MIN="${COVERAGE_MIN}" bash scripts/ci/collect-coverage.sh
          '''
        }
      }
      post {
        always { archiveArtifacts allowEmptyArchive: true, artifacts: '.coverage-artifacts/coverage*.xml,.coverage-artifacts/coverage-summary.txt' }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 7 — PARALLEL: Dependency Audit + Hadolint + OWASP DC
    // ════════════════════════════════════════════════════════════════
    stage('CI: Dependency & Container Audit') {
      parallel {
        stage('Composer + npm Audit') {
          agent { label 'master' }
          steps {
            timeout(time: 10, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/audit-dependencies.sh'
            }
          }
        }
        stage('Hadolint Dockerfile') {
          agent { label 'master' }
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/run-hadolint.sh'
            }
            post { always { junit allowEmptyResults: true, testResults: 'security/reports/hadolint-junit.xml' } }
          }
        }
        stage('OWASP Dependency-Check') {
          agent { label 'docker-agent' }
          steps {
            timeout(time: 20, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/run-owasp-dependency-check.sh'
            }
          }
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 8 — Security Scoping Engine (Scope-Aware Gate)
    // ════════════════════════════════════════════════════════════════
    stage('CI: Security Scoping Engine') {
      agent { label 'k8s-agent' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh '''
            set -euo pipefail
            mkdir -p security/reports artifacts/security

            echo "═════════════════════════════════════════════════════"
            echo "  Security Scoping Engine v1.0"
            echo "═════════════════════════════════════════════════════"

            # ── 1. Classifier: scan repo paths ──────────────────
            echo "[INFO] Running Security Classifier..."
            bash security/engine/security-classifier.sh --list-all > artifacts/security/scope-classification.txt 2>/dev/null || true
            echo "[INFO] Classification complete: $(wc -l < artifacts/security/scope-classification.txt) paths classified"

            # ── 2. Semgrep Scoped Scan (PRODUCTION only) ─────────
            echo "[INFO] Running Semgrep scoped scan (PRODUCTION scope)..."
            semgrep scan --config security/semgrep/semgrep-scope.yml \
              --json -o security/reports/semgrep-scope.json 2>/dev/null || true
            SEMGREP_COUNT=$(python3 -c "import json; d=json.load(open('security/reports/semgrep-scope.json')); print(len(d.get('results',[])))" 2>/dev/null || echo "0")
            echo "[INFO] Semgrep scoped: ${SEMGREP_COUNT} findings in PRODUCTION scope"

            # ── 3. Trivy Scoped Scan (PRODUCTION only) ───────────
            echo "[INFO] Running Trivy scoped scan (PRODUCTION scope)..."
            bash security/trivy/trivy-scope.sh json 2>&1 || true

            # ── 4. Gitleaks Scoped Scan ──────────────────────────
            echo "[INFO] Running Gitleaks (already scope-aware via config)..."
            # Gitleaks already uses .gitleaks.toml with proper allowlist

            # ── 5. Gate Decision Engine ──────────────────────────
            echo ""
            echo "[INFO] Running Gate Decision Engine..."
            GATE_EXIT=0
            bash security/engine/gate-decision-engine.sh \
              --trivy security/reports/trivy-scope.json \
              --semgrep security/reports/semgrep-scope.json \
              --gitleaks security/reports/gitleaks.json \
              --output artifacts/security/gate-decision-summary.md || GATE_EXIT=$?

            # Display gate summary
            cat artifacts/security/gate-decision-summary.md 2>/dev/null || true

            echo ""
            echo "[INFO] Security Scoping Engine completed (exit: ${GATE_EXIT})."

            # FAIL only for PRODUCTION HIGH/CRITICAL
            if [[ "${GATE_EXIT}" -eq 1 ]]; then
              echo "[FAIL] Security Gate BLOCKED: PRODUCTION-scope HIGH/CRITICAL vulnerabilities found."
              exit 1
            fi
          '''
        }
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/trivy-scope*.json,security/reports/semgrep-scope*.json,artifacts/security/gate-decision-summary.md,artifacts/security/scope-classification.txt'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 9 — SonarQube Analysis
    // ════════════════════════════════════════════════════════════════
    stage('CI: SonarQube') {
      when { expression { return params.RUN_SONAR } }
      agent { label 'sonar-agent' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
            sh '''
              set -euo pipefail
              REQUIRE_SONAR=true SONAR_HOST_URL="${SONAR_HOST_URL:-}" SONAR_TOKEN="${SONAR_TOKEN}" \
                bash scripts/ci/run-sonar-analysis.sh
            '''
          }
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 10 — Quality Gate (Aggregated Verdict)
    // ════════════════════════════════════════════════════════════════
    stage('CI: Quality Gate') {
      when { expression { return params.ENFORCE_QUALITY_GATE } }
      agent { label 'master' }
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          unstash 'workspace'
          unstash 'coverage-artifacts'
          unstash 'semgrep-report'
          unstash 'gitleaks-report'
          unstash 'trivy-fs-report'
          unstash 'checkov-reports'
          unstash 'k8s-reports'
          sh '''
            set -euo pipefail
            QG_REQUIRE_SONAR="${RUN_SONAR:-false}" \
            QG_COVERAGE_MIN="${COVERAGE_MIN:-85}" \
              bash scripts/ci/secure-quality-gate.sh
          '''
        }
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/**'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  CD — PRE-DEPLOY GATES  (PRIORITÉ 1 — P1)
    //  Exécuté après CI Quality Gate, avant Deploy to Recette.
    //  CD_SECRETS_SCAN peut BLOCKER (currentBuild.result = FAILURE).
    //  Les autres P1 sont ADVISORY (UNSTABLE, décision humaine).
    // ════════════════════════════════════════════════════════════════
    stage('CD_PRE_DEPLOY_GATES') {
      parallel {
        stage('CD_SECRETS_SCAN') {
          agent { label 'security-agent' }
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh '''
                set -euo pipefail
                mkdir -p security/reports
                echo "[INFO] Running Gitleaks secrets scan (CD gate)..."
                gitleaks dir . --config .gitleaks.toml --report-format json --report-path security/reports/cd-gitleaks.json --verbose
                LEAKS=$(python3 -c "import json; d=json.load(open('security/reports/cd-gitleaks.json')); print(len(d))" 2>/dev/null || echo "0")
                if [ "${LEAKS}" -gt 0 ]; then
                  echo "============================================"
                  echo "  BLOCKED: ${LEAKS} secret(s) detected!"
                  echo "============================================"
                  python3 -c "
import json
d = json.load(open('security/reports/cd-gitleaks.json'))
for x in d:
    print(f'  - {x.get(\"Description\",\"?\")} in {x.get(\"File\",\"?\")}:{x.get(\"StartLine\",\"?\")}')
"
                  exit 1
                fi
                echo "[PASS] No secrets detected in workspace"
              '''
            }
          }
          post {
            failure {
              script { currentBuild.result = 'FAILURE' }
            }
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/cd-gitleaks.json'
            }
          }
        }

        stage('CD_DOCKERFILE_LINT') {
          agent { label 'master' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                unstash 'workspace'
                sh '''
                  set -euo pipefail
                  mkdir -p security/reports
                  echo "[INFO] Running Hadolint Dockerfile lint (CD gate)..."
                  bash scripts/ci/run-hadolint.sh
                  echo "[INFO] Hadolint completed — review JUnit report for details"
                '''
              }
            }
          }
          post {
            always {
              junit allowEmptyResults: true, testResults: 'security/reports/hadolint-junit.xml'
              archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/hadolint-junit.xml'
            }
          }
        }

        stage('CD_IAC_SCAN') {
          agent { label 'k8s-agent' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 10, unit: 'MINUTES') {
                unstash 'workspace'
                sh '''
                  set -euo pipefail
                  mkdir -p security/reports
                  echo "[INFO] Running Checkov IaC scan (CD gate)..."
                  set +e
                  checkov -d . --config-file security/checkov-config.yaml --skip-path vendor --skip-path node_modules --hard-fail-on HIGH \
                    -o json > security/reports/cd-checkov-k8s.json 2>/dev/null
                  rc=$?
                  touch security/reports/cd-checkov-helm.json
                  set -e
                  if [ $rc -ne 0 ]; then
                    echo "[ERROR] Checkov scans found violations in CD stage."
                    exit 1
                  fi
                  echo "[INFO] Checkov IaC scan complete — review reports for findings"
                '''
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/cd-checkov-*.json'
            }
          }
        }

        stage('CD_MANIFEST_VALIDATE') {
          agent { label 'k8s-agent' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 10, unit: 'MINUTES') {
                unstash 'workspace'
                sh '''
                  set -euo pipefail
                  mkdir -p artifacts/security
                  echo "[INFO] Running kube-score on recette overlay manifests..."
                  set +e
                  KUSTOMIZE_OVERLAY=infra/k8s/overlays/recette \
                    STRICT_KUBE_SCORE=true \
                    KUBE_SCORE_MAX_CRITICAL="${KUBE_SCORE_MAX_CRITICAL:-0}" \
                    KUBE_SCORE_MAX_WARNINGS="${KUBE_SCORE_MAX_WARNINGS:-0}" \
                    bash scripts/ci/validate-kube-score.sh
                  rc1=$?
                  echo "[INFO] Running Kyverno dry-run on recette overlay..."
                  REQUIRE_KYVERNO_CLI=true bash scripts/ci/validate-kyverno-policies.sh --dry-run
                  rc2=$?
                  set -e
                  if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
                    echo "[ERROR] Manifest validation failed."
                    exit 1
                  fi
                  echo "[INFO] Manifest validation complete — review kube-score report"
                '''
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/kube-score-*,artifacts/security/*.md'
            }
          }
        }

        stage('CD_OWASP_AUDIT') {
          agent { label 'docker-agent' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 20, unit: 'MINUTES') {
                unstash 'workspace'
                sh '''
                  set -euo pipefail
                  mkdir -p security/reports
                  echo "[INFO] Running OWASP Dependency-Check (CD gate)..."
                  bash scripts/ci/run-owasp-dependency-check.sh
                  echo "[INFO] OWASP Dependency-Check complete — review HTML report"
                '''
              }
            }
          }
          post {
            always {
              publishHTML(target: [
                allowMissing: true,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'security/reports',
                reportFiles: 'dependency-check-*/dependency-check-report.html',
                reportName: 'OWASP Dependency-Check Report'
              ])
              archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/dependency-check-*/'
            }
          }
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  CD — DEPLOY TO RECETTE
    //  SSH deployment to recette/staging machine (63.250.59.72).
    //  Utilise deploy-to-recette.sh pour cloner, build, et déployer.
    //  Temps moyen: ~25s (existing).
    // ════════════════════════════════════════════════════════════════
    stage('Deploy to Recette') {
      when { expression { return params.DEPLOY_TO_RECETTE } }
      agent { label 'master' }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          unstash 'workspace'
          withCredentials([sshUserPrivateKey(credentialsId: 'recette-deploy-ssh-key', keyFileVariable: 'SSH_KEY_FILE')]) {
            sh '''
              set -euo pipefail
              echo "[INFO] Deploying to recette (${RECETTE_USER}@${RECETTE_HOST})..."
              SSH_KEY_FILE="${SSH_KEY_FILE}" bash scripts/deploy/deploy-to-recette.sh
              echo "[INFO] Deployment to recette completed"
            '''
          }
        }
      }
      post {
        success {
          echo "[INFO] Deploy to Recette — SUCCESS"
        }
        failure {
          echo "[WARN] Deploy to Recette — FAILED (review logs)"
        }
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/deploy/*.log,reports/deploy/*.md'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  CD — POST-DEPLOY SMOKE TESTS
    //  Vérifie que les workloads sont Running et que les endpoints
    //  health répondent. Temps moyen: ~1s (existing).
    // ════════════════════════════════════════════════════════════════
    stage('Post-deploy Smoke Tests') {
      agent { label 'k8s-agent' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          sh '''
            set -euo pipefail
            mkdir -p reports/postdeploy
            echo "[INFO] Running post-deploy smoke tests..."
            bash scripts/validate/smoke-tests.sh || echo "[WARN] Smoke tests reported failures — investigate"
            echo "[INFO] Smoke tests complete"
          '''
        }
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/postdeploy/smoke-tests-report.md'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  CD — POST-DEPLOY VALIDATION  (PRIORITÉ 2 — P2)
    //  Exécuté après Smoke Tests, avant DAST.
    //  Tous les stages P2 sont ADVISORY (UNSTABLE, décision humaine).
    // ════════════════════════════════════════════════════════════════
    stage('CD_POST_DEPLOY_VALIDATION') {
      parallel {
        stage('CD_SONARQUBE') {
          when { expression { return params.RUN_SONAR } }
          agent { label 'sonar-agent' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 10, unit: 'MINUTES') {
                unstash 'workspace'
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                  sh '''
                    set -euo pipefail
                    echo "[INFO] Running SonarQube analysis (CD validation)..."
                    REQUIRE_SONAR=true SONAR_HOST_URL="${SONAR_HOST_URL:-}" SONAR_TOKEN="${SONAR_TOKEN}" \
                      bash scripts/ci/run-sonar-analysis.sh
                    echo "[INFO] SonarQube analysis complete"
                    echo "[NOTE] SonarQube Quality Gate status must be reviewed manually"
                  '''
                }
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: '.scannerwork/report-task.txt'
            }
          }
        }

        stage('CD_SUPPLY_CHAIN') {
          agent { label 'worker' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 10, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  echo "[INFO] Verifying supply chain (SLSA + Cosign)..."
                  set +e
                  if [ -f "scripts/supply-chain/verify-slsa.sh" ]; then
                    bash scripts/supply-chain/verify-slsa.sh
                    rc1=$?
                  else
                    echo "[WARN] SLSA verify script not found — skipping"
                    rc1=0
                  fi
                  COSIGN_PUB_KEY="k8s://securerag-hub/cosign-public-key"
                  if kubectl get secret cosign-public-key -n securerag-hub &>/dev/null 2>&1; then
                    cosign verify --key "${COSIGN_PUB_KEY}" \
                      "${REGISTRY_HOST:-localhost:5001}/securerag-hub-portal-web:${IMAGE_TAG:-demo}"
                    rc2=$?
                  else
                    echo "[WARN] Cosign public key not found in cluster — skipping image verification"
                    rc2=0
                  fi
                  set -e
                  if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
                    echo "[ERROR] Supply chain verification failed."
                    exit 1
                  fi
                  echo "[INFO] Supply chain verification complete"
                '''
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/slsa-verify*.json'
            }
          }
        }

        stage('CD_RUNTIME_SECURITY') {
          agent { label 'k8s-agent' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  echo "[INFO] Checking runtime security (Tetragon + OPA Gatekeeper)..."
                  set +e
                  if [ -f "scripts/ci/validate-tetragon-policies.sh" ]; then
                    bash scripts/ci/validate-tetragon-policies.sh
                    rc1=$?
                  else
                    echo "[WARN] Tetragon validation script not found — skipping"
                    rc1=0
                  fi
                  if [ -f "scripts/ci/validate-opa-gatekeeper.sh" ]; then
                    bash scripts/ci/validate-opa-gatekeeper.sh
                    rc2=$?
                  else
                    echo "[WARN] OPA Gatekeeper validation script not found — skipping"
                    rc2=0
                  fi
                  set -e
                  if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
                    echo "[ERROR] Runtime security verification failed."
                    exit 1
                  fi
                  echo "[INFO] Runtime security checks complete"
                '''
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/opa-audit*.json,artifacts/security/tetragon*.json'
            }
          }
        }

        stage('CD_SPIRE_VALIDATE') {
          agent { label 'worker' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  echo "[INFO] Validating SPIRE workload identities..."
                  if [ -f "scripts/spire/deploy-spire.sh" ]; then
                    bash scripts/spire/deploy-spire.sh --validate-only
                  else
                    echo "[WARN] SPIRE validation script not found — skipping"
                  fi
                  echo "[INFO] SPIRE validation complete"
                '''
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/spire-validate*.json'
            }
          }
        }

        stage('CD_VAULT_SECRETS') {
          agent { label 'worker' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  echo "[INFO] Validating Vault dynamic secrets..."
                  if [ -f "scripts/vault/validate-dynamic-secrets.sh" ]; then
                    bash scripts/vault/validate-dynamic-secrets.sh
                  else
                    echo "[WARN] Vault validation script not found — skipping"
                  fi
                  echo "[INFO] Vault secrets validation complete"
                '''
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/vault-validate*.json'
            }
          }
        }

        stage('CD_SIEM_CHECK') {
          agent { label 'worker' }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  echo "[INFO] Checking SIEM (Wazuh) for post-deploy alerts..."
                  if [ -f "scripts/opensearch/validate-siem.sh" ]; then
                    bash scripts/opensearch/validate-siem.sh --window 2m
                  else
                    echo "[WARN] SIEM validation script not found — skipping"
                  fi
                  echo "[INFO] SIEM check complete"
                '''
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/siem-alerts*.json'
            }
          }
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  CD — DAST (Dynamic Application Security Testing)
    //  OWASP ZAP baseline scan + validation du rapport.
    //  ADVISORY uniquement — ne bloque jamais le déploiement.
    //  Temps moyen: ~3s (existing, + ZAP scan time ~2-5min).
    // ════════════════════════════════════════════════════════════════
    stage('DAST') {
      agent { label 'docker-agent' }
      steps {
        catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
          timeout(time: 15, unit: 'MINUTES') {
            sh '''
              set -euo pipefail
              mkdir -p artifacts/dast
              echo "[INFO] Running OWASP ZAP baseline scan against ${DAST_PORTAL_URL}..."
              set +e
              docker run --rm --network host \
                -v "$(pwd)/artifacts/dast:/zap/wrk:rw" \
                -t ghcr.io/zaproxy/zaproxy:2.15.0 zap-baseline.py \
                -t "${DAST_PORTAL_URL}" \
                -r dast-baseline-report.html \
                -J dast-baseline-report.json \
                -l WARN
              rc1=$?
              echo "[INFO] ZAP baseline scan complete (exit: ${rc1})"
              echo "[INFO] Validating DAST report..."
              DAST_REPORT=artifacts/dast/dast-baseline-report.json DAST_FAIL_ON=High \
                bash scripts/validate/validate-dast-report.sh
              rc2=$?
              set -e
              if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
                echo "[ERROR] ZAP scan or validation failed."
                exit 1
              fi
              echo "[INFO] DAST validation complete"
            '''
          }
        }
      }
      post {
        always {
          publishHTML(target: [
            allowMissing: true,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'artifacts/dast',
            reportFiles: 'dast-baseline-report.html',
            reportName: 'OWASP ZAP Baseline Scan Report'
          ])
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/dast/*'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 11a — SPIRE Validation
    // ════════════════════════════════════════════════════════════════
    stage('CI: SPIRE Validation') {
      when {
        expression { return params.ENFORCE_QUALITY_GATE && params.RUN_SPIRE_VALIDATION }
      }
      agent { label 'worker' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/spire/deploy-spire.sh --validate-only'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 11b — Trivy Operator Scan
    // ════════════════════════════════════════════════════════════════
    stage('CI: Trivy Operator Scan') {
      when { expression { return params.RUN_TRIVY_OPERATOR } }
      agent { label 'worker' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/trivy-operator/validate-trivy-scans.sh'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 11c — CIS Benchmark (nightly)
    // ════════════════════════════════════════════════════════════════
    stage('CI: CIS Benchmark') {
      when {
        expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') && params.RUN_CIS_BENCHMARK }
      }
      agent { label 'worker' }
      steps {
        timeout(time: 15, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/security/run-cis-benchmark.sh'
        }
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/cis-report.md'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 11d — Policy-as-Code (Conftest)
    // ════════════════════════════════════════════════════════════════
    stage('CI: Policy-as-Code (Conftest)') {
      when { expression { return params.RUN_POLICY_AS_CODE } }
      agent { label 'worker' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/ci/policy-as-code.sh'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 11e — SLSA Verify (CD trigger only)
    // ════════════════════════════════════════════════════════════════
    stage('CI: SLSA Verify') {
      when {
        expression { return params.RUN_SLSA_VERIFY }
      }
      agent { label 'worker' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/supply-chain/verify-slsa.sh'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 11f — Dynamic Secrets Validation
    // ════════════════════════════════════════════════════════════════
    stage('CI: Dynamic Secrets Validation') {
      when {
        expression { return params.DEPLOY_VAULT }
      }
      agent { label 'worker' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/vault/validate-dynamic-secrets.sh'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 11g — SIEM Validation (nightly)
    // ════════════════════════════════════════════════════════════════
    stage('CI: SIEM Validation') {
      when {
        expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') && params.RUN_SIEM_VALIDATION }
      }
      agent { label 'worker' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/opensearch/validate-siem.sh'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 11 — Deploy Vault & ESO (First run only)
    // ════════════════════════════════════════════════════════════════
    stage('CI: Deploy Vault & ESO') {
      when { expression { return params.DEPLOY_VAULT } }
      agent { label 'k8s-agent' }
      steps {
        timeout(time: 15, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/deploy/deploy-vault-and-eso.sh'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 12 — Deploy Velero & MinIO (First run only)
    // ════════════════════════════════════════════════════════════════
    stage('CI: Deploy Velero') {
      when { expression { return params.DEPLOY_VELERO } }
      agent { label 'k8s-agent' }
      steps {
        timeout(time: 15, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/deploy/deploy-velero.sh'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 13 — Backup Validation (Nightly)
    // ════════════════════════════════════════════════════════════════
    stage('CI: Backup Validation') {
      when {
        expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') }
      }
      agent { label 'k8s-agent' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh '''
            set -euo pipefail
            if command -v velero &>/dev/null; then
              bash scripts/dr/validate-restore.sh || exit 1
            else
              echo "[WARN] Velero not installed — backup validation skipped"
            fi
          '''
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 14 — Jenkins Backup (Nightly)
    // ════════════════════════════════════════════════════════════════
    stage('CI: Jenkins Backup') {
      when {
        expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') }
      }
      agent { label 'master' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}" BACKUP_DIR="/tmp/jenkins-backup" bash scripts/jenkins/backup-jenkins.sh'
        }
      }
      post {
        always { archiveArtifacts allowEmptyArchive: true, artifacts: '/tmp/jenkins-backup/*.tar.gz' }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 15 — Renovate Dependency Updates (Weekly)
    // ════════════════════════════════════════════════════════════════
    stage('CI: Dependency Updates') {
      when {
        expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') }
      }
      agent { label 'master' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh '''
            set -euo pipefail
            if command -v renovate &>/dev/null; then
              renovate --config renovate.json .
            elif command -v npx &>/dev/null; then
              npx --yes renovate --config renovate.json .
            else
              echo "[WARN] Renovate not installed — dependency update skipped"
            fi
          '''
        }
      }
    }
  }

  post {
    failure {
      echo 'CI pipeline failed.'
    }
  }
}
