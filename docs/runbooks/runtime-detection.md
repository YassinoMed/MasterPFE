# Runtime Detection Runbook - SecureRAG Hub

## Objectif

Ajouter une preuve de détection runtime légère sans rendre le scénario kind/VPS instable.

## Profil supporté

Le profil versionné est `infra/runtime-security/falco/values-kind.yaml`. Il garde Falco en mode audit, sans Falcosidekick, avec limites CPU/RAM adaptées à une démo.

## Preuve non destructive

```bash
make runtime-detection-proof
```

Si Falco n'est pas installé, le rapport est `PRÊT_NON_EXÉCUTÉ`.

## Installation optionnelle

```bash
INSTALL_FALCO=true CONFIRM_RUNTIME_DETECTION_INSTALL=YES make runtime-detection-proof
```

Cette étape est volontairement optionnelle car le driver eBPF peut dépendre du noyau, de Docker/kind et des ressources VPS.

## Artefact

```text
artifacts/security/runtime-detection-proof.md
```

## Lecture honnête

- `TERMINÉ` : Falco est installé, les pods/DaemonSets sont visibles et des logs récents sont archivés.
- `PRÊT_NON_EXÉCUTÉ` : profil prêt mais non installé.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` : `kubectl`, `helm`, le noyau ou le cluster empêchent la preuve live.
