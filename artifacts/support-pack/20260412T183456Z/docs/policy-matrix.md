# Policy Matrix — SecureRAG Hub

## Objectif
Rendre lisible la posture de securite actuelle du cluster local et la trajectoire de durcissement retenue.

## Matrice Kyverno

| Policy | Mode actuel | Variante disponible | Prerequis | Impact | Risque |
|---|---|---|---|---|---|
| `securerag-require-pod-security` | `Audit` | `Enforce` non activee | Kyverno installe | Remonte les ecarts de posture pod sans bloquer la demo | faible en `Audit`, moyen en `Enforce` |
| `securerag-verify-cosign-images` | `Audit` | `Enforce` via overlay | Kyverno installe, images signees, cle publique valide, registre joignable | Controle la chaine de confiance des images SecureRAG | faible en `Audit`, eleve en `Enforce` si active trop tot |

## Guardrails namespace

| Controle | Etat | Prerequis | Impact | Risque si absent |
|---|---|---|---|---|
| `ResourceQuota` | actif | namespace applique | Evite la surconsommation grossiere en demo locale | pression forte sur la machine locale |
| `LimitRange` | actif | namespace applique | Donne des defaults CPU / memoire cohérents | incoherence des workloads |
| `PodDisruptionBudget` | actif sur workloads critiques | replicas et workloads cibles | Protege les composants critiques des disruptions volontaires | interruption plus brutale des composants |
| `HPA` | actif | `metrics-server` installe | Rend la charge observable et l'autoscaling demonstrable | HPA presents mais non exploitables |

## Strategie Audit -> Enforce

### Audit
Mode recommande pour :

- la soutenance ;
- un cluster local heterogene ;
- les phases de correction et de calibration.

### Enforce
Mode reserve a un environnement plus mature dans lequel :

- toutes les images SecureRAG sont signees de facon stable ;
- la cle publique Cosign est la bonne ;
- le registre est resoluble depuis les composants du cluster ;
- les pods ephemeres de validation n'utilisent pas une image prise a tort dans le scope de la policy.

## Decision actuelle recommandee

- **demo standard** : `Audit`
- **real local stabilise** : `Audit`
- **pre-prod ou cluster local maturise** : test ponctuel `Enforce`
