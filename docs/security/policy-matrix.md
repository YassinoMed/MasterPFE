# Policy Matrix — SecureRAG Hub

## Objectif
Rendre lisible la posture de securite actuelle du cluster local et la trajectoire de durcissement retenue.

## Matrice Kyverno

| Policy | Mode actuel | Variante disponible | Prerequis | Impact | Risque |
|---|---|---|---|---|---|
| `securerag-require-pod-security` | `Audit` | `Enforce` non activee | Kyverno installe | Remonte les ecarts de posture pod sans bloquer la demo | faible en `Audit`, moyen en `Enforce` |
| `securerag-require-workload-controls` | `Audit` | `Enforce` via overlay | Kyverno installe | Exige probes et token ServiceAccount non monté dans les Deployments | faible en `Audit`, moyen en `Enforce` |
| `securerag-restrict-image-references` | `Audit` | `Enforce` via overlay | Kyverno installe, references images calibrees | Audite tags `latest` et registres non attendus | faible en `Audit`, moyen en `Enforce` |
| `securerag-restrict-service-exposure` | `Audit` | `Enforce` via overlay | Kyverno installe | Interdit `LoadBalancer` et limite `NodePort` au portail de demo | faible en `Audit`, moyen en `Enforce` |
| `securerag-restrict-volume-types` | `Audit` | `Enforce` via overlay | Kyverno installe | Interdit les volumes `hostPath` dans le namespace applicatif | faible en `Audit`, moyen en `Enforce` |
| `securerag-verify-cosign-images` | `Audit` | `Enforce` via overlay | Kyverno installe, images signees, cle publique valide, registre joignable | Controle la chaine de confiance des images SecureRAG | faible en `Audit`, eleve en `Enforce` si active trop tot |

## Guardrails namespace

| Controle | Etat | Prerequis | Impact | Risque si absent |
|---|---|---|---|---|
| Pod Security Admission `restricted` | actif dans les manifests | Kubernetes >= 1.25 | Bloque les pods non conformes au profil restricted | pods privilégiés ou root acceptés |
| `ResourceQuota` | actif | namespace applique | Evite la surconsommation grossiere en demo locale | pression forte sur la machine locale |
| `LimitRange` | actif | namespace applique | Donne des defaults CPU / memoire / `ephemeral-storage` cohérents | incoherence des workloads et risque d'eviction non maitrise |
| `PodDisruptionBudget` | actif sur workloads critiques | replicas et workloads cibles | Protege les composants critiques des disruptions volontaires | interruption plus brutale des composants |
| `HPA` | actif | `metrics-server` installe | Rend la charge observable et l'autoscaling demonstrable | HPA presents mais non exploitables |
| Pods de validation hardened | actif dans les scripts | `curlimages/curl` disponible | Garde les smoke tests compatibles avec PSA restricted | pods de validation rejetés par admission |

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
- les pods ephemeres de validation utilisent `sa-validation`, `runAsNonRoot`, `seccomp RuntimeDefault`, `drop ALL` et des ressources bornées.

## Decision actuelle recommandee

- **demo standard** : `Audit`
- **legacy real/RAG restaure explicitement** : `Audit`
- **pre-prod ou cluster local maturise** : test ponctuel `Enforce` après preuve Cosign et rapport `k8s-ultra-hardening`
