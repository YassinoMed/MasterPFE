    # ── SECAI Security Analysis (read-only, never blocks) ──────
    stage('SECAI Security Analysis') {
      when { expression { return env.SKIPPABLE_DOCS != 'true' } }
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

    stage('Kubernetes Deploy & Verify') {