pipeline {
  agent any

  triggers {
    githubPush()
  }

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
    booleanParam(
      name: 'STRICT_KUBE_SCORE',
      defaultValue: true,
      description: 'Fail CI if kube-score binary is missing or thresholds are exceeded. Disable only for local dry-runs.'
    )
    string(
      name: 'KUBE_SCORE_MAX_CRITICAL',
      defaultValue: '0',
      description: 'Maximum allowed CRITICAL findings across all overlays.'
    )
    string(
      name: 'KUBE_SCORE_MAX_WARNINGS',
      defaultValue: '0',
      description: 'Maximum allowed WARNING findings across all overlays. Set higher (e.g. 50) during incremental hardening.'
    )
    booleanParam(
      name: 'ENFORCE_QUALITY_GATE',
      defaultValue: true,
      description: 'Run the consolidated CI Quality Gate stage that aggregates all signals (tests, SAST, scans, kube-score, kyverno).'
    )
    string(
      name: 'NOTIFICATION_EMAIL',
      defaultValue: 'med.yassine.bouneb@proton.me',
      description: 'Email address to notify on build failures. Leave empty to disable.'
    )
  }

  environment {
    SEMGREP_VERSION = '1.156.0'
    COVERAGE_MIN = '0'
    ENFORCE_COVERAGE_GATE = 'true'
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
          python -m pip install "semgrep==${SEMGREP_VERSION}" PyYAML

          for app in ${LARAVEL_APPS}; do
            echo "[INFO] Installing Composer dependencies for ${app}"
            (cd "${app}" && composer install --no-interaction --prefer-dist --no-progress)
            if [ -f "${app}/package-lock.json" ]; then
              echo "[INFO] Installing npm dependencies for ${app}"
              (cd "${app}" && npm ci --ignore-scripts)
              if grep -q '"build":' "${app}/package.json"; then
                echo "[INFO] Building frontend assets for ${app}"
                (cd "${app}" && npm run build)
              fi
            fi
          done
        '''
      }
    }

    stage('CI_LINT - Laravel Syntax and Manifest Validation') {
      steps {
        sh '''
          set -euo pipefail

          make lint
        '''
      }
    }

    stage('CI_TESTS - Laravel Tests and Coverage') {
      steps {
        sh '''
          set -euo pipefail

          COVERAGE_MIN="${COVERAGE_MIN}" \
          ENFORCE_COVERAGE_GATE="${ENFORCE_COVERAGE_GATE}" \
          bash scripts/ci/run-tests.sh
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '.coverage-artifacts/junit-*.xml'
          archiveArtifacts allowEmptyArchive: true, artifacts: '.coverage-artifacts/**'
        }
      }
    }

    stage('CI_COVERAGE_GATE - Enforce 70% Minimum Coverage') {
      steps {
        sh '''
          set -euo pipefail

          echo "[INFO] Enforcing coverage gate: minimum ${COVERAGE_MIN}%"
          COVERAGE_MIN="${COVERAGE_MIN}" \
          bash scripts/ci/collect-coverage.sh
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: '.coverage-artifacts/coverage-summary.txt,.coverage-artifacts/coverage*.xml'
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

          JENKINS_SOURCE=$(docker inspect securerag-jenkins --format='{{range .Mounts}}{{if eq .Destination "/var/jenkins_home"}}{{or .Name .Source}}{{end}}{{end}}' 2>/dev/null || echo "")

          if [ -n "${JENKINS_SOURCE}" ]; then
            docker run --rm \
              -v "${JENKINS_SOURCE}:/var/jenkins_home" \
              -w "$PWD" \
              "${GITLEAKS_IMAGE}" \
              dir "$PWD" \
              --config .gitleaks.toml \
              --report-format json \
              --report-path security/reports/gitleaks.json
          else
            WORKSPACE_HOST_PATH=$(docker inspect securerag-jenkins --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || echo "$PWD")
            if [ -z "${WORKSPACE_HOST_PATH}" ]; then
              WORKSPACE_HOST_PATH="$PWD"
            fi
            docker run --rm \
              -v "${WORKSPACE_HOST_PATH}:/repo" \
              -w /repo \
              "${GITLEAKS_IMAGE}" \
              dir /repo \
              --config .gitleaks.toml \
              --report-format json \
              --report-path security/reports/gitleaks.json
          fi

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

    stage('Static Analysis & IaC Scanning') {
      steps {
        sh '''
          set -euo pipefail

          # Checkov
          if command -v checkov >/dev/null 2>&1; then
            checkov -d infra/k8s/ --config-file security/checkov-config.yaml -o junitxml > security/reports/checkov-k8s.xml || true
            checkov -d infra/helm/ --config-file security/checkov-config.yaml -o junitxml > security/reports/checkov-helm.xml || true
          else
            echo "[WARN] checkov is not installed; skipping IaC scan"
          fi

          # Trivy fs scan
          trivy fs . --scanners vuln,config,secret \
            --format json \
            --output security/reports/trivy-iac.json || true
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'security/reports/checkov-*.xml'
          archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/checkov-*.xml,security/reports/trivy-iac.json'
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

          # kube-score: blocking gate (P0-1).
          # Fails on missing binary in strict mode, on CRITICAL > seuil, and
          # on WARNING > seuil. Tunable via Jenkins parameters.
          STRICT_KUBE_SCORE="${STRICT_KUBE_SCORE:-true}" \
          KUBE_SCORE_MAX_CRITICAL="${KUBE_SCORE_MAX_CRITICAL:-0}" \
          KUBE_SCORE_MAX_WARNINGS="${KUBE_SCORE_MAX_WARNINGS:-0}" \
            bash scripts/ci/validate-kube-score.sh

          # Falco rules linter. Returns 77 (skip) when no validator present.
          bash scripts/ci/validate-falco-rules.sh || rc=$?
          if [ "${rc:-0}" -ne 0 ] && [ "${rc:-0}" -ne 77 ]; then
            echo "[FAIL] Falco rules invalid"; exit 1
          fi
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/k8s-ultra-hardening.md,artifacts/security/kyverno-policy-validation.md,artifacts/security/kyverno-apply.log,artifacts/security/kube-score-report.md,artifacts/security/kube-score-raw.txt,artifacts/security/falco-rules-validation.log'
        }
      }
    }

    stage('CI_QUALITY_GATE - Aggregated Verdict') {
      when {
        expression { return params.ENFORCE_QUALITY_GATE }
      }
      steps {
        sh '''
          set -euo pipefail

          # Aggregates: tests, coverage, semgrep, gitleaks, trivy fs,
          # dependency-audit, kube-score, kyverno static. Fails the build
          # if any REQUIRED check is not PASS.
          QG_REQUIRE_SONAR="${RUN_SONAR:-false}" \
          QG_REQUIRE_COSIGN="false" \
          QG_COVERAGE_MIN="${COVERAGE_MIN:-70}" \
            bash scripts/ci/quality-gate.sh
        '''
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true,
            artifacts: 'artifacts/security/quality-gate-summary.md,artifacts/security/quality-gate-summary.json,artifacts/security/kube-score-status.txt'
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
      script {
        if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == null) {
          withCredentials([string(credentialsId: 'github-token-secret', variable: 'GITHUB_TOKEN')]) {
            sh '''
              bash scripts/ci/notify-security-backlog.sh \
                "${JOB_NAME}" \
                "${BUILD_URL}" \
                "YassinoMed/MasterPFE" \
                "${GITHUB_TOKEN}" \
                "${BUILD_NUMBER}"
            '''
          }
        }
        if (params.NOTIFICATION_EMAIL && params.NOTIFICATION_EMAIL.trim() != '') {
          def gitCommitShort = env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'N/A'
          def buildDuration = currentBuild.durationString ?: 'N/A'
          def buildUrl = env.BUILD_URL
          def consoleUrl = "${env.BUILD_URL}console"
          def jobName = env.JOB_NAME
          def buildNumber = env.BUILD_NUMBER
          def gitBranch = env.GIT_BRANCH ?: 'N/A'

          def htmlBody = """
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Build Failed</title>
  <style>
    @keyframes pulse {
      0% {
        transform: scale(0.95);
        box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7);
      }
      70% {
        transform: scale(1);
        box-shadow: 0 0 0 6px rgba(239, 68, 68, 0);
      }
      100% {
        transform: scale(0.95);
        box-shadow: 0 0 0 0 rgba(239, 68, 68, 0);
      }
    }
    body {
      background-color: #0f172a;
      color: #f8fafc;
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 0;
      -webkit-font-smoothing: antialiased;
    }
    .container {
      max-width: 600px;
      margin: 40px auto;
      background-color: #0f172a;
      border: 1px solid #1e293b;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.5);
    }
    .header {
      background: linear-gradient(135deg, #0f172a 0%, #450a0a 100%);
      padding: 35px 30px;
      text-align: center;
      position: relative;
      border-bottom: 2px solid #ef4444;
      box-shadow: inset 0 0 40px rgba(239, 68, 68, 0.15);
    }
    .badge-container {
      display: inline-block;
      margin-bottom: 12px;
    }
    .badge {
      background-color: #991b1b;
      color: #fca5a5;
      padding: 6px 14px;
      border-radius: 9999px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.05em;
      text-transform: uppercase;
      display: inline-flex;
      align-items: center;
    }
    .dot {
      width: 8px;
      height: 8px;
      background-color: #ef4444;
      border-radius: 50%;
      margin-right: 8px;
      display: inline-block;
      animation: pulse 2s infinite;
    }
    .title {
      font-size: 24px;
      font-weight: 800;
      margin: 0;
      color: #ffffff;
      letter-spacing: -0.025em;
    }
    .content {
      padding: 30px;
    }
    .intro {
      font-size: 15px;
      color: #94a3b8;
      line-height: 1.6;
      margin-top: 0;
      margin-bottom: 24px;
    }
    .grid-table {
      width: 100%;
      border-collapse: separate;
      border-spacing: 8px;
      margin-bottom: 24px;
    }
    .card {
      background-color: #1e293b;
      border: 1px solid #334155;
      border-radius: 8px;
      padding: 12px 16px;
      width: 50%;
    }
    .card-label {
      font-size: 11px;
      color: #64748b;
      text-transform: uppercase;
      font-weight: 600;
      letter-spacing: 0.05em;
      margin-bottom: 4px;
    }
    .card-value {
      font-size: 14px;
      font-weight: 700;
      color: #e2e8f0;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .card-value.highlight-red {
      color: #ef4444;
    }
    .card-value.highlight-blue {
      color: #3b82f6;
    }
    .section-title {
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #475569;
      margin-bottom: 12px;
      border-bottom: 1px solid #1e293b;
      padding-bottom: 6px;
    }
    .tags-container {
      margin-bottom: 30px;
      line-height: 2.2;
    }
    .tag {
      display: inline-block;
      padding: 3px 10px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 600;
      margin-right: 6px;
    }
    .tag-sec {
      background-color: #172554;
      color: #93c5fd;
      border: 1px solid #1e3a8a;
    }
    .tag-scanner {
      background-color: #450a0a;
      color: #fca5a5;
      border: 1px solid #7f1d1d;
    }
    .tag-gate {
      background-color: #064e3b;
      color: #6ee7b7;
      border: 1px solid #065f46;
    }
    .tag-audit {
      background-color: #3b0764;
      color: #d8b4fe;
      border: 1px solid #581c87;
    }
    .actions {
      text-align: center;
      margin-bottom: 10px;
    }
    .btn {
      display: inline-block;
      padding: 12px 24px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 700;
      text-decoration: none;
      margin: 0 8px;
    }
    .btn-primary {
      background-color: #ef4444;
      color: #ffffff;
      border: 1px solid #ef4444;
    }
    .btn-secondary {
      background-color: transparent;
      color: #ffffff;
      border: 1px solid #475569;
    }
    .footer {
      background-color: #020617;
      padding: 24px;
      text-align: center;
      border-top: 1px solid #1e293b;
    }
    .footer-text {
      font-size: 12px;
      color: #64748b;
      margin: 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="badge-container">
        <span class="badge"><span class="dot"></span>Build Failed</span>
      </div>
      <h1 class="title">SecureRAG Hub — Alert</h1>
    </div>
    <div class="content">
      <p class="intro">Bonjour, le build de la pipeline a échoué. Vous trouverez ci-dessous les détails du build ainsi que les outils de sécurité impliqués.</p>
      
      <table class="grid-table">
        <tr>
          <td class="card">
            <div class="card-label">Pipeline</div>
            <div class="card-value">${jobName}</div>
          </td>
          <td class="card">
            <div class="card-label">Build N°</div>
            <div class="card-value highlight-red">#${buildNumber}</div>
          </td>
        </tr>
        <tr>
          <td class="card">
            <div class="card-label">Branche Git</div>
            <div class="card-value highlight-blue">${gitBranch}</div>
          </td>
          <td class="card">
            <div class="card-label">Commit SHA</div>
            <div class="card-value">${gitCommitShort}</div>
          </td>
        </tr>
        <tr>
          <td class="card">
            <div class="card-label">Durée</div>
            <div class="card-value">${buildDuration}</div>
          </td>
          <td class="card">
            <div class="card-label">Environnement</div>
            <div class="card-value">DevSecOps CI/CD</div>
          </td>
        </tr>
      </table>

      <div class="section-title">Outils de sécurité actifs</div>
      <div class="tags-container">
        <span class="tag tag-scanner">Semgrep SAST</span>
        <span class="tag tag-scanner">Gitleaks Secrets</span>
        <span class="tag tag-scanner">Trivy Image & FS</span>
        <span class="tag tag-sec">Kyverno Policies</span>
        <span class="tag tag-sec">kube-score Linter</span>
        <span class="tag tag-audit">Falco Runtime</span>
        <span class="tag tag-gate">Quality Gate</span>
        <span class="tag tag-gate">Coverage Gate</span>
      </div>

      <div class="actions">
        <a href="${consoleUrl}" class="btn btn-primary">Voir la console</a>
        <a href="${buildUrl}" class="btn btn-secondary">Détails du build</a>
      </div>
    </div>
    <div class="footer">
      <p class="footer-text">SecureRAG Hub — Système d'Intégration et de Déploiement Continus</p>
    </div>
  </div>
</body>
</html>
"""

          mail to: params.NOTIFICATION_EMAIL,
               mimeType: 'text/html',
               subject: "🔴 [Jenkins] Échec du build : ${env.JOB_NAME} #${env.BUILD_NUMBER}",
               body: htmlBody
        }
      }
    }
    always {
      archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/**,.coverage-artifacts/**'
    }
  }
}
