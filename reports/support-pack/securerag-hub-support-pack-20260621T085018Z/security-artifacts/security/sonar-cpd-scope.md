# Sonar CPD Scope Validation - SecureRAG Hub

| Pattern | Status |
|---|---:|
| `**/config/**` | TERMINÉ |
| `services-laravel/*/config/*.php` | TERMINÉ |
| `platform/portal-web/config/*.php` | TERMINÉ |
| `**/database/migrations/0001_01_01_*.php` | TERMINÉ |
| `services-laravel/*/database/migrations/0001_01_01_*.php` | TERMINÉ |
| `platform/portal-web/database/migrations/0001_01_01_*.php` | TERMINÉ |
| `services-laravel/auth-users-service/database/migrations/2026_04_11_000003_create_permission_role_table.php` | TERMINÉ |
| `services-laravel/auth-users-service/database/migrations/2026_04_11_000004_create_role_user_table.php` | TERMINÉ |
| `**/database/factories/UserFactory.php` | TERMINÉ |
| `services-laravel/*/database/factories/UserFactory.php` | TERMINÉ |
| `platform/portal-web/database/factories/UserFactory.php` | TERMINÉ |
| `services-laravel/*/tests/Feature/AuthorizationSecurityTest.php` | TERMINÉ |
| `platform/portal-web/app/Support/DemoPortalData.php` | TERMINÉ |

## Interpretation

Statut global: TERMINÉ. Les fichiers Laravel générés ou déclaratifs restent analysés par Sonar, mais exclus du calcul CPD.
