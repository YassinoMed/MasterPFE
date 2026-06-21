with open("infra/jenkins/casc/kubernetes-agents.yaml", "r") as f:
    text = f.read()

import re

# Replace PVC with hostPathVolume
text = re.sub(
    r"-\s*persistentVolumeClaim:\s*\n\s*claimName:\s*\"([^\"]+)\"\s*\n\s*mountPath:\s*\"([^\"]+)\"",
    lambda m: f"- hostPathVolume:\n                  hostPath: \"/var/cache/jenkins/{m.group(1)}\"\n                  mountPath: \"{m.group(2)}\"",
    text
)

with open("infra/jenkins/casc/kubernetes-agents.yaml", "w") as f:
    f.write(text)
