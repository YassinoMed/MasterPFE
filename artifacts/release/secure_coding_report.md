# Rapport d'Audit de Sécurité - Secure Coding Agent
**Anomalies Détectées** : 24

## 1. Détails des Vulnérabilités
### [Remote Code Execution (RCE)] - ./services/ai-orchestrator/main.py (Ligne 126)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  uvicorn.run(app, host="0.0.0.0", port=8091)
  ```
### [Remote Code Execution (RCE)] - ./services/ai-metrics/main.py (Ligne 53)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  uvicorn.run(app, host="0.0.0.0", port=8098)
  ```
### [Remote Code Execution (RCE)] - ./services/ai-memory/main.py (Ligne 100)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  uvicorn.run(app, host="0.0.0.0", port=8095)
  ```
### [Remote Code Execution (RCE)] - ./services/ai-feedback-engine/main.py (Ligne 77)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  uvicorn.run(app, host="0.0.0.0", port=8097)
  ```
### [Remote Code Execution (RCE)] - ./services/ai-trust-engine/main.py (Ligne 189)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  uvicorn.run(app, host="0.0.0.0", port=8093)
  ```
### [Remote Code Execution (RCE)] - ./services/ai-risk-engine/main.py (Ligne 89)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  uvicorn.run(app, host="0.0.0.0", port=8092)
  ```
### [Remote Code Execution (RCE)] - ./services/ai-explainability/main.py (Ligne 137)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  uvicorn.run(app, host="0.0.0.0", port=8094)
  ```
### [Remote Code Execution (RCE)] - ./services/ai-knowledge/main.py (Ligne 91)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  uvicorn.run(app, host="0.0.0.0", port=8096)
  ```
### [Hardcoded Secret] - ./services/auth-users/tests/test_auth_flow.py (Ligne 18)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  token = r2.json()["access_token"]
  ```
### [Hardcoded Secret] - ./services/auth-users/src/main.py (Ligne 42)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  token = authorization.split(" ", 1)[1].strip()
  ```
### [Hardcoded Secret] - ./services/auth-users/src/main.py (Ligne 102)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  token = issue_token(subject=str(user.id), role=user.role)
  ```
### [Hardcoded Secret] - ./services/auth-users/src/main.py (Ligne 114)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  token = issue_token(subject=str(user.id), role=user.role)
  ```
### [Hardcoded Secret] - ./infra/wazuh/wazuh-exporter/exporter.py (Ligne 83)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  token = None
  ```
### [Hardcoded Secret] - ./infra/wazuh/wazuh-exporter/exporter.py (Ligne 87)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  token = get_token()
  ```
### [Hardcoded Secret] - ./infra/wazuh/wazuh-exporter/exporter.py (Ligne 92)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  token = None
  ```
### [Hardcoded Secret] - ./scripts/ai-agents/secure_coding_agent.py (Ligne 36)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  if any(x in line.lower() for x in ["password = ", "passwd =", "api_key =", "secret_key =", "token ="]):
  ```
### [Remote Code Execution (RCE)] - ./scripts/ai/analyze-images.py (Ligne 22)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  res = subprocess.run(
  ```
### [Remote Code Execution (RCE)] - ./ai-security/app.py (Ligne 274)
* **Sévérité** : `CRITICAL`
* **Description** : Dangerous shell execution 'run' with dynamic arguments detected.
* **Code Suspect** :
  ```python
  uvicorn.run(app, host="0.0.0.0", port=8000)
  ```
### [Hardcoded Secret] - ./embeding/services/knowledge-hub/app/retrieval/retrieval_engine.py (Ligne 20)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  CHARS_PER_TOKEN = 4
  ```
### [Hardcoded Secret] - ./embeding/services/knowledge-hub/app/vectorstore/qdrant_manager.py (Ligne 39)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  self.api_key = api_key if api_key is not None else settings.qdrant_api_key
  ```
### [Hardcoded Secret] - ./services-laravel/shared-security/src/Http/Requests/Concerns/AuthorizesServiceRequest.php (Ligne 17)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  $sharedToken = (string) $this->authzValue('SECURERAG_SHARED_API_TOKEN', '');
  ```
### [Hardcoded Secret] - ./services-laravel/shared-security/src/Http/Requests/Concerns/AuthorizesServiceRequest.php (Ligne 18)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  if ($sharedToken === '') {
  ```
### [Hardcoded Secret] - ./services-laravel/shared-security/src/Http/Requests/Concerns/AuthorizesServiceRequest.php (Ligne 22)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  $headerToken = (string) $this->header('X-SecureRAG-Service-Token', '');
  ```
### [Hardcoded Secret] - ./services-laravel/shared-security/src/Http/Requests/Concerns/AuthorizesServiceRequest.php (Ligne 27)
* **Sévérité** : `CRITICAL`
* **Description** : Potential hardcoded credentials or API token found.
* **Code Suspect** :
  ```python
  $bearerToken = (string) $this->bearerToken();
  ```
