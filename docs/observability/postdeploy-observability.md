# Observabilité Post-Déploiement — SecureRAG Hub

## Statut : FONCTIONNEL & OPÉRATIONNEL

Ce document décrit le fonctionnement et la configuration de la stack de surveillance (Prometheus, Grafana, Loki, Alertmanager) déployée pour piloter SecureRAG Hub.

---

## 1. Démarrage de la Stack d'Observabilité

La stack d'observabilité complète est prête à être déployée dans le namespace dédié `securerag-monitoring`.

```bash
# Démarrer la stack de monitoring
make observability-up

# Vérifier la bonne disponibilité des composants
kubectl get pods -n securerag-monitoring
```

---

## 2. Accès aux Tableaux de Bord (Port-Forward)

Pour des raisons de sécurité locale, les interfaces d'administration ne sont pas exposées directement à l'extérieur du cluster. Vous pouvez y accéder de manière sécurisée en exécutant les tunnels de port-forward suivants :

| Composant | Commande d'exposition | Port local | Identifiants par défaut |
| :--- | :--- | :---: | :--- |
| **Grafana** | `make grafana-port-forward` | `3000` | `admin` / `admin` |
| **Prometheus** | `make prometheus-port-forward` | `9090` | Aucun |
| **Alertmanager** | `make alertmanager-port-forward` | `9093` | Aucun |

---

## 3. Métriques Clés et SLO à Surveiller

Pour assurer le maintien en conditions opérationnelles (MCO) et de sécurité (MCS) du portail SecureRAG Hub, les indicateurs suivants sont configurés :

### 3.1 Disponibilité (SLO 99.9%)
* **Métrique** : `up{namespace="securerag-hub"}`
* **Rôle** : Alerte immédiate via Alertmanager si l'un des composants applicatifs Laravel (`portal-web`, `auth-users`, etc.) s'arrête ou n'est plus joignable par Prometheus.

### 3.2 Latence (SLO de Performance)
* **Métrique** : `http_request_duration_seconds_bucket` (ou temps de réponse applicatif).
* **Rôle** : Mesurer le temps de traitement des requêtes HTTP (cible SRE : 95% des appels en moins de 200 ms).

### 3.3 Taux d'Erreurs HTTP (SLO de Fiabilité)
* **Métrique** : `http_requests_total{status=~"5.."}`
* **Rôle** : Déclencher une alerte critique si le taux d'erreurs 5xx (Server Errors) dépasse 5% sur une fenêtre glissante de 5 minutes.

### 3.4 Consommation des Ressources (CPU/RAM)
* **Métrique** : `container_memory_working_set_bytes` et `container_cpu_usage_seconds_total`
* **Rôle** : Vérifier la conformité par rapport aux quotas et détecter les fuites de mémoire.

### 3.5 Redémarrages des Conteneurs (Restarts)
* **Métrique** : `kube_pod_container_status_restarts_total`
* **Rôle** : Détecter les pods instables bloqués dans des CrashLoops ou des fuites de ressources système.

### 3.6 Événements Kubernetes
* **Métrique** : `kube_pod_status_phase{phase="Failed"}`
* **Rôle** : Tracer les évictions de pods ou les échecs de planification.

### 3.7 Alertes Sécurité (Intégration Falco)
* **Métrique** : `falco_events_total`
* **Rôle** : Notifier en temps réel l'équipe DevSecOps en cas de détection d'intrusion ou de comportement anormal au niveau du noyau (ex: ouverture de shell non autorisé, écriture dans `/etc`).

---

## 4. Intégration Loki et Falco pour la Sécurité

* **Centralisation des logs** : Loki indexe en continu tous les logs applicatifs Laravel et les événements système.
* **Corrélation de sécurité** : Grafana affiche des graphes corrélant les erreurs HTTP de Laravel avec les alertes système générées en temps réel par Falco. Cela permet d'identifier l'impact direct d'une attaque (ex: une tentative d'injection SQL bloquée par le code mais détectée par la télémétrie réseau).
