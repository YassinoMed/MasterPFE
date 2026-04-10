# SecureRAG Hub Portal

Application Laravel 12 servant de portail User/Admin pour SecureRAG Hub.

## Role

- authentification et session utilisateur
- portail multi-chatbots
- ecrans d'administration
- supervision securite et DevSecOps

## Execution locale

Depuis le dossier `platform/` :

```bash
docker compose up --build
```

Acces :

- portail via `http://localhost:8081`
- acces direct Laravel via `http://localhost:8082`
- sante web via `http://localhost:8081/health`
- resume plateforme via `http://localhost:8081/api/v1/platform/summary`
