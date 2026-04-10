# Legacy GitHub Actions Workflows

Jenkins est la source de verite officielle pour la CI/CD de SecureRAG Hub.

Les workflows GitHub Actions conserves dans ce dossier sont maintenus a titre :

- d'historique technique ;
- de reference comparative ;
- de relance manuelle exceptionnelle si Jenkins local n'est pas disponible.

## Regle de gouvernance

- Jenkins fait foi pour les executions CI et CD normales.
- Les workflows GitHub presents ici sont deprecies.
- Ils sont volontairement limites a `workflow_dispatch` pour eviter toute double execution automatique sur `push` ou `pull_request`.
- Ils ne doivent pas etre re-actives sur `push` ou `pull_request` sans decision explicite de gouvernance.

## Workflows concernes

- `build-sign.yml`
- `ci-pr.yml`
- `deploy-kind-dev.yml`
- `validate-postdeploy.yml`

## Recommandation

Si une gouvernance encore plus stricte est souhaitee, ces workflows peuvent ensuite etre deplaces dans un dossier d'archive hors `.github/workflows/`.

## Strategie d'archivage recommandee

Etape 1 :
- conserver les workflows dans `.github/workflows/`
- les garder en `workflow_dispatch`
- conserver le prefixe `legacy-`

Etape 2 :
- une fois plusieurs campagnes Jenkins consolidees, deplacer ces fichiers vers un dossier de type `.github/workflows-legacy/`
- conserver ce `README` comme trace de gouvernance

Etape 3 :
- ne laisser dans `.github/workflows/` que des workflows volontaires et explicitement maintenus

## Position finale recommandee

- court terme : conserver ces workflows en lecture, relance manuelle exceptionnelle uniquement ;
- moyen terme : les deplacer hors `.github/workflows/` une fois plusieurs campagnes Jenkins consolidees ;
- long terme : ne garder dans `.github/workflows/` que des workflows explicitement maintenus et non redondants avec Jenkins.
