# Configuration Webhook GitHub → Jenkins (Mode Local/Demo)

## Objectif
Activer le déclenchement automatique de la pipeline `securerag-hub-ci` lors d'un `git push`, finalisant ainsi l'automatisation CI/CD (P1).

## Étape 1 : Exposer Jenkins (Si GitHub est sur le cloud)
Comme Jenkins tourne localement (`localhost:8085`), GitHub ne peut pas l'atteindre directement.
Exposez-le temporairement :
```bash
# Lancer ngrok sur le port Jenkins
ngrok http 8085
# Noter l'URL publique générée (ex: https://abc-123.eu.ngrok.io)
```

## Étape 2 : Configuration côté Jenkins
1. Aller dans **Manage Jenkins > Plugins**.
2. Vérifier que le plugin "GitHub Integration Plugin" est installé et actif.
3. Aller dans le job **securerag-hub-ci > Configure**.
4. Dans l'onglet **Build Triggers**, cocher : `GitHub hook trigger for GITScm polling`.
5. Sauvegarder.

## Étape 3 : Configuration côté GitHub (Repository)
1. Dans le dépôt GitHub : **Settings > Webhooks > Add webhook**.
2. **Payload URL** : `https://<votre-url-ngrok>.ngrok.io/github-webhook/` *(⚠️ le "/" final est obligatoire)*.
3. **Content type** : `application/json`.
4. **Events** : Essayer juste "Just the push event".
5. Cliquez sur **Add webhook**.

## Étape 4 : Preuve locale de fonctionnement (Sans Ngrok)
Pour simuler le webhook localement et obtenir l'évidence de trigger, utilisez le script `scripts/ci/trigger-github-webhook.sh`.
