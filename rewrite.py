import re

with open("Jenkinsfile.recette", "r") as f:
    text = f.read()

# 1. Remove stash commands
text = re.sub(r"\s*stash name: 'workspace', includes: '\*\*'", "", text)
text = re.sub(r"\s*unstash 'workspace'", "\n                checkout scm\n                sh 'find scripts -type f -name \"*.sh\" -exec chmod +x {} + || true'", text)

# 2. Inject dependency installation into Lint
deps_script = """
                sh '''
                  set -euo pipefail
                  for app in ${LARAVEL_APPS}; do
                    (cd "${app}" && composer install --no-interaction --prefer-dist --no-progress)
                    if [ -f "${app}/package-lock.json" ]; then
                      if ! command -v npm &>/dev/null; then apk add --no-cache nodejs npm || true; fi
                      (cd "${app}" && npm ci --ignore-scripts)
                    fi
                  done
                '''"""

# Replace "make lint" with deps_script + "\n                make lint"
# But we need to make sure we don't mess up.
text = text.replace("make lint", deps_script.strip() + "\n                make lint")

# 3. Inject dependency installation into Tests & Coverage
# "bash scripts/ci/run-tests.sh" needs composer install before it
test_deps = """
                sh '''
                  set -euo pipefail
                  for app in ${LARAVEL_APPS}; do
                    (cd "${app}" && composer install --no-interaction --prefer-dist --no-progress)
                  done
                '''"""

# Find COVERAGE_MIN="${COVERAGE_MIN}" \
# ENFORCE_COVERAGE_GATE="${ENFORCE_COVERAGE_GATE}" \
# bash scripts/ci/run-tests.sh
target_test = 'COVERAGE_MIN="${COVERAGE_MIN}" \\\n                ENFORCE_COVERAGE_GATE="${ENFORCE_COVERAGE_GATE}" \\\n                bash scripts/ci/run-tests.sh'
text = text.replace(target_test, test_deps.strip() + '\n                ' + target_test)

with open("Jenkinsfile.recette", "w") as f:
    f.write(text)
