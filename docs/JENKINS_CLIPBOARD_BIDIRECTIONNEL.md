# SecureRAG Hub — Copier-Coller bidirectionnel Jenkins ↔ Host

Outilage de bidirectionalité complète pour le pipeline CI/CD.

## 3 mécanismes livrés

### 1. Montage `/workspace` (déjà activé — par défaut)

Le conteneur Jenkins monte ta repo entièrement à `/home/admin/MasterPFE` vers `/workspace` en lecture-écriture :
```
docker inspect securerag-jenkins --format '{{range .Mounts}}{{.Source}}->{{.Destination}}{{"\n"}}{{end}}'
# /home/admin/MasterPFE -> /workspace
```

**Conséquence :** tout ce que tu touches ici (ex: updated Makefile, fix de Dockerfile) apparaît automatiquement dans le pipeline. Vu que le Jenkinsfile vit dans le repo git, tu n'as rien à copier — il est déjà là.

---

### 2. Helper scripts (nouveau)

Créés dans `scripts/jenkins/` :

#### a) `to-jenkins-file` — pousser un fichier local dans Jenkins
```bash
scripts/jenkins/to-jenkins-file.sh <fichier_local> [<job>]
# Ex: push du nouveau Jenkinsfile
scripts/jenkins/to-jenkins-file.sh Jenkinsfile securerag-hub-ci
```

#### b) `from-jenkins` — récupérer les logs & artefacts
```bash
scripts/jenkins/from-jenkins.sh lastBuild/console
scripts/jenkins/from-jenkins.sh lastBuild/api/json
scripts/jenkins/from-jenkins.sh lastBuild/archive/*
```
tombera dans `artifacts/jenkins/`.

#### c) `jenkins-copy-promis` — pousser/récupérer promiscript depuis le clipbook
```bash
# Copier une ligne (build URL, commit) dans le clipboard Jenkins
scripts/jenkins/jenkins-copy-promis.sh "<text>" > out

# Coller un extrait du log Jenkins en clipboard locale
scripts/jenkins/jenkins-copy-promis.sh --build <num> <pattern> | xclip -selection clipboard
```

#### d) `jenkins-biwalk` — bidirectionnel
Afficher côté à côté local et Jenkins artefact identique :
```bash
scripts/jenkins/jenkins-biwalk.sh [path_relatif]
# ex: scripts/jenkins/jenkins-biwalk.sh artifacts/release/sbom-index.txt
```

---

### 3. Alias shell (activation rapide)

```bash
# Ajouter à ~/.bashrc ou ~/.zshrc :
source $(pwd)/scripts/jenkins/clipboard-aliases.sh

# Ensuite utilisable partout :
jlog         # dernier log Jenkins
jbuild       # forcer un build dans la job securerag-hub-ci  
jcopy <file> # copier un fichier localement dans Jenkins (via /workspace)
jpaste [pattern]   # coller du log Jenkins vers clipboard local
```

---

## Script maître : activation immédiate

```bash
cd /home/admin/MasterPFE
chmod +x scripts/jenkins/{to-jenkins,from-jenkins,jenkins-copy-promis,jenkins-biwalk}.sh
source scripts/jenkins/clipboard-aliases.sh
echo "✅ Copier-coller bidirectionnel Jenkins activé"
```

*Prérequis : xclip ou xsel (pour le clipboard local).*
