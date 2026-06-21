# SecureRAG Hub - Audit Security Service

## Role
`audit-security-service` is the Laravel business microservice responsible for
security incidents, audit logs and compliance evidence in SecureRAG Hub.

It provides a versioned REST API for:

- security incidents
- audit events
- compliance evidence
- security dashboard consumption by the Blade portal

This service records structured evidence for the `demo` scenario. It does not
pretend to replace a SIEM or a production SOC pipeline.

## API
Base path:

```text
/api/v1
```

Main endpoints:

```text
GET    /api/v1/health
GET    /api/v1/incidents
POST   /api/v1/incidents
GET    /api/v1/incidents/{incident}
PATCH  /api/v1/incidents/{incident}/status
GET    /api/v1/audit-logs
POST   /api/v1/audit-logs
GET    /api/v1/compliance-evidence
POST   /api/v1/compliance-evidence
```

`{incident}` uses UUID route binding.

## Local setup
```bash
cd services-laravel/audit-security-service
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8094
```

Health check:

```bash
curl http://127.0.0.1:8094/api/v1/health
```

## Tests
```bash
cd services-laravel/audit-security-service
php artisan test
```

Expected result:

```text
Feature and unit tests pass.
```

## Security notes
- No real secret is committed.
- Demo incidents and evidence are synthetic.
- Enrichment by SIEM/Kyverno/Jenkins evidence can be added later by adapters.
