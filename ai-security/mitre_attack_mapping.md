# Cartographie Systématique MITRE ATT&CK for Containers

Ce document établit la correspondance systématique entre les composants *Réalisés* de la chaîne de sécurité de SecureRAG Hub (notamment la sécurité runtime avec Falco, Tetragon et Kyverno) et les tactiques/techniques du framework MITRE ATT&CK for Containers.

## 1. Initial Access (TA0001)

| Technique MITRE ATT&CK | Contrôle SecureRAG Hub | Composant Responsable | Mode |
|------------------------|------------------------|-----------------------|------|
| **Exploit Public-Facing Application (T1190)** | Détection de scan DAST (OWASP ZAP) au pipeline. Blocage des payloads suspects au runtime. | OWASP ZAP (CI), AI-Sec Filter | CI/Runtime |
| **Valid Accounts (T1078)** | Chiffrement des secrets locaux et interdiction d'accès direct au cluster kind. | Gitleaks, RBAC K8s | Préventif |

## 2. Execution (TA0002)

| Technique MITRE ATT&CK | Contrôle SecureRAG Hub | Composant Responsable | Mode |
|------------------------|------------------------|-----------------------|------|
| **Command and Scripting Interpreter (T1059)** | Interception des appels système `execve` dans les conteneurs. | Falco (règle `Terminal shell in container`) | Détectif |
| **User Execution (T1204)** | Interdiction des conteneurs privilégiés et blocage de l'élévation de privilèges. | Kyverno (`allowPrivilegeEscalation: false`) | Bloquant |

## 3. Persistence (TA0003)

| Technique MITRE ATT&CK | Contrôle SecureRAG Hub | Composant Responsable | Mode |
|------------------------|------------------------|-----------------------|------|
| **Deploy Container (T1610)** | Contrôle d'admission strict, vérification de la signature Cosign et du SBOM à l'admission. | Kyverno (`verifyImages`) | Bloquant |
| **Create or Modify System Process (T1543)** | File integrity monitoring et interdiction d'écriture sur le rootfs. | Kyverno (`readOnlyRootFilesystem: true`) | Bloquant |

## 4. Privilege Escalation (TA0004)

| Technique MITRE ATT&CK | Contrôle SecureRAG Hub | Composant Responsable | Mode |
|------------------------|------------------------|-----------------------|------|
| **Escape to Host (T1611)** | Contournement empêché par le durcissement du profil Seccomp et suppression des capabilities. | Kyverno (`RuntimeDefault`, `drop: ALL`) | Bloquant |

## 5. Defense Evasion (TA0005)

| Technique MITRE ATT&CK | Contrôle SecureRAG Hub | Composant Responsable | Mode |
|------------------------|------------------------|-----------------------|------|
| **Obfuscated Files or Information (T1027)** | Analyse XAI du payload pour détecter l'obfuscation (ex: Base64/Hex). | Module XAI-Sec | Détectif |
| **Clear Command History (T1070)** | Exécution de Tetragon pour bloquer les appels eBPF tentant de masquer les processus. | Tetragon | Bloquant |

## 6. Exfiltration (TA0010)

| Technique MITRE ATT&CK | Contrôle SecureRAG Hub | Composant Responsable | Mode |
|------------------------|------------------------|-----------------------|------|
| **Exfiltration Over Alternative Protocol (T1048)** | Zero-Trust NetworkPolicies (Default Deny). Trafic bloqué s'il n'est pas whitelisté. | NetworkPolicies Kubernetes | Bloquant |
| **Exfiltration of Vector Data (RAG Specific)** | Filtrage cryptographique par métadonnées RBAC (`allowed_roles`). | Qdrant RBAC Vector Filter | Bloquant |

---
*Ce document sert de référence pour la calibration empirique de $R_{workload}$. Chaque violation de ces tactiques augmente le score de risque dynamiquement.*
