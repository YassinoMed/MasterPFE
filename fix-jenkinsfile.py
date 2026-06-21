with open("Jenkinsfile.recette", "r") as f:
    lines = f.readlines()

out = []
for i, line in enumerate(lines):
    if "stash name: 'workspace', includes: '**'" in line:
        continue
    
    if "unstash 'workspace'" in line:
        out.append("              checkout scm\n")
        out.append("              sh 'find scripts -type f -name \"*.sh\" -exec chmod +x {} + || true'\n")
        continue

    if "make lint" in line:
        out.append('                for app in ${LARAVEL_APPS}; do\n')
        out.append('                  (cd "${app}" && composer install --no-interaction --prefer-dist --no-progress)\n')
        out.append('                  if [ -f "${app}/package-lock.json" ]; then\n')
        out.append('                    if ! command -v npm &>/dev/null; then apk add --no-cache nodejs npm || true; fi\n')
        out.append('                    (cd "${app}" && npm ci --ignore-scripts)\n')
        out.append('                  fi\n')
        out.append('                done\n')
        out.append(line)
        continue

    if "bash scripts/ci/run-tests.sh" in line and 'COVERAGE_MIN=' in lines[i-1]:
        out.append('                for app in ${LARAVEL_APPS}; do\n')
        out.append('                  (cd "${app}" && composer install --no-interaction --prefer-dist --no-progress)\n')
        out.append('                done\n')
        out.append(line)
        continue

    out.append(line)

with open("Jenkinsfile.recette", "w") as f:
    f.writelines(out)
