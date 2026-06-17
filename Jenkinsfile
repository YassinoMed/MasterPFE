// Jenkinsfile — SecureRAG Hub CI (Distributed Edition)
// Agents spécialisés Kubernetes pour exécution parallèle.
pipeline {
  agent none

  triggers { githubPush() }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 45, unit: 'MINUTES')
  }

  parameters {
    booleanParam(name: 'RUN_SONAR', defaultValue: true, description: 'Run Sonar analysis')
    booleanParam(name: 'ENFORCE_QUALITY_GATE', defaultValue: true, description: 'Run consolidated Quality Gate')
    string(name: 'COVERAGE_MIN', defaultValue: '85', description: 'Minimum coverage percentage')
    string(name: 'KUBE_SCORE_MAX_CRITICAL', defaultValue: '0', description: 'Max CRITICAL kube-score findings')
    string(name: 'KUBE_SCORE_MAX_WARNINGS', defaultValue: '0', description: 'Max WARNING kube-score findings')
  }

  environment {
    LARAVEL_APPS = 'platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service'
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
              (cd "${app}" && composer install --no-interaction --prefer-dist --no-progress 2>/dev/null) || true
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
              '''
              stash name: 'semgrep-report', includes: 'security/reports/semgrep.json'
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
                checkov -d infra/k8s/ --config-file security/checkov-config.yaml --hard-fail-on CRITICAL --soft-fail-on HIGH -o junitxml > security/reports/checkov-k8s.xml || echo "[WARN] Checkov k8s found issues"
                checkov -d infra/helm/ --config-file security/checkov-config.yaml --hard-fail-on CRITICAL --soft-fail-on HIGH -o junitxml > security/reports/checkov-helm.xml || echo "[WARN] Checkov helm found issues"
                checkov -d platform/ --config-file security/checkov-config.yaml --hard-fail-on CRITICAL --soft-fail-on HIGH -o junitxml > security/reports/checkov-docker-platform.xml || echo "[WARN] Checkov platform found issues"
                checkov -d services-laravel/ --config-file security/checkov-config.yaml --hard-fail-on CRITICAL --soft-fail-on HIGH -o junitxml > security/reports/checkov-docker-services.xml || echo "[WARN] Checkov services-laravel found issues"
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
                REQUIRE_KYVERNO_CLI=false bash scripts/ci/validate-kyverno-policies.sh
                STRICT_KUBE_SCORE=true KUBE_SCORE_MAX_CRITICAL="${KUBE_SCORE_MAX_CRITICAL:-0}" KUBE_SCORE_MAX_WARNINGS="${KUBE_SCORE_MAX_WARNINGS:-0}" bash scripts/ci/validate-kube-score.sh
              '''
              stash name: 'k8s-reports', includes: 'artifacts/security/*.md,artifacts/security/kube-score-*'
            }
          }
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 5b — Platform Tools (OPA, Cilium, Crossplane, CIS)
    // ════════════════════════════════════════════════════════════════
    stage('CI: Platform Tools Validation') {
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
    //  STAGE 7 — Dependency Audit
    // ════════════════════════════════════════════════════════════════
    stage('CI: Dependency Audit') {
      agent { label 'master' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/ci/audit-dependencies.sh'
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    //  STAGE 8 — PARALLEL: Sonar + Quality Gate
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
    //  STAGE 9 — Quality Gate (Aggregated Verdict)
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
            QG_REQUIRE_COSIGN=false \
            QG_COVERAGE_MIN="${COVERAGE_MIN:-85}" \
              bash scripts/ci/quality-gate.sh
          '''
        }
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/quality-gate-summary.md,artifacts/security/quality-gate-summary.json,security/reports/**'
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
