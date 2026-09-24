#!/usr/bin/env bash
# Alias shell pour activer le copier-coller bidirectionnel Jenkins.
# Usage: source ce fichier dans ~/.bashrc ou ~/.zshrc

JenkinsP() {
  basename "$(cat infra/jenkins/secrets/jenkins-admin-password)"
}

alias jlog='cd /home/admin/MasterPFE && bash scripts/jenkins/from-jenkins.sh lastBuild/console'
alias jbuild='cd /home/admin/MasterPFE && \
  CRUMB=$(curl -s -c /tmp/jjc.txt -u "admin:$(cat infra/jenkins/secrets/jenkins-admin-password)" http://localhost:8085/crumbIssuer/api/json | python3 -c "import json,sys;print(json.load(sys.stdin)[\"crumb\"])"); \
  curl -s -b /tmp/jjc.txt -u "admin:$(cat infra/jenkins/secrets/jenkins-admin-password)" -H "Jenkins-Crumb:$CRUMB" -X POST http://localhost:8085/job/securerag-hub-ci/build -o /dev/null -w "build triggered %"'

# Copier un fichier local vers Jenkins (via volume, immédiat)
jcopy() {
  [ -z "$1" ] && echo "Usage: jcopy <fichier>" && return
  local f="$1"
  cp -v "$f" "/home/admin/MasterPFE/$f" 2>/dev/null && echo "✅ $f available à /workspace/$f dans Jenkins" || echo "path_abs_${f}"
}

# Coller un extrait du dernier log Jenkins dans le clipboard local
jpaste() {
  cd /home/admin/MasterPFE
  local pat="${1:-PASS|FAIL|WARN}"
  bash scripts/jenkins/jenkins-copy-promis.sh --build lastBuild --pattern "$pat"
}

# Ouvrir la console Jenkins du haut (pratique après `jbuild`)
jconsole() {
  xdg-open http://localhost:8085/job/securerag-hub-ci/lastBuild/console 2>/dev/null || \
    echo "👉 http://localhost:8085/job/securerag-hub-ci/lastBuild/console"
}
