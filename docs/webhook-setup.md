# Configuration du Webhook GitHub pour Jenkins

Ce guide explique comment configurer GitHub pour déclencher automatiquement le pipeline CI de Jenkins lors d'un `git push`.

## 1. Prérequis sur Jenkins

1. Assurez-vous que le plugin **GitHub Integration Plugin** est installé sur Jenkins.
2. Le `Jenkinsfile` de votre dépôt doit contenir la directive de déclenchement :
   ```groovy
   pipeline {
     agent any
     triggers {
       githubPush()
     }
     // ...
   }
   ```
3. Jenkins doit être accessible depuis Internet (ou au moins depuis les IP de GitHub) pour recevoir les appels Webhook.

## 2. Configuration sur GitHub

1. Accédez à votre dépôt sur GitHub.
2. Cliquez sur **Settings** (Paramètres) > **Webhooks** > **Add webhook** (Ajouter un webhook).
3. Remplissez le formulaire comme suit :
   - **Payload URL** : `https://<VOTRE_DOMAINE_JENKINS>/github-webhook/`
     *(Exemple: `https://jenkins.securerag.local/github-webhook/`)*. N'oubliez pas le `/` final.
   - **Content type** : Sélectionnez `application/json`.
   - **Secret** : (Optionnel mais recommandé) Entrez un secret partagé que vous aurez configuré dans les paramètres du plugin GitHub de Jenkins pour valider la provenance.
   - **Which events would you like to trigger this webhook?** : Laissez sur `Just the push event`.
   - **Active** : Cochez cette case.
4. Cliquez sur **Add webhook**.

## 3. Test et Vérification

1. Une fois ajouté, GitHub enverra un payload de test (ping) à Jenkins.
2. Un icône vert (✅) doit apparaître à côté du webhook dans GitHub si la communication est réussie.
3. Pour tester le flux complet :
   - Poussez un nouveau commit sur votre dépôt.
   - Vérifiez sur l'interface Jenkins qu'un nouveau build s'est déclenché automatiquement avec la mention "Started by GitHub push by [Utilisateur]".
