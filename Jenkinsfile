pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    booleanParam(
      name: 'RUN_SONAR',
      defaultValue: false,
      description: 'Run Sonar analysis and block the build on the Sonar quality gate. Requires SONAR_HOST_URL and SONAR_TOKEN in the Jenkins environment.'
    )
    string(
      name: 'SONAR_HOST_URL',
      defaultValue: '',
      description: 'SonarQube/SonarCloud URL. Required only when RUN_SONAR=true.'
    )
    booleanParam(
      name: 'REQUIRE_KYVERNO_CLI',
      defaultValue: false,
      description: 'Fail CI if the Kyverno CLI is missing instead of recording a ready-not-executed policy validation.'
    )
  }

  environment {
    SEMGREP_VERSION = '1.156.0'
    COVERAGE_MIN = '70'
    GITLEAKS_IMAGE = 'ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f'
    LARAVEL_APPS = 'platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Prepare Workspace') {
      steps {
        sh '''
          set -euo pipefail
          mkdir -p security/reports .coverage-artifacts
          find scripts -type f -name "*.sh" -exec chmod +x {} +
        '''
      }
    }

    stage('Install CI Dependencies') {
      steps {
        sh '''
          set -euo pipefail

          python3 -m venv .tools/semgrep-venv
          . .tools/semgrep-venv/bin/activate
          python -m pip install --upgrade pip
          python -m pip install "semgrep==${SEMGREP_VERSION}"

          for app in ${LARAVEL_APPS}; do
            echo "[INFO] Installing Composer dependencies for ${app}"
            (cd "${app}" && composer install --no-interaction --prefer-dist --no-progress)
            if [ -f "${app}/package-lock.json" ]; then
              echo "[INFO] Installing npm dependencies for ${app}"
              (cd "${app}" && npm ci --ignore-scripts)
            fi
          done
        '''
      }
    }

    stage('CI_SECURITY_STATIC - Lint and Tests') {
      steps {
        sh '''
          set -euo pipefail

          make lint
          bash scripts/ci/run-tests.sh
          bash scripts/ci/collect-coverage.sh
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '.coverage-artifacts/junit-*.xml'
          archiveArtifacts allowEmptyArchive: true, artifacts: '.coverage-artifacts/**'
        }
      }
    }

    stage('CI_DEPENDENCIES - Dependency Audit') {
      steps {
        sh '''
          set -euo pipefail

          bash scripts/ci/audit-dependencies.sh
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/dependency-audit-summary.md,security/reports/composer-audit-*.json,security/reports/npm-audit-*.json'
        }
      }
    }

    stage('CI_SECURITY_STATIC - SAST and Secret Scans') {
      steps {
        sh '''
          set -euo pipefail

          . .tools/semgrep-venv/bin/activate

          semgrep scan \
            --config security/semgrep/semgrep.yml \
            --json \
            --output security/reports/semgrep.json \
            --error

          docker run --rm \
            -v "$PWD:/repo" \
            -w /repo \
            "${GITLEAKS_IMAGE}" \
            dir /repo \
            --config .gitleaks.toml \
            --report-format json \
            --report-path security/reports/gitleaks.json

          trivy fs \
            --config security/trivy/trivy.yaml \
            --ignorefile .trivyignore \
            --format json \
            --output security/reports/trivy-fs.json \
            .
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/**'
        }
      }
    }

    stage('CI_K8S_POLICY - Kubernetes Policy Checks') {
      steps {
        sh '''
          set -euo pipefail

          bash scripts/validate/validate-k8s-ultra-hardening.sh
          REQUIRE_KYVERNO_CLI="${REQUIRE_KYVERNO_CLI:-false}" \
            bash scripts/ci/validate-kyverno-policies.sh
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/k8s-ultra-hardening.md,artifacts/security/kyverno-policy-validation.md,artifacts/security/kyverno-apply.log'
        }
      }
    }

    stage('CI_SONAR_SCOPE_READY') {
      when {
        expression { return !params.RUN_SONAR }
      }
      steps {
        sh '''
          set -euo pipefail

          REQUIRE_SONAR="false" \
          SONAR_HOST_URL="${SONAR_HOST_URL:-}" \
          bash scripts/ci/run-sonar-analysis.sh
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/sonar-*.md,security/reports/sonar-*.json,security/reports/sonar-scanner.log,artifacts/security/sonar-cpd-scope.md'
        }
      }
    }

    stage('CI_SONAR_QUALITY_GATE') {
      when {
        expression { return params.RUN_SONAR }
      }
      steps {
        withCredentials([
          string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')
        ]) {
          sh '''
            set -euo pipefail

            REQUIRE_SONAR="true" \
            SONAR_HOST_URL="${SONAR_HOST_URL:-}" \
            SONAR_TOKEN="${SONAR_TOKEN}" \
            bash scripts/ci/run-sonar-analysis.sh
          '''
        }
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/sonar-*.md,security/reports/sonar-*.json,security/reports/sonar-scanner.log,artifacts/security/sonar-cpd-scope.md'
        }
      }
    }
  }

  post {
    success {
      echo 'SecureRAG Hub CI pipeline completed successfully.'
    }
    failure {
      echo 'SecureRAG Hub CI pipeline failed. Inspect tests and security reports.'
    }
    always {
      archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/**,.coverage-artifacts/**'
    }
  }
}
