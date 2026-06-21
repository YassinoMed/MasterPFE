pipeline {
  agent {
    kubernetes {
      yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
  - name: tools
    image: mohamedyassinebouneb/securerag-hub-unified:latest
    imagePullPolicy: Always
    command:
    - cat
    tty: true
    env:
    - name: DOCKER_HOST
      value: tcp://localhost:2375
    volumeMounts:
    - name: composer-cache
      mountPath: /home/jenkins/.composer/cache
    - name: npm-cache
      mountPath: /home/jenkins/.npm
    - name: pip-cache
      mountPath: /home/jenkins/.cache/pip
    - name: trivy-cache
      mountPath: /home/jenkins/.trivycache
    - name: semgrep-cache
      mountPath: /home/jenkins/.semgrep
    - name: sonar-cache
      mountPath: /home/jenkins/.sonar
    - name: maven-cache
      mountPath: /home/jenkins/.m2
  - name: dind
    image: docker:27-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
  volumes:
  - name: composer-cache
    hostPath:
      path: /var/cache/jenkins/composer-cache-pvc
  - name: npm-cache
    hostPath:
      path: /var/cache/jenkins/npm-cache-pvc
  - name: pip-cache
    hostPath:
      path: /var/cache/jenkins/pip-cache
  - name: trivy-cache
    hostPath:
      path: /var/cache/jenkins/trivy-cache-pvc
  - name: semgrep-cache
    hostPath:
      path: /var/cache/jenkins/semgrep-cache
  - name: sonar-cache
    hostPath:
      path: /var/cache/jenkins/sonar-cache-pvc
  - name: maven-cache
    hostPath:
      path: /var/cache/jenkins/maven-cache
'''
      defaultContainer 'tools'
    }
  }

  triggers {
    githubPush()
    cron('H 2 * * *')
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 60, unit: 'MINUTES')
    ansiColor('xterm')
    skipDefaultCheckout()
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
    string(
      name: 'NOTIFICATION_EMAIL',
      defaultValue: 'med.yassine.bouneb@proton.me',
      description: 'Email address to notify on build failures. Leave empty to disable.'
    )
  }

  environment {
    LARAVEL_APPS = 'platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service'
    RECETTE_HOST = '63.250.59.72'
    RECETTE_USER = 'root'
    SSH_KEY_FILE = '/tmp/recette-deploy-key'
    SONAR_HOST_URL = 'http://sonarqube.securerag-hub.svc:9000'
    VAULT_ADDR = 'http://vault.vault.svc:8200'
    WAZUH_API_URL = 'https://wazuh-dashboard.securerag-hub.svc:55000'
    DAST_PORTAL_URL = 'http://localhost:8081'
    REPORT_DIR = 'security/reports'

    // Cache configurations
    COMPOSER_HOME       = '/home/jenkins/.composer'
    COMPOSER_CACHE_DIR  = '/home/jenkins/.composer/cache'
    npm_config_cache    = '/home/jenkins/.npm'
    NPM_CONFIG_CACHE    = '/home/jenkins/.npm'
    PIP_CACHE_DIR       = '/home/jenkins/.cache/pip'
    TRIVY_CACHE_DIR     = '/home/jenkins/.trivycache'
    SEMGREP_CACHE_DIR   = '/home/jenkins/.semgrep'
    SONAR_USER_HOME     = '/home/jenkins/.sonar'
  }

  stages {

    stage('Prepare Workspace') {
      steps {
        retry(3) {
          timeout(time: 5, unit: 'MINUTES') {
            checkout scm
          }
        }
        sh 'find scripts -type f -name "*.sh" -exec chmod +x {} + || true'
        sh '''
          set -euo pipefail
          mkdir -p security/reports .coverage-artifacts
          for app in ${LARAVEL_APPS}; do
            (cd "${app}" && composer install --no-interaction --prefer-dist --no-progress 2>/dev/null)
          done
        '''
        stash name: 'workspace', excludes: '.git/**, .trivycache/**, .semgrep/**, .sonar/**'
      }
    }

    stage('CI: Lint & Tests') {
      parallel {
        stage('Lint') {
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'make lint'
            }
          }
        }
        stage('Laravel Tests + Coverage') {
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
          }
          post { always { junit allowEmptyResults: true, testResults: '.coverage-artifacts/junit-*.xml' } }
        }
      }
    }

    stage('CI: SAST & Secrets') {
      parallel {
        stage('Semgrep SAST') {
          steps {
            timeout(time: 15, unit: 'MINUTES') {
              unstash 'workspace'
              catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                sh '''
                  set -euo pipefail
                  mkdir -p security/reports
                  semgrep scan --config security/semgrep/semgrep.yml --json -o security/reports/semgrep.json --error
                  semgrep scan --config security/semgrep/semgrep.yml --sarif -o security/reports/semgrep.sarif
                '''
              }
              stash name: 'semgrep-report', includes: 'security/reports/semgrep.*'
            }
          }
        }
        stage('Gitleaks Secrets') {
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                sh '''
                  set -euo pipefail
                  mkdir -p security/reports
                  gitleaks dir . --config .gitleaks.toml --report-format json --report-path security/reports/gitleaks.json
                '''
              }
              stash name: 'gitleaks-report', includes: 'security/reports/gitleaks.json'
            }
          }
        }
        stage('Trivy FS') {
          steps {
            timeout(time: 10, unit: 'MINUTES') {
              unstash 'workspace'
              catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                sh '''
                  set -euo pipefail
                  mkdir -p security/reports
                  trivy fs --config security/trivy/trivy-fs.yaml --ignorefile .trivyignore \
                    --format json --output security/reports/trivy-fs.json .
                '''
              }
              stash name: 'trivy-fs-report', includes: 'security/reports/trivy-fs.json'
            }
          }
        }
        stage('Kubescape Scan') {
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                sh '''
                  set -euo pipefail
                  mkdir -p security/reports
                  if command -v kubescape &>/dev/null; then
                    kubescape scan . --format json --output security/reports/kubescape.json || true
                  else
                    echo '{"status": "skipped"}' > security/reports/kubescape.json
                  fi
                '''
              }
              stash name: 'kubescape-report', includes: 'security/reports/kubescape.json'
            }
          }
        }
      }
    }

    stage('CI: IaC Scanning') {
      parallel {
        stage('Checkov') {
          steps {
            timeout(time: 10, unit: 'MINUTES') {
              unstash 'workspace'
              catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
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
              }
              stash name: 'checkov-reports', includes: 'security/reports/checkov-*.xml'
            }
          }
          post { always { junit allowEmptyResults: true, testResults: 'security/reports/checkov-*.xml' } }
        }
        stage('kube-score + Kyverno') {
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

    stage('CI: Platform Tools Validation') {
      parallel {
        stage('OPA Gatekeeper') {
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/validate-opa-gatekeeper.sh'
            }
          }
        }
        stage('Tetragon Policies') {
          steps {
            timeout(time: 3, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/validate-tetragon-policies.sh'
            }
          }
        }
        stage('Platform Tools') {
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

    stage('CI: Coverage Gate') {
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

    stage('CI: Dependency & Container Audit') {
      parallel {
        stage('Composer + npm Audit') {
          steps {
            timeout(time: 10, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/audit-dependencies.sh'
            }
          }
        }
        stage('Hadolint Dockerfile') {
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/run-hadolint.sh'
            }
          }
          post { always { junit allowEmptyResults: true, testResults: 'security/reports/hadolint-junit.xml' } }
        }
        stage('OWASP Dependency-Check') {
          steps {
            timeout(time: 20, unit: 'MINUTES') {
              unstash 'workspace'
              sh 'bash scripts/ci/run-owasp-dependency-check.sh'
            }
          }
        }
      }
    }

    stage('CI: Security Scoping Engine') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh '''
            set -euo pipefail
            mkdir -p security/reports artifacts/security

            echo "═════════════════════════════════════════════════════"
            echo "  Security Scoping Engine v1.0"
            echo "═════════════════════════════════════════════════════"

            echo "[INFO] Running Security Classifier..."
            bash security/engine/security-classifier.sh --list-all > artifacts/security/scope-classification.txt 2>/dev/null || true

            echo "[INFO] Running Semgrep scoped scan (PRODUCTION scope)..."
            semgrep scan --config security/semgrep/semgrep-scope.yml \
              --json -o security/reports/semgrep-scope.json 2>/dev/null || true

            echo "[INFO] Running Trivy scoped scan (PRODUCTION scope)..."
            bash security/trivy/trivy-scope.sh json 2>&1 || true

            echo "[INFO] Running Gate Decision Engine..."
            GATE_EXIT=0
            bash security/engine/gate-decision-engine.sh \
              --trivy security/reports/trivy-scope.json \
              --semgrep security/reports/semgrep-scope.json \
              --gitleaks security/reports/gitleaks.json \
              --output artifacts/security/gate-decision-summary.md || GATE_EXIT=$?

            cat artifacts/security/gate-decision-summary.md 2>/dev/null || true

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

    stage('CI: SonarQube') {
      when { expression { return params.RUN_SONAR } }
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

    stage('CI: Quality Gate') {
      when { expression { return params.ENFORCE_QUALITY_GATE } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') { unstash 'coverage-artifacts' }
          catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') { unstash 'semgrep-report' }
          catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') { unstash 'gitleaks-report' }
          catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') { unstash 'trivy-fs-report' }
          catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') { unstash 'checkov-reports' }
          catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') { unstash 'k8s-reports' }
          catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') { unstash 'kubescape-report' }
          sh '''
            set -euo pipefail
            QG_REQUIRE_SONAR="${RUN_SONAR:-false}" \
            QG_COVERAGE_MIN="${COVERAGE_MIN:-85}" \
              bash scripts/ci/secure-quality-gate.sh
          '''
          
          // SonarQube quality gate verification
          script {
            if (params.RUN_SONAR) {
              try {
                def qg = waitForQualityGate()
                if (qg.status != 'OK') {
                  error "SonarQube Quality Gate failed: ${qg.status}"
                }
              } catch (Exception e) {
                echo "[WARN] SonarQube Quality Gate webhook wait skipped/failed: ${e.getMessage()}"
              }
            }
          }
        }
      }
      post {
        always {
          archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/**'
        }
      }
    }

    stage('CD_PRE_DEPLOY_GATES') {
      parallel {
        stage('CD_SECRETS_SCAN') {
          steps {
            timeout(time: 5, unit: 'MINUTES') {
              unstash 'workspace'
              sh '''
                set -euo pipefail
                mkdir -p security/reports
                gitleaks dir . --config .gitleaks.toml --report-format json --report-path security/reports/cd-gitleaks.json --verbose
                LEAKS=$(python3 -c "import json; d=json.load(open('security/reports/cd-gitleaks.json')); print(len(d))" 2>/dev/null || echo "0")
                if [ "${LEAKS}" -gt 0 ]; then
                  exit 1
                fi
              '''
            }
          }
          post {
            failure { script { currentBuild.result = 'FAILURE' } }
            always { archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/cd-gitleaks.json' }
          }
        }
        stage('CD_DOCKERFILE_LINT') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                unstash 'workspace'
                sh 'bash scripts/ci/run-hadolint.sh'
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
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 10, unit: 'MINUTES') {
                unstash 'workspace'
                sh '''
                  set -euo pipefail
                  mkdir -p security/reports
                  set +e
                  checkov -d . --config-file security/checkov-config.yaml --skip-path vendor --skip-path node_modules --hard-fail-on HIGH \
                    -o json > security/reports/cd-checkov-k8s.json 2>/dev/null
                  rc=$?
                  touch security/reports/cd-checkov-helm.json
                  set -e
                  if [ $rc -ne 0 ]; then
                    exit 1
                  fi
                '''
              }
            }
          }
          post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/cd-checkov-*.json' } }
        }
        stage('CD_MANIFEST_VALIDATE') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 10, unit: 'MINUTES') {
                unstash 'workspace'
                sh '''
                  set -euo pipefail
                  mkdir -p artifacts/security
                  set +e
                  KUSTOMIZE_OVERLAY=infra/k8s/overlays/recette \
                    STRICT_KUBE_SCORE=true \
                    KUBE_SCORE_MAX_CRITICAL="${KUBE_SCORE_MAX_CRITICAL:-0}" \
                    KUBE_SCORE_MAX_WARNINGS="${KUBE_SCORE_MAX_WARNINGS:-0}" \
                    bash scripts/ci/validate-kube-score.sh
                  rc1=$?
                  REQUIRE_KYVERNO_CLI=true bash scripts/ci/validate-kyverno-policies.sh --dry-run
                  rc2=$?
                  set -e
                  if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
                    exit 1
                  fi
                '''
              }
            }
          }
          post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/kube-score-*,artifacts/security/*.md' } }
        }
        stage('CD_OWASP_AUDIT') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 20, unit: 'MINUTES') {
                unstash 'workspace'
                sh 'bash scripts/ci/run-owasp-dependency-check.sh'
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

    stage('Deploy to Recette') {
      when { expression { return params.DEPLOY_TO_RECETTE } }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          unstash 'workspace'
          withCredentials([sshUserPrivateKey(credentialsId: 'recette-deploy-ssh-key', keyFileVariable: 'SSH_KEY_FILE')]) {
            sh '''
              set -euo pipefail
              if ! command -v ssh &>/dev/null; then
                apt-get update && apt-get install -y openssh-client
              fi
              SSH_KEY_FILE="${SSH_KEY_FILE}" bash scripts/deploy/deploy-to-recette.sh
            '''
          }
        }
      }
      post {
        always { archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/deploy/*.log,reports/deploy/*.md' }
      }
    }

    stage('Post-deploy Smoke Tests') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          sh '''
            set -euo pipefail
            mkdir -p reports/postdeploy
            bash scripts/validate/smoke-tests.sh || echo "[WARN] Smoke tests reported failures"
          '''
        }
      }
      post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/postdeploy/smoke-tests-report.md' } }
    }

    stage('CD_POST_DEPLOY_VALIDATION') {
      when { expression { return params.RUN_CD_VALIDATION } }
      parallel {
        stage('CD_SONARQUBE') {
          when { expression { return params.RUN_SONAR } }
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
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
          post { always { archiveArtifacts allowEmptyArchive: true, artifacts: '.scannerwork/report-task.txt' } }
        }
        stage('CD_SUPPLY_CHAIN') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 10, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  set +e
                  if [ -f "scripts/supply-chain/verify-slsa.sh" ]; then
                    bash scripts/supply-chain/verify-slsa.sh
                    rc1=$?
                  else
                    rc1=0
                  fi
                  COSIGN_PUB_KEY="k8s://securerag-hub/cosign-public-key"
                  if kubectl get secret cosign-public-key -n securerag-hub &>/dev/null 2>&1; then
                    cosign verify --key "${COSIGN_PUB_KEY}" \
                      "${REGISTRY_HOST:-localhost:5001}/securerag-hub-portal-web:${IMAGE_TAG:-demo}"
                    rc2=$?
                  else
                    rc2=0
                  fi
                  set -e
                  if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
                    exit 1
                  fi
                '''
              }
            }
          }
          post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'security/reports/slsa-verify*.json' } }
        }
        stage('CD_RUNTIME_SECURITY') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  set +e
                  if [ -f "scripts/ci/validate-tetragon-policies.sh" ]; then
                    bash scripts/ci/validate-tetragon-policies.sh
                    rc1=$?
                  else
                    rc1=0
                  fi
                  if [ -f "scripts/ci/validate-opa-gatekeeper.sh" ]; then
                    bash scripts/ci/validate-opa-gatekeeper.sh
                    rc2=$?
                  else
                    rc2=0
                  fi
                  set -e
                  if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
                    exit 1
                  fi
                '''
              }
            }
          }
          post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/opa-audit*.json,artifacts/security/tetragon*.json' } }
        }
        stage('CD_SPIRE_VALIDATE') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  if [ -f "scripts/spire/deploy-spire.sh" ]; then
                    bash scripts/spire/deploy-spire.sh --validate-only
                  fi
                '''
              }
            }
          }
          post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/spire-validate*.json' } }
        }
        stage('CD_VAULT_SECRETS') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  if [ -f "scripts/vault/validate-dynamic-secrets.sh" ]; then
                    bash scripts/vault/validate-dynamic-secrets.sh
                  fi
                '''
              }
            }
          }
          post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/vault-validate*.json' } }
        }
        stage('CD_SIEM_CHECK') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              timeout(time: 5, unit: 'MINUTES') {
                sh '''
                  set -euo pipefail
                  if [ -f "scripts/opensearch/validate-siem.sh" ]; then
                    bash scripts/opensearch/validate-siem.sh --window 2m
                  fi
                '''
              }
            }
          }
          post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/siem-alerts*.json' } }
        }
      }
    }

    stage('DAST') {
      steps {
        catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
          timeout(time: 15, unit: 'MINUTES') {
            sh '''
              set -euo pipefail
              mkdir -p artifacts/dast
              set +e
              docker run --rm --network host \
                -v "$(pwd)/artifacts/dast:/zap/wrk:rw" \
                -t ghcr.io/zaproxy/zaproxy:2.15.0 zap-baseline.py \
                -t "${DAST_PORTAL_URL}" \
                -r dast-baseline-report.html \
                -J dast-baseline-report.json \
                -l WARN
              rc1=$?
              DAST_REPORT=artifacts/dast/dast-baseline-report.json DAST_FAIL_ON=High \
                bash scripts/validate/validate-dast-report.sh
              rc2=$?
              set -e
              if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
                exit 1
              fi
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

    stage('CI: SPIRE Validation') {
      when { expression { return params.ENFORCE_QUALITY_GATE && params.RUN_SPIRE_VALIDATION } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/spire/deploy-spire.sh --validate-only'
        }
      }
    }

    stage('CI: Trivy Operator Scan') {
      when { expression { return params.RUN_TRIVY_OPERATOR } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/trivy-operator/validate-trivy-scans.sh'
        }
      }
    }

    stage('CI: CIS Benchmark') {
      when { expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') && params.RUN_CIS_BENCHMARK } }
      steps {
        timeout(time: 15, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/security/run-cis-benchmark.sh'
        }
      }
      post { always { archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/security/cis-report.md' } }
    }

    stage('CI: Policy-as-Code (Conftest)') {
      when { expression { return params.RUN_POLICY_AS_CODE } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/ci/policy-as-code.sh'
        }
      }
    }

    stage('CI: SLSA Verify') {
      when { expression { return params.RUN_SLSA_VERIFY } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/supply-chain/verify-slsa.sh'
        }
      }
    }

    stage('CI: Dynamic Secrets Validation') {
      when { expression { return params.DEPLOY_VAULT } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/vault/validate-dynamic-secrets.sh'
        }
      }
    }

    stage('CI: SIEM Validation') {
      when { expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') && params.RUN_SIEM_VALIDATION } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/opensearch/validate-siem.sh'
        }
      }
    }

    stage('CI: Deploy Vault & ESO') {
      when { expression { return params.DEPLOY_VAULT } }
      steps {
        timeout(time: 15, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/deploy/deploy-vault-and-eso.sh'
        }
      }
    }

    stage('CI: Deploy Velero') {
      when { expression { return params.DEPLOY_VELERO } }
      steps {
        timeout(time: 15, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'bash scripts/deploy/deploy-velero.sh'
        }
      }
    }

    stage('CI: Backup Validation') {
      when { expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh '''
            set -euo pipefail
            if command -v velero &>/dev/null; then
              bash scripts/dr/validate-restore.sh || exit 1
            fi
          '''
        }
      }
    }

    stage('CI: Jenkins Backup') {
      when { expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh 'JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}" BACKUP_DIR="/tmp/jenkins-backup" bash scripts/jenkins/backup-jenkins.sh'
        }
      }
      post { always { archiveArtifacts allowEmptyArchive: true, artifacts: '/tmp/jenkins-backup/*.tar.gz' } }
    }

    stage('CI: Dependency Updates') {
      when { expression { return currentBuild.getBuildCauses().toString().contains('TimerTrigger') } }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          unstash 'workspace'
          sh '''
            set -euo pipefail
            if command -v renovate &>/dev/null; then
              renovate --config renovate.json .
            elif command -v npx &>/dev/null; then
              npx --yes renovate --config renovate.json .
            fi
          '''
        }
      }
    }
  }

  post {
    always {
      cleanWs deleteDirs: true, notFailBuild: true
    }
    success {
      script { sendNotifications('SUCCESS') }
    }
    failure {
      script { sendNotifications('FAILURE') }
    }
    unstable {
      script { sendNotifications('UNSTABLE') }
    }
    aborted {
      script { sendNotifications('ABORTED') }
    }
  }
}

def sendNotifications(String status) {
  def colorMap = [
    'SUCCESS': '#22c55e',
    'FAILURE': '#ef4444',
    'UNSTABLE': '#eab308',
    'ABORTED': '#64748b'
  ]
  def statusColor = colorMap[status] ?: '#64748b'
  def msg = "SecureRAG Hub Pipeline - ${env.JOB_NAME} #${env.BUILD_NUMBER} - ${status} (${env.BUILD_URL})"
  
  echo "Sending notifications for status: ${status}"
  
  // ── Slack ────────────────────────────────────────────────────────
  try {
    slackSend channel: '#securerag-alerts', color: statusColor, message: msg
  } catch (Exception e) {
    echo "[WARN] Slack notification failed/skipped: ${e.getMessage()}"
  }

  // ── Teams ────────────────────────────────────────────────────────
  try {
    if (env.TEAMS_WEBHOOK_URL) {
      sh "curl -s -X POST -H 'Content-Type: application/json' -d '{\"text\": \"${msg}\"}' \"\${TEAMS_WEBHOOK_URL}\" || true"
    }
  } catch (Exception e) {
    echo "[WARN] Teams notification failed/skipped: ${e.getMessage()}"
  }

  // ── Email ────────────────────────────────────────────────────────
  if (params.NOTIFICATION_EMAIL && params.NOTIFICATION_EMAIL.trim() != '') {
    try {
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
  <title>Build ${status}</title>
  <style>
    body {
      background-color: #0f172a;
      color: #f8fafc;
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 0;
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
      background: linear-gradient(135deg, #0f172a 0%, ${status == 'FAILURE' ? '#450a0a' : '#064e3b'} 100%);
      padding: 35px 30px;
      text-align: center;
      border-bottom: 2px solid ${statusColor};
    }
    .badge {
      background-color: ${statusColor};
      color: #ffffff;
      padding: 6px 14px;
      border-radius: 9999px;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
    }
    .title {
      font-size: 24px;
      font-weight: 800;
      margin: 15px 0 0 0;
      color: #ffffff;
    }
    .content {
      padding: 30px;
    }
    .intro {
      font-size: 15px;
      color: #94a3b8;
      line-height: 1.6;
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
    }
    .card-label {
      font-size: 11px;
      color: #64748b;
      text-transform: uppercase;
      font-weight: 600;
    }
    .card-value {
      font-size: 14px;
      font-weight: 700;
      color: #e2e8f0;
    }
    .actions {
      text-align: center;
    }
    .btn {
      display: inline-block;
      padding: 12px 24px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 700;
      text-decoration: none;
      background-color: ${statusColor};
      color: #ffffff;
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
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <span class="badge">Pipeline ${status}</span>
      <h1 class="title">SecureRAG Hub — CI/CD Alert</h1>
    </div>
    <div class="content">
      <p class="intro">Bonjour, la pipeline de recette/recette a fini avec le statut : <strong>${status}</strong>.</p>
      
      <table class="grid-table">
        <tr>
          <td class="card">
            <div class="card-label">Pipeline</div>
            <div class="card-value">${jobName}</div>
          </td>
          <td class="card">
            <div class="card-label">Build N°</div>
            <div class="card-value">#${buildNumber}</div>
          </td>
        </tr>
        <tr>
          <td class="card">
            <div class="card-label">Branche</div>
            <div class="card-value">${gitBranch}</div>
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
            <div class="card-value">Production / Main</div>
          </td>
        </tr>
      </table>

      <div class="actions">
        <a href="${consoleUrl}" class="btn">Consulter la Console</a>
      </div>
    </div>
    <div class="footer">
      <p class="footer-text">SecureRAG Hub — Cloud Native DevSecOps Portal</p>
    </div>
  </div>
</body>
</html>
"""
      mail to: params.NOTIFICATION_EMAIL,
           mimeType: 'text/html',
           subject: "[Jenkins] ${status}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
           body: htmlBody
    } catch (Exception e) {
      echo "[WARN] Email notification failed: ${e.getMessage()}"
    }
  }
}
