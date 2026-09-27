# SPIFFE/SPIRE — Statut de Déploiement (Phase 8)

**Date**: 2026-09-27T10:40:00Z

## Ce qui est DÉPLOYÉ

| Ressource | Statut |
|---|---|
| Namespace `spire-system` | ✅ Créé |
| SPIRE Server (Deployment) | ✅ Déployé (pod créé, image pulled) |
| SPIRE Agents (DaemonSet × 2 nœuds) | ✅ Déployés (pods créés) |
| SPIRE Controller Manager | ✅ Déployé (dans le même pod que le server) |
| ConfigMaps (server-config, agent-config) | ✅ Créés |
| RBAC (ClusterRole + Binding pour server et agent) | ✅ Appliqués |
| ServiceAccount (spire-server, spire-agent) | ✅ Créés |
| Service (spire-server) | ✅ Créé |
| Images dans le registry local | ✅ spire-server, spire-agent, controller-manager |

## Ce qui NE FONCTIONNE PAS ENCORE

| Problème | Cause | Fix requis |
|---|---|---|
| Server crash | `notifier(k8sbundle): unable to update configmaps "spire-bundle"` → résolu (ConfigMap créé) mais maintenant `keymanager(memory): client connection closing` | Configurer le keymanager sur disque ou vérifier la ConfigMap format |
| Agent crash | `open /run/spire/bundle/bundle.crt: no such file` → le ConfigMap n'est pas encore rempli par le serveur | Le serveur doit remplir le ConfigMap avant que les agents puissent se connecter |
| Controller manager | Partage le même pod que le server → crash avec lui | Séparer en pods distincts |

## Architecture cible (documentée dans le repo)

```
SPIRE Server ──── génère SVID ────▶ SPIRE Agents (DaemonSet)
     │                                  │
     │ k8sbundle notifier               │ Workload API
     ▼                                  ▼
ConfigMap spire-bundle ──────▶ Pods (auth-users, portal-web, etc.)
                                       │
                                       ▼
                              SVID (X.509 cert) → mTLS sans secrets
```

## Statut : IMPLEMENTED / NOT YET FULLY OPERATIONAL

L'infrastructure SPIRE est déployée et les pods démarrent (pulled, created, started),
mais le serveur crash sur une erreur de configuration interne (keymanager memory).
La résolution nécessite :
1. Configurer le keymanager sur disque (au lieu de mémoire)
2. Corriger le format du ConfigMap bundle
3. Séparer le controller-manager du serveur

**L'architecture et les manifests sont prêts** — une fois ces 3 points corrigés,
SPIRE fournira des identités cryptographiques (SVID) pour le mTLS.

---
*Images disponibles dans le registry local: spire-server, spire-agent, spire-controller-manager*
