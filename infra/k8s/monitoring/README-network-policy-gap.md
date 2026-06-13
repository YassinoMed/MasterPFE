# Rapport d'analyse — Métriques de rejet des NetworkPolicies

Le CNI par défaut du cluster Kind (kindnet) ne supporte pas l'exposition des métriques de paquets rejetés (drop metrics).

## Limitation technique
Kindnet applique les règles réseau via iptables de manière basique sans agent d'observabilité eBPF ou Netfilter dédié. Il n'émet aucune métrique Prometheus native pour les flux bloqués par les NetworkPolicies.

## Recommandation SRE (Priorité P3)
Pour obtenir ces métriques avec précision, migrez le cluster vers le CNI Cilium.
Activez Hubble avec la configuration suivante dans le fichier de valeurs Helm de Cilium :

```yaml
hubble:
  metrics:
    enabled:
      - drop
      - dns
      - flow
```

Déployez ensuite le ServiceMonitor pour `cilium-agent` dans l'espace de noms `monitoring`.
