# Rapport de Tests Sécurité Dynamiques - AI Testing Agent
**Type de test** : Fuzzing & DAST intelligent
**Total des cas de tests exécutés** : 28

## 1. Résultats détaillés du Fuzzing
* **Type d'attaque** : `sqli`
  * Payload : `' OR 1=1 --`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `sqli`
  * Payload : `admin' --`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `sqli`
  * Payload : `' UNION SELECT username, password FROM users --`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `xss`
  * Payload : `<script>alert('xss')</script>`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `xss`
  * Payload : `<img src=x onerror=alert(1)>`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `xss`
  * Payload : `javascript:alert(1)`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `ssrf`
  * Payload : `http://169.254.169.254/latest/meta-data/`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `ssrf`
  * Payload : `http://localhost:8093/api/v1/trust/scores`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `ssrf`
  * Payload : `http://127.0.0.1:8500`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `rce`
  * Payload : `; cat /etc/passwd`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `rce`
  * Payload : `| id`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `rce`
  * Payload : `$(whoami)`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `jwt`
  * Payload : `eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJhZG1pbiJ9.`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `jwt`
  * Payload : `invalid_signature_token`
  * Endpoint ciblé : `/health`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `sqli`
  * Payload : `' OR 1=1 --`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `sqli`
  * Payload : `admin' --`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `sqli`
  * Payload : `' UNION SELECT username, password FROM users --`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `xss`
  * Payload : `<script>alert('xss')</script>`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `xss`
  * Payload : `<img src=x onerror=alert(1)>`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `xss`
  * Payload : `javascript:alert(1)`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `ssrf`
  * Payload : `http://169.254.169.254/latest/meta-data/`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `ssrf`
  * Payload : `http://localhost:8093/api/v1/trust/scores`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `ssrf`
  * Payload : `http://127.0.0.1:8500`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `rce`
  * Payload : `; cat /etc/passwd`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `rce`
  * Payload : `| id`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `rce`
  * Payload : `$(whoami)`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `jwt`
  * Payload : `eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJhZG1pbiJ9.`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
* **Type d'attaque** : `jwt`
  * Payload : `invalid_signature_token`
  * Endpoint ciblé : `/analyze`
  * Statut réponse : `500`
  * Verdict : **🔴 VULNERABLE**
