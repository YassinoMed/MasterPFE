pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
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
          chmod +x scripts/ci/*.sh scripts/validate/*.sh
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

    stage('Lint and Tests') {
      steps {
        sh '''
          set -euo pipefail

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

    stage('Security Scans') {
      steps {
        sh '''
          set -euo pipefail

          . .tools/semgrep-venv/bin/activate

          semgrep scan \
            --config security/semgrep/semgrep.yml \
            --json \
            --output security/reports/semgrep.json \
            --error

          bash scripts/ci/audit-dependencies.sh

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
