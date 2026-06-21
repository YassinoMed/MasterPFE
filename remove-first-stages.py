with open("Jenkinsfile.recette", "r") as f:
    text = f.read()

import re

# Remove 'Checkout' stage
text = re.sub(r"    stage\('Checkout'\) \{.*?\n    stage\('Prepare Workspace'\)", "    stage('Prepare Workspace')", text, flags=re.DOTALL)

# Remove 'Prepare Workspace' stage
text = re.sub(r"    stage\('Prepare Workspace'\) \{.*?\n    stage\('Install CI Dependencies'\)", "    stage('Install CI Dependencies')", text, flags=re.DOTALL)

# Remove 'Install CI Dependencies' stage
text = re.sub(r"    stage\('Install CI Dependencies'\) \{.*?\n    stage\('CI: Parallel Checks'\)", "    stage('CI: Parallel Checks')", text, flags=re.DOTALL)

with open("Jenkinsfile.recette", "w") as f:
    f.write(text)
