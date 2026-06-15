# ADR-001 : Utilisation des Images Distroless en Production

* **Statut** : Accepté
* **Date** : 2026-06-15
* **Auteurs** : Équipe DevSecOps SecureRAG Hub

---

## Contexte

Dans les architectures de microservices traditionnelles, les conteneurs sont souvent construits à partir d'images de base complètes (comme `debian`, `ubuntu` ou même `alpine`). Ces images embarquent un gestionnaire de paquets (`apt`, `apk`), des interpréteurs de commandes (`sh`, `bash`) et des utilitaires système standard (`curl`, `tar`, etc.).

Cependant, ces utilitaires augmentent considérablement :
1. **La surface d'attaque** : Si un attaquant parvient à exploiter une vulnérabilité applicative (ex: RCE), la présence d'un shell et de `curl` lui permet de télécharger des scripts malveillants et de pivoter au sein du cluster.
2. **Le nombre de vulnérabilités (CVE)** : Les outils système tiers introduisent un flux constant de CVE de sévérité moyenne à critique qu'il faut patcher régulièrement.
3. **La taille des images** : Plus d'espace disque consommé et temps de déploiement plus long.

## Décision

Nous décidons de bannir l'usage d'images système standard en production pour les remplacer par des images **Distroless** (fournies par Google Container Tools) pour l'exécution de tous les microservices applicatifs (PHP/Laravel et Python).

Les règles de construction d'images imposent :
- L'utilisation de builds multi-étapes (`multi-stage builds`).
- Les étapes de compilation/installation (`composer install`, `pip install`) s'effectuent sur une image SDK temporaire.
- L'image finale d'exécution copie uniquement les artefacts compilés sur une base minimale Distroless (ex: `gcr.io/distroless/python3-debian12` ou `chialab/php-dev:distroless` adapté).
- L'image finale ne contient aucun shell (`sh`, `bash`), aucun gestionnaire de paquets et aucun utilitaire non requis par l'exécution stricte de l'application.

## Conséquences

### Avantages (Pros)
* **Surface d'attaque minimale** : Pas de shell disponible par défaut. Les tentatives d'exécution de commandes système (ex. scénarios Falco) échouent immédiatement.
* **Réduction drastique des CVE** : Réduction de plus de 90 % des vulnérabilités recensées par Trivy lors des scans statiques d'images.
* **Optimisation de la performance** : Taille des images de conteneur divisée par 2 ou 3, accélérant les phases de tirage (`image pull`) et d'autoscaling du cluster.

### Inconvénients et Alternatives (Cons)
* **Complexité de débogage** : Il est impossible de faire un `kubectl exec -it <pod> -- sh` pour inspecter l'environnement de production.
* **Mitigation pour le débogage** : Utilisation systématique de la commande `kubectl debug` introduisant un conteneur de debug éphémère doté d'outils (ex: alpine) partageant le namespace réseau/processus du pod principal.
