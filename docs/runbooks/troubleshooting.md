# Troubleshooting Runbook — SecureRAG Hub

## Docker daemon indisponible
### Symptôme
`Cannot connect to the Docker daemon`

### Vérifications
```bash
docker info
docker context ls
ls -l ~/.docker/run/docker.sock
```

### Action recommandée
```bash
osascript -e 'quit app "Docker"'
sleep 5
open -a Docker
until docker info >/dev/null 2>&1; do
  echo "Waiting for Docker daemon..."
  sleep 2
done
```

## Jenkins ne démarre pas
### Vérifications
```bash
docker compose -f infra/jenkins/docker-compose.yml logs
docker compose -f infra/jenkins/docker-compose.yml ps
curl -fsS http://localhost:8085/login
```

### Causes probables
- build de l’image Jenkins interrompu
- plugin incompatible
- configuration JCasC invalide

## Jobs Jenkins absents
### Vérifications
- présence des fichiers dans `infra/jenkins/jobs/`
- variable `CASC_JENKINS_CONFIG`
- logs Jenkins au démarrage

### Actions
- relancer `docker compose -f infra/jenkins/docker-compose.yml up --build -d`
- vérifier `infra/jenkins/casc/jenkins.yaml`

## Cosign échoue
### Vérifications
```bash
cosign version
ls -l /path/to/cosign.key /path/to/cosign.pub
```

### Causes probables
- clé absente
- mot de passe erroné
- image non poussée dans la registry

## `kind` déploie mais les pods ne passent pas `Ready`
### Vérifications
```bash
kubectl get pods -n securerag-hub
kubectl describe pod <pod> -n securerag-hub
kubectl logs <pod> -n securerag-hub
```

### Causes probables
- probe incorrecte
- image absente
- dépendance non disponible
- `NetworkPolicy` trop restrictive

## `Ollama` reste bloqué
### Causes probables
- image trop lourde à télécharger
- ressources machine insuffisantes
- disque saturé

### Actions recommandées
- attendre la fin du pull initial si la machine le permet
- documenter le fallback/mock pour la soutenance
- exécuter les validations non dépendantes du flux RAG complet
