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

          python3 -m pip install --upgrade pip
          python3 -m pip install pytest pytest-cov ruff "semgrep==${SEMGREP_VERSION}"

          if [ -f services/shared/requirements.txt ]; then
            python3 -m pip install -r services/shared/requirements.txt
          fi

          find services -maxdepth 2 -name requirements.txt -not -path "*/shared/*" -print0 | \
            xargs -0 -r -n1 python3 -m pip install -r
        '''
      }
    }

    stage('Lint and Tests') {
      steps {
        sh '''
          set -euo pipefail

          if find services -type f -name "*.py" | grep -q .; then
            ruff check services tests
          else
            echo "No Python files found yet."
          fi

          bash scripts/ci/run-tests.sh
          bash scripts/ci/collect-coverage.sh
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '.coverage-artifacts/junit.xml'
          archiveArtifacts allowEmptyArchive: true, artifacts: '.coverage-artifacts/**'
        }
      }
    }

    stage('Security Scans') {
      steps {
        sh '''
          set -euo pipefail

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
