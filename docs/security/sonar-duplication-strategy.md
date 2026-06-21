# Sonar Duplication Strategy - SecureRAG Hub

## Objectif

Réduire les duplications Sonar sans casser Laravel et sans masquer les contrôles de sécurité utiles.

## Décision

Les fichiers Laravel suivants restent dans le périmètre d'analyse Sonar, mais sont exclus du calcul CPD via `sonar.cpd.exclusions` :

- `config/*.php` des cinq applications Laravel ;
- migrations Laravel générées `0001_01_01_*` ;
- `UserFactory.php` généré par Laravel ;
- tests d'autorisation volontairement identiques entre microservices ;
- données statiques de démonstration du portail.

Cette décision évite de refactorer artificiellement des fichiers framework indépendants. Elle ne retire pas ces fichiers de l'analyse générale, car `sonar.cpd.exclusions` agit uniquement sur la duplication.

## Correction réelle appliquée

Le service RBAC contenait aussi des données de référence dans le code applicatif. Ces données ont été déplacées dans `services-laravel/auth-users-service/config/rbac.php`, afin que `RbacService` porte la logique de synchronisation plutôt qu'un gros tableau déclaratif.

## Validation

```bash
bash scripts/ci/validate-sonar-cpd-scope.sh
sonar-scanner
```

Résultat attendu :

- `artifacts/security/sonar-cpd-scope.md` indique `Statut global: TERMINÉ` ;
- après une nouvelle analyse Sonar, les fichiers `config/*`, migrations Laravel générées et factories ne doivent plus alimenter la métrique `Duplicated Lines`.

## Limite honnête

Le tableau Sonar Cloud ne se mettra pas à jour tant qu'une nouvelle analyse Sonar/Jenkins n'a pas été exécutée. Les anciennes duplications visibles dans l'interface peuvent donc rester affichées jusqu'au prochain scan.
