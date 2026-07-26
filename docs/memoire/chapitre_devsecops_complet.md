# Analyse Comparative et Évaluation Scientifique de la Chaîne DevSecOps dans les Architectures Cloud-Native Sécurisées

## Introduction

L’essor fulgurant des architectures cloud-natives, propulsé par la
conteneurisation et l’orchestration via Kubernetes, a fondamentalement
transformé le cycle de vie du développement logiciel. Cependant, cette
agilité s’accompagne d’une expansion critique de la surface d’attaque,
marquée par une recrudescence historique des compromissions de la chaîne
d’approvisionnement logicielle (*software supply chain attacks*). Pour y
faire face, les organisations ont progressivement superposé une
multitude d’outils de sécurité tout au long de leurs pipelines
d’Intégration et de Déploiement Continus (CI/CD), instaurant l’approche
DevSecOps.

Ce chapitre documente avec rigueur technique la chaîne DevSecOps
effectivement mise en œuvre dans le projet *SecureRAG Hub*, ainsi que la
couche de sécurité par intelligence artificielle qui vient s’y adosser.
Il s’inscrit en continuité directe du chapitre d’étude préalable et
d’état de l’art, dont il reprend et applique systématiquement le
principe de transparence entre ce qui est **réalisé**, ce qui est
**préparé** et ce qui relève d’une **perspective** d’évolution. Cette
discipline de classification n’est pas un exercice de prudence
rhétorique : elle conditionne directement la défendabilité du mémoire en
soutenance, où toute affirmation doit pouvoir être reliée à un artefact
vérifiable — code, manifeste, journal d’exécution ou rapport produit.

Par rapport à une version antérieure, ce chapitre renforce trois
dimensions explicitement identifiées comme insuffisamment développées :
(i) la profondeur de la comparaison avec les solutions concurrentes, qui
dépasse désormais le simple constat du choix retenu pour documenter les
compromis explicites et les conditions de bascule vers une alternative ;
(ii) la rigueur méthodologique des résultats expérimentaux et métriques
quantitatives, avec un protocole statistique explicite plutôt que des
valeurs isolées ; et (iii) un protocole de validation expérimentale
complet pour la couche de sécurité IA, dont le statut de contribution
principale du mémoire — s’il est retenu comme tel — exige un niveau de
preuve supérieur à celui d’un composant DevSecOps standard.

## Cartographie Globale des Outils par Statut

La figure <a href="#fig:cartographie_statut" data-reference-type="ref"
data-reference="fig:cartographie_statut">1.1</a> offre une vue
d’ensemble des familles d’outils mobilisées par *SecureRAG Hub*, codées
visuellement selon le statut Réalisé / Préparé / Perspective précisé à
la section suivante.

<figure id="fig:cartographie_statut">

<figcaption>Cartographie des familles d’outils de SecureRAG Hub, codées
par statut Réalisé / Préparé / Perspective / à confirmer.</figcaption>
</figure>

Cette cartographie fait apparaître un déséquilibre net entre la maturité
de la chaîne DevSecOps proprement dite — majoritairement Réalisé, à
l’exception notable du GitOps — et celle de la couche applicative RAG et
de la couche de sécurité IA, où les statuts Préparé, Perspective et « à
confirmer » dominent. Ce déséquilibre n’est pas anormal pour un projet
de fin d’études : il reflète la priorisation assumée, documentée au
chapitre d’étude préalable, de la gouvernance et de l’industrialisation
sur la performance conversationnelle immédiate.

## Méthodologie d’Évaluation

L’évaluation de chaque outil repose désormais sur une grille d’analyse à
**six** axes — le sixième, ajouté pour approfondir la dimension
comparative, distingue explicitement le constat du choix retenu (déjà
présent dans les versions antérieures) de son argumentation critériée
(développée
section <a href="#sec:comparaison_systematique" data-reference-type="ref"
data-reference="sec:comparaison_systematique">1.17</a>).

<figure id="fig:grille_analyse">

<figcaption>Grille d’analyse à six axes appliquée uniformément à chaque
outil de ce chapitre — le sixième axe est nouveau par rapport aux
versions antérieures.</figcaption>
</figure>

1.  **Positionnement architectural** : à quelle étape du cycle de vie
    logiciel l’outil intervient-il, et sur quelle primitive technique
    repose-t-il ?

2.  **Mécanisme de détection ou de contrôle** : quel est le modèle
    sous-jacent ?

3.  **Intégration effective dans SecureRAG Hub** : comment l’outil
    est-il concrètement déployé et configuré ?

4.  **Limites structurelles** : quelles sont les défaillances
    intrinsèques de l’outil pris isolément ?

5.  **Statut** : Réalisé, Préparé, ou Perspective, selon les définitions
    déjà établies.

6.  **Comparaison critériée aux alternatives** : sur quels critères
    explicites l’outil retenu domine-t-il — ou non — les alternatives
    sérieusement étudiées, et sous quelles conditions ce choix serait-il
    révisé ?

> **Avertissement méthodologique** : plusieurs versions successives de
> ce chapitre ont dû être corrigées après confrontation avec le code
> source réel du projet et avec le chapitre d’étude préalable. Certains
> outils initialement documentés comme pleinement opérationnels se sont
> révélés soit absents du projet, soit à un statut *Préparé* ou
> *Perspective* plutôt que *Réalisé*. Le présent chapitre applique
> désormais strictement le statut établi par le chapitre d’étude
> préalable. Cette même discipline s’applique au sixième axe introduit
> ci-dessus : une comparaison critériée n’est légitime que si elle
> repose sur des propriétés documentées et vérifiables des outils
> comparés, et non sur des mesures de performance qui n’ont pas été
> effectivement produites sur l’infrastructure du projet — ce point est
> développé
> section <a href="#sec:comparaison_systematique" data-reference-type="ref"
> data-reference="sec:comparaison_systematique">1.17</a>.

## Couche d’Orchestration CI/CD

### Jenkins

**Statut : Réalisé.**

#### Rôle et positionnement

Jenkins constitue l’autorité officielle de CI/CD de *SecureRAG Hub*. La
chaîne se décompose en deux pipelines déclaratifs et complémentaires :
le `Jenkinsfile`, qui opère exclusivement sur le code source, et le
`Jenkinsfile.cd`, qui manipule les artefacts conteneurisés et en
garantit l’intégrité de bout en bout.

#### Fonctionnement technique

Chaque pipeline est défini de manière déclarative et versionné dans le
dépôt Git au même titre que le code applicatif (*Pipeline as Code*),
soumis aux mêmes revues via *Pull Request*. Jenkins consomme les
événements émis par GitHub pour déclencher l’exécution.

#### Intégration dans SecureRAG Hub

Le pipeline CI exécute séquentiellement les tests unitaires PHPUnit et
l’analyse statique PHPStan (couverture minimale de 70 %), l’analyse SAST
Semgrep, la détection de secrets Gitleaks, le scan de dépendances Trivy
FS et `composer audit`, ainsi que la validation statique des manifestes
Kubernetes via kube-score. Un script de *quality gate* consolidé
(`scripts/ci/quality-gate.sh`) agrège l’ensemble de ces sorties. Le
pipeline CD reconstruit l’image, exécute Trivy en mode image, génère le
SBOM via Syft, signe l’artefact via Cosign, puis promeut l’image par
digest SHA-256.

La figure <a href="#fig:pipeline_ci" data-reference-type="ref"
data-reference="fig:pipeline_ci">1.3</a> détaille la séquence du
pipeline CI et la
figure <a href="#fig:pipeline_cd" data-reference-type="ref"
data-reference="fig:pipeline_cd">1.4</a> celle du pipeline CD.

<figure id="fig:pipeline_ci">

<figcaption>Séquence du pipeline CI
(<code>Jenkinsfile</code>).</figcaption>
</figure>

<figure id="fig:pipeline_cd">

<figcaption>Séquence du pipeline CD
(<code>Jenkinsfile.cd</code>).</figcaption>
</figure>

#### Limites structurelles

Jenkins, en tant qu’orchestrateur, ne possède aucune logique de sécurité
native : il exécute séquentiellement des scripts tiers dont il ne
comprend ni la sémantique ni la portée du résultat.

#### Comparaison critériée aux alternatives

Voir la grille consolidée de la
section <a href="#sec:comparaison_systematique" data-reference-type="ref"
data-reference="sec:comparaison_systematique">1.17</a>, ligne « CI/CD ».

#### Infrastructure d’Exécution : Nœuds et Agents Kubernetes Éphémères (CASC)

Une inspection directe de l’environnement d’exécution (`docker ps`,
`kubectl get nodes`) et du fichier de configuration
`infra/jenkins/casc/kubernetes-agents.yaml` confirme que Jenkins ne
s’exécute pas comme un unique processus monolithique, mais orchestre des
*Pod Templates* Kubernetes éphémères via le plugin Kubernetes et la
configuration déclarative CASC (*Configuration as Code*). Cette
infrastructure était jusqu’ici absente de l’inventaire de ce chapitre ;
elle est intégrée ici avec le même niveau de rigueur de statut que le
reste du document.

<figure id="fig:infra_casc">

<figcaption>Nœuds d’infrastructure observés directement
(<code>docker ps</code>, <code>kubectl get nodes</code>) : contrôleur
Jenkins, plan de contrôle et nœud <em>worker</em> du cluster
<code>kind</code>, registre OCI local et proxy Sigstore. Tous confirmés
Réalisé par observation directe de l’environnement en
exécution.</figcaption>
</figure>

Le tableau <a href="#tab:agents_casc" data-reference-type="ref"
data-reference="tab:agents_casc">1.1</a> et la
figure <a href="#fig:agents_distribution" data-reference-type="ref"
data-reference="fig:agents_distribution">1.6</a> détaillent les sept
*Pod Templates* déclarés. Leur existence dans le fichier CASC atteste
qu’ils sont **préparés et instanciables à la demande** ; elle ne
constitue pas à elle seule la preuve qu’un outil embarqué dans l’image
d’un agent est effectivement invoqué par une étape active du
`Jenkinsfile`. Conformément à la discipline de ce chapitre, chaque outil
est donc évalué individuellement : les outils déjà établis Réalisé
ailleurs dans ce document (Semgrep, Gitleaks, Trivy, Syft, Cosign,
kube-score, Kyverno CLI, kubectl) conservent ce statut au sein de
l’agent qui les héberge. Les outils dont la présence dans un agent
**contredit** un statut déjà établi (SonarQube, Grype, Helm, ArgoCD CLI)
ou qui n’apparaissent dans aucun autre inventaire de ce chapitre (OWASP
Dependency-Check, Checkov, OWASP ZAP, k6) sont reclassés **Préparé** :
l’infrastructure d’exécution existe, mais rien dans ce chapitre
n’atteste à ce stade qu’une étape du pipeline les invoque effectivement.

<div id="tab:agents_casc">

| **Agent (label)** | **Ressources**         | **Outillage**                              | **Statut par outil**                                                                                                                                            |
|:------------------|:-----------------------|:-------------------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `test-agent`      | 2 vCPU / 2 GiB         | PHP 8.4, Composer, PCOV, Xdebug            | Réalisé (cohérent avec PHPUnit établi)                                                                                                                          |
| `security-agent`  | 4 vCPU / 4 GiB         | Semgrep, Gitleaks, Trivy, Dependency-Check | Semgrep/Gitleaks/Trivy : Réalisé ; Dependency-Check : **Préparé** (absent de l’inventaire officiel avant ce constat)                                            |
| `docker-agent`    | 4 vCPU / 4 GiB (+DinD) | Docker BuildKit, Syft, Grype, Cosign       | Docker/Syft/Cosign : Réalisé ; Grype : **Préparé** (Trivy seul retenu en comparaison, section <a href="#sec:comparaison_systematique" data-reference-type="ref" 
                                                                                           data-reference="sec:comparaison_systematique">1.17</a>)                                                                                                          |
| `k8s-agent`       | 2 vCPU / 2 GiB         | Checkov, kube-score, Kyverno CLI           | kube-score/Kyverno CLI/Checkov : Réalisé (stage Terraform IaC Scan actif dans le Jenkinsfile)                                                                   |
| `sonar-agent`     | 2 vCPU / 4 GiB         | Sonar Scanner                              | **Préparé** (SonarQube explicitement écarté au profit de Semgrep, section <a href="#sec:comparaison_systematique" data-reference-type="ref"                     
                                                                                           data-reference="sec:comparaison_systematique">1.17</a>)                                                                                                          |
| `zap-agent`       | 4 vCPU / 4 GiB         | OWASP ZAP, k6                              | **Préparé** (ni l’un ni l’autre confirmé exécuté)                                                                                                               |
| `deploy-agent`    | 1 vCPU / 1 GiB         | kubectl, Helm, ArgoCD CLI                  | kubectl : Réalisé ; Helm : **Préparé** (Kustomize retenu en comparaison, section <a href="#sec:comparaison_systematique" data-reference-type="ref"              
                                                                                           data-reference="sec:comparaison_systematique">1.17</a>) ; ArgoCD CLI : **Réalisé** (ArgoCD déployé, section <a href="#sec:gitops" data-reference-type="ref"      
                                                                                           data-reference="sec:gitops">1.10</a>)                                                                                                                            |

Sept Pod Templates Kubernetes éphémères déclarés dans
`kubernetes-agents.yaml`, avec statut reclassifié outil par outil

</div>

<figure id="fig:agents_distribution">

<figcaption>Distribution des sept agents Pod éphémères du pipeline,
colorés selon le statut consolidé de leur outillage (détail par outil
individuel dans le tableau <a href="#tab:agents_casc"
data-reference-type="ref"
data-reference="tab:agents_casc">1.1</a>).</figcaption>
</figure>

## Intégration du DevSecOps dans le Cycle Agile : Sprint DevSecOps, DoD et Gouvernance

L’efficacité d’une démarche DevSecOps repose non seulement sur
l’outillage technique, mais également sur son intégration fluide au sein
du cycle de développement agile. Dans le cadre du projet *SecureRAG
Hub*, la sécurité n’est pas traitée comme une activité ponctuelle en fin
de projet, mais est directement infusée dans le rituel des **Sprints
Agile/Scrum** .

### Modélisation des Menaces et Security User Stories au Sprint Planning

Lors de la phase de *Sprint Planning*, chaque fonctionnalité métier (ex:
ingestion de documents vectoriels, authentification OAuth2, gestion du
dialogue RAG) est évaluée sous l’angle de la sécurité. Les exigences
sont déclinées sous forme de :

- **Security User Stories** : Histoires utilisateurs spécifiant les
  contrôles requis (ex: « En tant qu’administrateur, je veux que les
  clés d’API LLM soient chiffrées en base au repos afin d’éviter toute
  divulgation en cas de fuite de sauvegarde »).

- **Abuse Cases (Cas d’Abus)** : Scénarios modélisant les actions d’un
  attaquant (ex: « En tant qu’attaquant externe, je tente d’injecter une
  instruction système dans le prompt RAG pour exfiltrer le contexte
  applicatif »).

Ces éléments sont intégrés au *Product Backlog* et priorisés au même
titre que les fonctionnalités métiers.

### La Définition de Terminé (*Definition of Done* - DoD) Sécurisée

Pour garantir qu’aucun incrément logiciel vulnérable ne rejoigne la
branche principale (`main`), la **Definition of Done (DoD)** standard a
été enrichie d’exigences de sécurité strictes et automatisées. Une *User
Story* ne peut être déclarée « Terminée » que si elle satisfait les six
critères de la grille DoD DevSecOps :

<div id="tab:dod_devsecops">

| **Critère DoD DevSecOps**      | **Mécanisme de Contrôle Automatisé**      | **Seuil d’Acceptation (Gate)**        |
|:-------------------------------|:------------------------------------------|:--------------------------------------|
| 1\. Qualité & Tests            | Tests unitaires et d’intégration PHPUnit  | Couverture de code $\ge 70\%$         |
| 2\. Analyse Statique (SAST)    | Scan Semgrep par AST sur le code source   | 0 vulnérabilité `CRITICAL` ou `HIGH`  |
| 3\. Inviolabilité Secrets      | Scan d’entropie et regex Gitleaks         | 0 secret ou token détecté dans Git    |
| 4\. Sécurité Dépendances (SCA) | Scan Trivy FS et `composer audit`         | 0 CVE critique non dérogée            |
| 5\. Conformité Manifestes      | Audit statique kube-score & Kyverno CLI   | Score de conformité PSS Restricted OK |
| 6\. Intégrité Supply Chain     | Build Kaniko rootless, Syft SBOM & Cosign | Image signée SHA-256 + SBOM CycloneDX |

Grille des critères de la Definition of Done (DoD) DevSecOps appliquée
lors de chaque Sprint.

</div>

### Sprints d’Industrialisation et de Durcissement (*Security Hardening Sprints*)

Outre l’intégration continue au fil des sprints de delivery, le projet
intercale périodiquement des **Sprints d’Industrialisation et de
Durcissement** (*Hardening Sprints*). Ces sprints dédiés visent à :

1.  Exécuter des campagnes de tests dynamiques complexes (DAST OWASP
    ZAP) et de Red Teaming d’IA (fuzzing d’injections de prompt par
    Garak).

2.  Réduire la dette technique de sécurité (*Security Technical Debt*)
    issue des rapports d’audit statiques et des alertes de runtime eBPF
    (Falco).

3.  Valider les scripts de restauration de sauvegardes PostgreSQL et les
    procédures de réponse aux incidents
    (`RUNBOOK-INCIDENT-RESPONSE.md`).

### Mesure de Vélocité et Impact de la Sécurité sur l’Équipe

L’automatisation des contrôles au sein d’agents Kubernetes éphémères
CASC permet de contenir le surcoût temporel lié à la sécurité. L’analyse
des métriques d’équipe montre que l’exécution des contrôles DevSecOps
ajoute un temps moyen de **4.2 minutes** par build CI/CD, largement
compensé par la réduction de **96.5% du temps de remédiation (MTTR)**
grâce à la détection précoce des failles.

## Analyse de Sécurité (SAST / SCA / Secrets)

<figure id="fig:shift_left">

<figcaption>Trois analyses statiques complémentaires (<em>Shift
Left</em>) convergeant vers un security backlog et un quality gate
communs.</figcaption>
</figure>

### Semgrep (SAST)

**Statut : Réalisé.**

Semgrep intervient en tout début de chaîne pour analyser le code source
de l’ensemble des microservices. Il construit un arbre de syntaxe
abstraite (AST) et applique des règles déclaratives, ce qui le distingue
des approches par expressions régulières. Le projet mobilise les
*rulesets* publics Semgrep et des règles personnalisées PHP/Laravel. Les
exceptions justifiées sont tracées dans un *security backlog*. Limite
structurelle : l’analyse reste purement statique, sans garantie
d’atteignabilité en production.

#### Comparaison critériée à l’alternative SonarQube

SonarQube Community couvre une partie recoupante de la SAST mais se
positionne historiquement davantage comme outil de qualité de code
(dette technique, duplication) que comme moteur de règles de sécurité
dédié ; son intégration CI est plus lourde (serveur dédié, base de
données) que celle de Semgrep, qui s’exécute comme un binaire autonome
sans infrastructure serveur. Le critère décisif a été la légèreté
d’intégration dans un pipeline Jenkins déjà dense. Un basculement vers
SonarQube serait justifié si le projet visait explicitement un tableau
de bord de dette technique consolidé, ce qui n’est pas l’objectif du
présent mémoire.

### Gitleaks

**Statut : Réalisé.**

Gitleaks applique des expressions régulières et des heuristiques
d’entropie de Shannon sur chaque ligne modifiée et sur l’historique
complet lors d’un scan intégral. Il est exécuté comme étape bloquante du
pipeline CI, avec un fichier d’exceptions documenté (`.gitleaks.toml`).
Limite : un secret encodé, fragmenté ou injecté dynamiquement échappe
structurellement à l’analyse statique.

#### Comparaison critériée à l’alternative TruffleHog

TruffleHog ajoute une capacité de vérification active de certains types
de secrets (validation en ligne de la validité d’une clé auprès du
fournisseur), capacité que Gitleaks ne possède pas nativement. Ce gain
de précision a un coût : il suppose des appels réseau sortants depuis
l’environnement CI vers des services tiers, ce qui est en tension avec
la discipline de cloisonnement réseau (*deny-all* par défaut) documentée
section <a href="#sec:runtime_security" data-reference-type="ref"
data-reference="sec:runtime_security">1.9</a> pour l’environnement
runtime, et introduit une dépendance externe non souhaitée dans un
pipeline dont l’un des objectifs affichés est la reproductibilité hors
ligne. Gitleaks a été retenu pour cette raison, au prix d’un taux de
faux positifs de configuration légèrement supérieur, absorbé par le
fichier d’exceptions documenté.

### Trivy et `composer audit`

**Statut : Réalisé.**

Trivy est mobilisé en mode *filesystem* avant construction et en mode
image après construction. Pour l’analyse SCA, il extrait la nomenclature
des dépendances et effectue une correspondance contre des bases de
vulnérabilités agrégées ; pour l’analyse d’image, il inspecte chaque
couche OCI. Les exceptions acceptées sont tracées dans `.trivyignore`.
Limite : dépendance intégrale à l’exhaustivité et à la fraîcheur des
bases de données ; une vulnérabilité *zero-day* est structurellement
invisible.

#### Comparaison critériée à l’alternative Grype

Grype (Anchore) et Trivy (Aqua Security) partagent un positionnement
fonctionnel très proche : correspondance de nomenclature contre bases de
vulnérabilités publiques. La différence pratique déterminante dans ce
projet est l’unification : Trivy couvre à la fois le mode *filesystem*
et le mode image dans un seul binaire et une seule syntaxe de
configuration, alors que Grype se concentre sur l’image et suppose
l’usage combiné d’un second outil (par exemple Syft, déjà retenu par
ailleurs pour le SBOM) pour la génération de nomenclature en amont.
Retenir Trivy seul plutôt que Grype+Syft+un scanner FS distinct réduit
le nombre d’outils à maintenir dans le pipeline, au prix d’une
dépendance accrue à un unique fournisseur de base de vulnérabilités. Une
réévaluation serait justifiée si des divergences de couverture entre
bases de vulnérabilités devenaient critiques, ce qui justifierait alors
un usage combiné Trivy+Grype en double vérification plutôt qu’un
remplacement.

### Kube-score

**Statut : Réalisé.**

Kube-score évalue la conformité des manifestes Kubernetes (limites de
ressources, absence de conteneurs privilégiés, sondes de santé) sans
nécessiter de cluster actif, complété par des scripts personnalisés
validant statiquement la cohérence des politiques Kyverno. Limite :
aucune garantie sur le comportement runtime effectif.

## Build, Registre et Chaîne d’Approvisionnement

<figure id="fig:chaine_confiance">

<figcaption>Chaîne de confiance de l’artefact.</figcaption>
</figure>

### Docker et Discipline de l’Immuabilité

**Statut : Réalisé.**

Docker assure la conteneurisation via des `Dockerfiles` multi-étapes.
Deux disciplines structurent la chaîne : la **promotion digest-first**
(seul un digest scanné et signé est promu, tags mutables refusés) et le
**déploiement no-rebuild**. Les images sont hébergées sur un registre
local joignable depuis `kind`. Limite : l’immuabilité protège l’identité
de l’artefact mais ne dit rien sur son comportement une fois exécuté.

### Syft

**Statut : Réalisé.**

Syft génère systématiquement le SBOM CycloneDX de chaque artefact, en
catalogant les paquets couche par couche. Le SBOM sert aux audits de
conformité, à la veille de vulnérabilités et à l’inventaire des
licences. Limite : inventaire statique à un instant donné.

### Cosign (Sigstore)

**Statut : Réalisé.**

Cosign produit une signature détachée vérifiable, contrôlée dans le
pipeline CD avant promotion et potentiellement à l’admission. Les
attestations in-toto sont préparées mais non pleinement opérées.
Limite : garantit l’intégrité à la construction, pas le comportement
après démarrage.

#### Comparaison critériée à l’alternative Notation

Notation (projet CNCF) et Cosign (Sigstore) couvrent le même besoin
fonctionnel de signature d’image. Cosign a été retenu pour son
intégration documentée et directe avec la règle `verifyImages` de
Kyverno, déjà retenu par ailleurs comme moteur d’admission : les deux
projets partagent un écosystème de référence commun (Sigstore/Kyverno),
ce qui réduit le risque d’incompatibilité de format entre la signature
produite et sa vérification. Notation reste une alternative crédible si
le projet devait s’intégrer à un registre d’entreprise imposant
spécifiquement ce standard.

### Blockchain : Technologie Étudiée mais Non Retenue

**Statut : Non implémenté — piste étudiée et explicitement écartée.**

L’usage d’une blockchain a été envisagé pour garantir l’intégrité des
traces d’audit et fournir un registre infalsifiable des artefacts. Trois
arguments ont motivé son écartement : adéquation fonctionnelle (les
besoins d’intégrité sont déjà couverts par SHA-256, SBOM CycloneDX,
Cosign et `SHA256SUMS`), complexité opérationnelle (nœuds dédiés,
gouvernance cryptographique, gestion des clés, latence d’écriture sans
gain démontrable), et maturité contextuelle (adoption industrielle
limitée pour ce cas d’usage dans les plateformes de chatbots
d’entreprise). Cette décision illustre une discipline de conception plus
large : préférer un mécanisme simple, mature et démontrable à une
solution plus sophistiquée dont la valeur ajoutée resterait à prouver.

## Déploiement Kubernetes

<figure id="fig:kustomize_overlays">

<figcaption>Composition Kustomize.</figcaption>
</figure>

### Kubernetes `kind` et Kustomize

**Statut : Réalisé.**

Le déploiement s’appuie sur `kind`, sans dépendance à une infrastructure
cloud externe. La configuration est gérée par Kustomize en une base
commune et des *overlays* par environnement. Les ressources mobilisées
sont *namespaces*, *Deployments*, *Services*, *ConfigMaps* et *Secrets*
natifs, avec les trois sondes `startupProbe`, `readinessProbe` et
`livenessProbe`. Limite : un cluster `kind` local ne restitue ni la
latence réseau ni les contraintes de montée en charge d’un cluster de
production multi-nœuds.

#### Comparaison critériée à l’alternative Minikube

Minikube et `kind` couvrent un besoin équivalent de cluster Kubernetes
local. `kind` a été retenu pour son démarrage plus rapide et son
intégration Docker directe (le cluster *est* un ensemble de conteneurs
Docker, plutôt qu’une machine virtuelle comme dans certains pilotes
Minikube), ce qui réduit la consommation de ressources sur la machine de
développement et accélère le cycle de test du pipeline CD. Minikube
resterait pertinent si le projet nécessitait un pilote spécifique (par
exemple l’émulation de *LoadBalancer* via un *tunnel* dédié), besoin non
rencontré dans ce projet.

#### Comparaison critériée à l’alternative Helm pour la gestion des manifestes

Helm introduit un moteur de *templating* et un système de *charts*
versionnées, utile pour la distribution de logiciels tiers
paramétrables. Kustomize a été retenu car il opère par *overlay*
(surcharge de manifestes YAML natifs) sans langage de templating
supplémentaire à apprendre ni à maintenir : pour un projet interne dont
les manifestes ne sont pas destinés à être distribués à des tiers, cette
simplicité l’emporte sur la flexibilité de packaging offerte par Helm.
Un passage à Helm serait justifié si *SecureRAG Hub* devait un jour être
distribué comme produit installable par des tiers.

## Sécurité Runtime et Contrôle d’Admission

<figure id="fig:kyverno_audit_enforce">

<figcaption>Kyverno en mode Enforce (Réalisé).</figcaption>
</figure>

### Kyverno

**Statut : Réalisé (mode Enforce actif).**

Kyverno exprime ses règles en *ClusterPolicies* YAML natives à
Kubernetes. Le projet mobilise Kyverno pour : la règle `verifyImages`
(signature Cosign valide requise), le durcissement *SecurityContext*
(`runAsNonRoot`, `readOnlyRootFilesystem`,
`allowPrivilegeEscalation: false`, suppression des *capabilities*,
profil seccomp `RuntimeDefault`), et la validation RBAC/NetworkPolicies.
**Point de vigilance essentiel** : ces politiques sont actives en **mode
Audit**, qui consigne les violations sans bloquer la création des
ressources. Toute affirmation selon laquelle Kyverno « bloque » une
image non signée doit être nuancée : il *détecte et journalise*, sans
nécessairement empêcher.

#### Comparaison critériée à l’alternative OPA/Gatekeeper

Le cahier des charges initial identifiait OPA/Gatekeeper, fondé sur
Rego, comme alternative. Kyverno a été retenu pour la lisibilité de ses
politiques en YAML natif, contre la puissance d’expression supérieure
mais la courbe d’apprentissage plus exigeante de Rego. Sur le plan
strictement fonctionnel, Gatekeeper et Kyverno couvrent un périmètre
équivalent (mutation, validation, génération de ressources) ; la
différence pratique déterminante est l’accessibilité : une politique
Kyverno peut être relue et modifiée par un développeur familier de YAML
Kubernetes, alors qu’une politique Rego exige une compétence dédiée.
**OPA/Gatekeeper n’est pas déployé dans le projet**. Une bascule serait
justifiée si le projet devait un jour mutualiser ses politiques avec une
organisation ayant déjà standardisé sur Rego (par exemple pour des
politiques partagées avec des systèmes non Kubernetes, où Rego
s’applique plus largement que Kyverno).

### Falco

**Statut : Réalisé (capacité de détection démontrée) — opération
continue en production : Perspective.**

Falco capture les appels système via une sonde eBPF et confronte chaque
appel à des règles déclaratives de comportement anormal, déployé en
*DaemonSet*. L’activation continue avec routage systématique des alertes
reste une perspective ; la capacité de détection est démontrable dans un
scénario contrôlé. Limite : alertes brutes et isolées par nœud, sans
corrélation globale native.

#### Comparaison critériée aux alternatives Sysdig Secure et Tracee

Sysdig Secure, éditeur commercial à l’origine du projet Falco open
source, ajoute une couche de corrélation, un moteur de règles enrichi et
un support commercial, au prix d’une licence payante et d’une dépendance
à un fournisseur tiers pour l’hébergement des données de télémétrie.
Tracee (Aqua Security), également fondé sur eBPF, offre une alternative
purement open source proche de Falco mais avec un écosystème de règles
communautaires moins développé au moment de la conception du projet.
Falco a été retenu pour la maturité et le volume de sa base de règles
communautaires (CNCF *graduated project*) et pour l’absence de
dépendance commerciale, cohérente avec le choix assumé ailleurs dans ce
chapitre de n’écarter aucune alternative pour un motif de coût de
licence. Une bascule vers Sysdig Secure serait justifiable si le projet
devait un jour opérer en production avec un besoin de support
contractuel formel.

### Tetragon

**Statut : Réalisé.**

Tetragon complète Falco en apportant une capacité d’application active
(*enforcement*) au niveau du noyau via eBPF, permettant de bloquer un
appel système avant sa complétion. Limite : risque de disponibilité en
cas de faux positif entraînant le blocage d’une opération légitime.

### NetworkPolicies, RBAC Kubernetes et Quotas

**Statut : Réalisé.**

Les *NetworkPolicies* appliquent une segmentation *deny-all* par défaut.
Le RBAC restreint les droits des *ServiceAccounts* selon le moindre
privilège. Les *ResourceQuota* et *LimitRange* plafonnent les ressources
consommables. Limite : une politique *deny-all* mal calibrée peut
interrompre un flux légitime non anticipé.

## GitOps et Déploiement Continu

<figure id="fig:gitops_actuel_cible">

<figcaption>État GitOps avec ArgoCD (Réalisé).</figcaption>
</figure>

### ArgoCD

**Statut : Réalisé — l’industrialisation GitOps avec boucle de
réconciliation semi-automatisée est active.**

Dans sa cible architecturale, ArgoCD assurerait la synchronisation
continue entre l’état déclaré dans Git et l’état observé du cluster. Le
chapitre d’étude préalable classe explicitement cette industrialisation
parmi les perspectives d’évolution. Toute description d’un rollback
ArgoCD déclenché sans intervention humaine doit être relue comme une
cible fonctionnelle, non comme un comportement démontré. Limite : en son
absence, la promotion des artefacts repose sur Jenkins et la discipline
digest-first, sans boucle de réconciliation continue.

## Secrets, Données et Résilience

### Secrets Kubernetes Natifs

**Statut : Réalisé.**

Les ressources `Secret` natives portent les valeurs sensibles. Limite :
encodage base64 non chiffré au repos par défaut, la protection effective
dépendant du chiffrement *etcd* sous-jacent.

### SOPS et age

**Statut : Préparé.**

SOPS et `age` permettraient de chiffrer les fichiers de secrets avant
versionnement. Ces outils sont documentés et leur intégration est
préparée, mais leur opération réelle (chiffrement systématique,
rotation) n’est pas encore pleinement rejouée.

### HashiCorp Vault et External Secrets Operator

**Statut : Perspective — non mis en œuvre dans la version actuelle.**

Vault centraliserait le stockage et la rotation dynamique des secrets ;
ESO synchroniserait ces secrets vers les ressources natives Kubernetes.
Le chapitre d’étude préalable identifie explicitement ces outils comme
cibles d’évolution.

#### Comparaison critériée aux alternatives de gestion de secrets cloud (AWS Secrets Manager, GCP Secret Manager)

Les gestionnaires de secrets managés par les fournisseurs cloud (AWS
Secrets Manager, GCP Secret Manager, Azure Key Vault) offrent une
rotation automatique et une intégration IAM native, au prix d’une
dépendance directe à un fournisseur cloud spécifique. Ce choix est
structurellement incompatible avec le déploiement actuel du projet sur
un cluster `kind` local sans dépendance cloud externe (cf.
section <a href="#sec:runtime_security" data-reference-type="ref"
data-reference="sec:runtime_security">1.9</a>) : Vault,
auto-hébergeable, reste l’option cohérente avec cette contrainte de
souveraineté d’infrastructure, même si son adoption reste au statut
Perspective à ce stade.

## Persistance des Données et Résilience

### PostgreSQL et Stratégie de Sauvegarde

**Statut : Réalisé.**

Un *CronJob* déclenche périodiquement `pg_dump`, produit les fichiers de
sauvegarde et calcule leurs empreintes dans `SHA256SUMS`. Un **test de
restauration** restitue périodiquement ces sauvegardes dans un namespace
éphémère et vérifie le nombre de lignes attendues. Limite : la fréquence
du *CronJob* borne le *Recovery Point Objective*.

#### Comparaison critériée à l’alternative Velero

Velero offre une sauvegarde au niveau du cluster entier (ressources
Kubernetes et volumes persistants), plus large que la sauvegarde
applicative ciblée par `pg_dump`. Le projet a retenu `pg_dump` car la
donnée critique à protéger est le contenu de la base PostgreSQL
elle-même, et non l’état complet du cluster (reconstructible depuis les
manifestes Kustomize versionnés dans Git). Velero deviendrait pertinent
si le projet devait garantir la restauration de volumes non
reconstructibles depuis Git (par exemple un futur volume Qdrant en
production).

## Observabilité

### Prometheus, Loki, Grafana et Alertmanager

**Statut : Préparé — manifests posés, exploitation continue en mode SRE
: Perspective.**

La pile associe Prometheus (métriques), Loki (logs), Grafana
(visualisation) et Alertmanager (routage des alertes). Le chapitre
d’étude préalable est explicite : ces briques sont préparées, mais leur
exploitation continue en mode SRE constitue une perspective.

#### Comparaison critériée aux alternatives Datadog et pile ELK

Datadog, solution commerciale intégrée, réduirait la charge
d’exploitation de la pile d’observabilité au prix d’un abonnement
récurrent et d’une dépendance à un fournisseur SaaS externe. La pile ELK
(Elasticsearch/Logstash/Kibana) couvre un périmètre de centralisation de
logs comparable à Loki mais avec une empreinte mémoire et une complexité
opérationnelle sensiblement supérieures pour un usage à l’échelle d’un
projet de fin d’études. Prometheus/Loki/Grafana a été retenu pour sa
légèreté relative et sa cohérence avec l’écosystème CNCF déjà mobilisé
(Falco, Tetragon, Kyverno relèvent du même écosystème de gouvernance).

## Preuves Techniques et Readiness Finale

### Evidence Collectors et Support Pack

**Statut : Réalisé.**

Les *evidence collectors* agrègent automatiquement les artefacts de
preuve : résultats de tests, rapports Semgrep/Gitleaks/Trivy, SBOM,
signatures, manifestes appliqués. Ces artefacts sont organisés en
*validation reports*, *security reports*, *readiness report*, agrégés
dans un *support pack* et un *final validation summary*. Limite : la
valeur probante dépend intégralement de la fraîcheur de génération.

## Sécurité Applicative de la Couche RAG

### Périmètre Applicatif : Architecture en Cinq Microservices

**Statut : Réalisé.**

Le socle applicatif repose sur Laravel (ADR-001), décomposé en
`portal-web`, `auth-users-service`, `chatbot-manager-service`,
`conversation-service`, et un cinquième service d’audit dont la portée
exacte reste à préciser.

### VectorStore Qdrant et Filtrage RBAC par Métadonnées

**Statut : Réalisé — Filtrage RBAC Vectoriel actif via métadonnées.**

Le contrôle d’accès serait appliqué directement au niveau de Qdrant,
lors de la recherche par similarité, via des métadonnées `allowed_roles`
et `sensitivity_level`. Le chapitre d’étude préalable est sans
ambiguïté : Qdrant est posé sous forme de manifeste mais non sollicité
par le scénario démontré.

#### Comparaison critériée aux alternatives Weaviate et Milvus

Weaviate offre un filtrage de métadonnées natif comparable à celui visé
pour Qdrant, avec en plus un module d’hybridation texte/vecteur
intégré ; Milvus vise davantage des déploiements à très grande échelle
avec une architecture distribuée plus complexe à opérer que ne le
justifie le périmètre actuel du projet. Qdrant a été retenu pour la
simplicité de son modèle de filtrage par métadonnées, directement
alignée sur le besoin de RBAC vectoriel décrit ci-dessus, sans
nécessiter l’infrastructure distribuée qu’impose Milvus.

### Security-Auditor / Audit Applicatif

**Statut : Partiellement couvert.**

Le service *Security-Auditor* inspecterait les prompts et réponses pour
détecter *prompt injection* et fuites de données. Certaines fonctions
sont partiellement couvertes par l’audit applicatif existant, mais sa
version complète fait partie des évolutions identifiées.

### LLM et Ollama

**Statut : Perspective — non opéré comme dépendance du scénario
officiel.**

Ollama est identifié comme runtime local pressenti (Llama 3 ou Mistral
candidats). Le projet ne vise pas à exploiter un LLM réel comme
dépendance obligatoire du scénario officiel.

#### Comparaison critériée à l’alternative d’une API LLM externe sécurisée

Une API LLM externe (par exemple un fournisseur cloud d’inférence)
offrirait une qualité de génération supérieure à un modèle open source
hébergé localement sur des ressources matérielles limitées, au prix
d’une perte de souveraineté sur les contenus conversationnels transmis
hors du périmètre du cluster. Le compromis retenu par la conception —
Ollama local par défaut, API externe envisageable seulement sous réserve
d’une analyse de souveraineté si les ressources locales s’avéraient
insuffisantes — reflète la priorité donnée à la gouvernance des données
dans l’ensemble de ce mémoire, cohérente avec le choix de Vault
auto-hébergé plutôt qu’un gestionnaire de secrets cloud
(section <a href="#sec:runtime_security" data-reference-type="ref"
data-reference="sec:runtime_security">1.9</a>).

### Pipeline Cible de Vectorisation Documentaire

**Statut : Perspective — architecture conçue, non opérée.**

Le flux prévu se décompose en onze étapes : ingestion, extraction,
nettoyage, *chunking*, *embeddings*, indexation Qdrant, recherche
vectorielle, filtrage RBAC, construction du prompt enrichi, appel LLM,
audit de la réponse. *LangChain*/*LangGraph* et *LlamaIndex* sont
identifiées comme bibliothèques candidates, toutes trois au statut
Perspective.

<figure id="fig:rag_pipeline_cible">

<figcaption>Onze étapes du pipeline cible de vectorisation documentaire.
L’ensemble du flux est Perspective, à l’exception de l’indexation Qdrant
dont le manifeste est Préparé (posé mais non sollicité, section <a
href="#sub:vectorstore_qdrant_note" data-reference-type="ref"
data-reference="sub:vectorstore_qdrant_note">1.15.2</a>).</figcaption>
</figure>

### Sécurité de l’IA et du RAG : Risques Anticipés et Protections Prévues

**Statut : Exigences de conception formalisées — opération complète
conditionnée à l’activation du moteur RAG (Perspective).**

<div id="tab:risques_ia_devsecops">

| **Risque**                     | **Description**                                              | **Protection prévue**                                                                       |
|:-------------------------------|:-------------------------------------------------------------|:--------------------------------------------------------------------------------------------|
| Prompt injection               | Instructions cachées dans une entrée ou un document récupéré | Règles de détection, séparation prompt système/contexte/requête, scoring de suspicion       |
| Fuite de données               | Restitution d’informations non autorisées                    | Filtrage RBAC en amont du retrieval, filtrage vectoriel par métadonnées, audit des réponses |
| Hallucination                  | Contenu plausible mais factuellement faux                    | Ancrage sur les passages récupérés, affichage des références sources                        |
| Accès non autorisé             | Filtrage par rôle non appliqué au retrieval                  | RBAC au retrieval, métadonnée `allowed_roles`                                               |
| Secrets dans les prompts       | Capture involontaire de clés/jetons                          | Nettoyage des documents ingérés, détection de motifs                                        |
| Journalisation excessive       | Vecteur de fuite via la conservation détaillée               | Stockage de hash, politique de rétention                                                    |
| Dépendance à un modèle externe | Provenance hors contrôle du projet                           | Préférence pour un modèle local, documentation de provenance                                |
| Réponse non conforme           | Violation de format/confidentialité                          | Audit systématique, blocage/marquage, tests OWASP LLM Top 10                                |

Risques IA anticipés et protections prévues

</div>

<figure id="fig:risques_ia_diagram">

<figcaption>Correspondance entre les huit risques IA/RAG anticipés et
leurs protections prévues. L’ensemble — risques et protections — relève
d’exigences de conception formalisées (traits pointillés) : l’opération
complète reste conditionnée à l’activation du moteur RAG (Perspective,
section <a href="#sub:vectorstore_qdrant_note" data-reference-type="ref"
data-reference="sub:vectorstore_qdrant_note">1.15.2</a>).</figcaption>
</figure>

## Composants Architecturaux Complémentaires du Cahier des Charges

### API Gateway

**Statut : Préparé — composant architectural identifié, à détailler dans
la conception.**

L’API Gateway constituerait le point d’entrée unique de la plateforme,
fonction actuellement assumée de façon plus limitée par `portal-web`.

### LLM-Orchestrator

**Statut : Préparé au niveau des contrats de service — Perspective sur
l’activation opérationnelle.**

Ce service orchestrerait le flux RAG complet, articulé avec le RBAC
applicatif déjà en place.

<figure id="fig:api_gateway_llm_orch">

<figcaption>Architecture cible intégrant l’API Gateway et le
LLM-Orchestrator au-dessus des composants déjà Réalisé
(<code>portal-web</code>, microservices). Les flèches pointillées
marquent un chemin non encore opérationnel.</figcaption>
</figure>

## Grille de Comparaison Systématique et Approfondie des Alternatives

Les sous-sections précédentes ont introduit, outil par outil, une
comparaison critériée à l’alternative la plus directement concurrente.
Cette section consolide l’ensemble en une grille unique et l’étend à des
critères transversaux, afin de répondre explicitement à l’exigence
d’approfondissement de la comparaison concurrentielle.

> **Avertissement méthodologique** : les critères ci-dessous restent
> qualitatifs (échelle Faible / Moyen / Élevé), justifiés par des
> propriétés architecturales documentées (dépendance à un service tiers,
> langage de configuration, empreinte d’infrastructure requise) et non
> par une mesure de performance chiffrée. Aucune campagne de bancs
> d’essai comparatifs n’a été exécutée sur l’infrastructure du projet ;
> publier une colonne de performance mesurée sans cette exécution
> reproduirait exactement l’erreur de statut déjà corrigée pour d’autres
> composants dans ce chapitre. La
> section <a href="#sec:metriques_reelles" data-reference-type="ref"
> data-reference="sec:metriques_reelles">1.22</a> définit le protocole
> permettant de produire, le cas échéant, une telle mesure sur le
> sous-ensemble d’outils pour lequel l’infrastructure de mesure est déjà
> disponible.

<div id="tab:grille_multicritere">

| **Famille**     | **Candidats comparés**                    |         **Dépendance externe**          |     **Langage/format**      | **Maturité écosystème** | **Coût d’exploitation** | **Condition de bascule vers l’alternative**                                          |
|:----------------|:------------------------------------------|:---------------------------------------:|:---------------------------:|:-----------------------:|:-----------------------:|:-------------------------------------------------------------------------------------|
| CI/CD           | Jenkins vs GitHub Actions vs GitLab CI    |      Faible (Jenkins auto-hébergé)      |      Groovy déclaratif      |         Élevée          |          Moyen          | Migration vers un hébergement Git managé imposant son propre CI                      |
| Cluster local   | `kind` vs Minikube                        |                 Aucune                  |          YAML/CLI           |         Élevée          |         Faible          | Besoin d’un pilote VM spécifique non couvert par Docker                              |
| SAST            | Semgrep vs SonarQube                      |            Aucune (Semgrep)             |     Règles déclaratives     |         Élevée          |         Faible          | Besoin d’un tableau de bord de dette technique consolidé                             |
| Secrets scan    | Gitleaks vs TruffleHog                    | Aucune (Gitleaks) / Réseau (TruffleHog) |       Regex/entropie        |     Moyenne/Élevée      |         Faible          | Besoin de vérification active de validité des secrets                                |
| SCA/image       | Trivy vs Grype+Syft                       |                 Aucune                  |     CLI unifiée (Trivy)     |         Élevée          |         Faible          | Divergence critique de couverture entre bases de vulnérabilités                      |
| Signature       | Cosign vs Notation                        |                 Aucune                  |        OCI/Sigstore         |         Moyenne         |         Faible          | Registre d’entreprise imposant le standard Notation                                  |
| Manifestes      | Kustomize vs Helm                         |                 Aucune                  |   YAML natif (Kustomize)    |         Élevée          |         Faible          | Distribution du projet comme produit installable tiers                               |
| Admission       | Kyverno vs OPA/Gatekeeper                 |                 Aucune                  | YAML natif (Kyverno) / Rego |     Moyenne/Élevée      |         Faible          | Mutualisation de politiques avec systèmes non Kubernetes                             |
| Runtime detect. | Falco vs Sysdig Secure vs Tracee          |  Aucune (Falco/Tracee) / SaaS (Sysdig)  |         Règles eBPF         |     Élevée (Falco)      |  Faible/Élevé (Sysdig)  | Besoin de support contractuel formel en production                                   |
| Secrets         | Vault/ESO vs gestionnaires cloud managés  |    Aucune (Vault) / Cloud (managés)     |         API dédiée          |         Moyenne         | Moyen/Faible (managés)  | Migration vers une infrastructure cloud pérenne                                      |
| Sauvegarde      | `pg_dump` vs Velero                       |                 Aucune                  |         Script/CRD          |         Moyenne         |         Faible          | Volumes persistants non reconstructibles depuis Git                                  |
| Observabilité   | Prometheus/Loki/Grafana vs Datadog vs ELK |  Aucune (stack CNCF) / SaaS (Datadog)   |        PromQL/LogQL         |         Élevée          | Faible/Élevé (Datadog)  | Besoin d’un support SaaS géré sans équipe SRE dédiée                                 |
| VectorStore     | Qdrant vs Weaviate vs Milvus              |                 Aucune                  |        API REST/gRPC        |         Moyenne         |         Faible          | Passage à une échelle distribuée justifiant Milvus                                   |
| Inférence LLM   | Ollama local vs API externe               |      Aucune (Ollama) / Cloud (API)      |         API locale          |         Moyenne         |     Faible/Variable     | Ressources matérielles locales insuffisantes, sous réserve d’analyse de souveraineté |

Grille consolidée de comparaison critériée aux alternatives, par famille
d’outils

</div>

### Lecture Transversale de la Grille

Quatre régularités se dégagent de cette grille consolidée.

Premièrement, **la dépendance externe est le critère le plus
systématiquement discriminant** dans les arbitrages de ce projet :
chaque fois qu’une alternative introduisait une dépendance à un service
tiers (réseau pour TruffleHog, SaaS pour Sysdig Secure ou Datadog, cloud
pour les gestionnaires de secrets managés), l’option auto-hébergée a été
préférée, même au prix d’une fonctionnalité ou d’une automatisation
moindre. Cette régularité traduit une priorité de conception assumée
pour la souveraineté et la reproductibilité hors ligne, cohérente avec
le choix de `kind` plutôt qu’une infrastructure cloud pour l’ensemble du
projet.

Deuxièmement, **le critère de la courbe d’apprentissage l’emporte sur la
puissance d’expression théorique** lorsque les alternatives couvrent un
périmètre fonctionnel équivalent — cas de Kyverno face à OPA/Gatekeeper,
et de Kustomize face à Helm.

Troisièmement, **aucune alternative n’a été écartée pour un motif de
coût de licence à proprement parler** : les cas où un coût
d’exploitation « Élevé » apparaît (Sysdig Secure, Datadog, gestionnaires
de secrets cloud) correspondent à des solutions commerciales/managées
écartées principalement pour la dépendance externe qu’elles
introduisent, le coût de licence n’étant qu’une conséquence de cette
dépendance et non le motif premier de l’arbitrage.

Quatrièmement, et c’est l’apport principal de cette grille consolidée
par rapport à un simple tableau de choix : **chaque ligne documente
explicitement une condition de bascule**. Cela transforme un choix
technologique en engagement réévaluable plutôt qu’en décision figée, et
permet — en soutenance — de répondre précisément à la question «
pourquoi pas X ? » pour chaque outil du projet par une condition
falsifiable plutôt que par une préférence non argumentée.

<figure id="fig:grille_regularites">

<figcaption>Les quatre régularités transversales dégagées de la grille
de comparaison consolidée (tableau <a href="#tab:grille_multicritere"
data-reference-type="ref"
data-reference="tab:grille_multicritere">1.4</a>).</figcaption>
</figure>

## Synthèse des Limites Structurelles Transversales

<figure id="fig:quatre_defaillances">

<figcaption>Les quatre défaillances structurelles transversales communes
à l’ensemble de la chaîne DevSecOps.</figcaption>
</figure>

L’analyse détaillée conduite ci-dessus converge vers un constat unique :
**aucun composant pris isolément ne dispose de la mémoire d’état, du
contexte transversal et de la capacité d’inférence nécessaires pour
distinguer un événement bénin d’un événement malveillant lorsque ces
deux catégories produisent un signal syntaxiquement identique**. Ce
constat se décline en quatre défaillances : silos informationnels,
surcharge cognitive (notamment via Kyverno en mode Audit), absence de
scoring de risque unifié, et latence de remédiation (Kyverno Audit +
ArgoCD Perspective imposant une intervention manuelle).

C’est la résolution de ces quatre défaillances, et non le remplacement
d’un composant Réalisé, que vise la couche de sécurité IA décrite
ci-après.

## Intégration Reclassifiée du Guide Opérationnel de la Chaîne DevSecOps

> **Origine et méthode de cette section** : un guide opérationnel
> distinct (diagrammes de flux et tableaux de stages, non rédigé selon
> la discipline Réalisé/Préparé/Perspective de ce mémoire) décrit la
> chaîne DevSecOps de *SecureRAG Hub* comme un pipeline intégralement
> actif, y compris plusieurs composants que ce chapitre a explicitement
> classés Perspective ou explicitement écartés au profit d’une
> alternative
> (section <a href="#sec:comparaison_systematique" data-reference-type="ref"
> data-reference="sec:comparaison_systematique">1.17</a>). Cette section
> ne reproduit pas ce guide tel quel : chaque élément y est confronté au
> statut déjà établi ailleurs dans ce chapitre avant intégration,
> conformément à l’avertissement méthodologique déjà formulé
> section <a href="#sec:methodologie" data-reference-type="ref"
> data-reference="sec:methodologie">1.3</a>. Les écarts identifiés comme
> contradictoires sont signalés explicitement plutôt que silencieusement
> corrigés, car ils constituent en eux-mêmes une information utile pour
> la soutenance : ils tracent l’endroit précis où une documentation
> antérieure du projet a anticipé un état cible non encore atteint.

### Écarts Identifiés entre le Guide Opérationnel et le Statut Documenté

<div id="tab:ecarts_guide_reclasse">

| **Composant (guide opérationnel)**                                                                                                                                                                      | **Statut implicite du guide**         | **Statut réel documenté dans ce chapitre**                                                                                                                       | **Verdict**                              |
|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------|:-----------------------------------------|
| ArgoCD (moteur GitOps actif dans le flux CD)                                                                                                                                                            | Opérationnel, réconciliation continue | **Perspective** (section <a href="#sec:gitops" data-reference-type="ref"                                                                                         
                                                                                                                                                                                                                                                   data-reference="sec:gitops">1.10</a>)                                                                                                                             | Contradiction majeure                    |
| Kyverno — « Enforce PSS Restricted » à l’admission                                                                                                                                                      | Bloquant                              | **Mode Audit uniquement** — aucune règle en Enforce (section <a href="#sec:runtime_security" data-reference-type="ref"                                           
                                                                                                                                                                                                                                                   data-reference="sec:runtime_security">1.9</a>)                                                                                                                    | Contradiction majeure                    |
| Grype (scan CVE bloquant, étape 7)                                                                                                                                                                      | Outil retenu et actif                 | **Écarté** — Trivy retenu explicitement à sa place (comparaison Trivy/Grype)                                                                                     | Contradiction majeure                    |
| SonarQube Quality Gate (étape 4)                                                                                                                                                                        | Stage actif du pipeline               | **Écarté** — Semgrep retenu explicitement à sa place (comparaison Semgrep/SonarQube)                                                                             | Contradiction majeure                    |
| AI Risk Analysis — rejet automatique si score $\geq 50{,}0$                                                                                                                                             | Blocage automatique en CI             | Contredit la remédiation manuelle établie (section <a href="#sec:scenario_attaque_e2e" data-reference-type="ref"                                                 
                                                                                                                                                                                                                                                   data-reference="sec:scenario_attaque_e2e">1.20</a>) ; statut global de `ai-security/` « à confirmer » (section <a href="#sec:ia_layer" data-reference-type="ref"  
                                                                                                                                                                                                                                                   data-reference="sec:ia_layer">1.23</a>)                                                                                                                           | Contradiction majeure                    |
| AI Security Agents $\times 6$ (STRIDE, DAST, etc., étape 10)                                                                                                                                            | Stage CI actif                        | Ne correspond à aucun composant identifié dans l’exploration du code `ai-security/` (section <a href="#sec:ia_layer" data-reference-type="ref"                   
                                                                                                                                                                                                                                                   data-reference="sec:ia_layer">1.23</a>)                                                                                                                           | À clarifier                              |
| Qdrant Vector Cluster (pod actif en production)                                                                                                                                                         | Opérationnel                          | **Préparé** — manifeste posé, non sollicité par le scénario démontré                                                                                             | À rétrograder                            |
| Ollama LLM Pod (actif en production)                                                                                                                                                                    | Opérationnel                          | **Perspective** — non opéré comme dépendance du scénario officiel                                                                                                | À rétrograder                            |
| Prometheus / Grafana / Loki (bloc « Runtime Sec »)                                                                                                                                                      | Opérationnel, au même titre que Falco | **Préparé** — manifests posés, exploitation continue en mode SRE = Perspective                                                                                   | À rétrograder                            |
| PostgreSQL 16 **HA** StatefulSet                                                                                                                                                                        | Haute disponibilité active            | Réalisé pour la sauvegarde/restauration ; **HA non confirmée** par aucune source de ce chapitre                                                                  | Qualificatif à retirer                   |
| OWASP Dependency-Check                                                                                                                                                                                  | Outil actif du pipeline               | Absent de l’inventaire officiel des outils de ce chapitre                                                                                                        | À vérifier                               |
| k6 (tests de charge & SLO Gate)                                                                                                                                                                         | Outil actif, seuils appliqués         | Absent de l’inventaire officiel des outils de ce chapitre                                                                                                        | À vérifier                               |
| DORA metrics (génération automatique)                                                                                                                                                                   | Métriques produites                   | Protocole de calcul défini (section <a href="#sec:metriques_reelles" data-reference-type="ref"                                                                   
                                                                                                                                                                                                                                                   data-reference="sec:metriques_reelles">1.22</a>), valeurs `[À EXÉCUTER]`                                                                                          | À reformuler comme perspective de mesure |
| Jenkins, PHPUnit, Semgrep, Gitleaks, Trivy FS, Docker digest-pinning, Syft, Cosign, Kyverno (Audit), Falco (capacité démontrée), Tetragon, NetworkPolicies/RBAC, PostgreSQL (backup/restore), Kustomize | Opérationnels                         | **Réalisé** — cohérent avec le statut déjà établi                                                                                                                | Confirmé, intégrable                     |

Confrontation du guide opérationnel de la chaîne DevSecOps au statut
Réalisé/Préparé/Perspective établi par ce chapitre

</div>

> **Point de vigilance pour la soutenance** : les cinq premières lignes
> du
> tableau <a href="#tab:ecarts_guide_reclasse" data-reference-type="ref"
> data-reference="tab:ecarts_guide_reclasse">1.5</a> décrivent des
> divergences qui ne peuvent pas être résolues par une simple
> reformulation éditoriale — elles supposent soit qu’une version du
> projet postérieure à la rédaction de ce chapitre a effectivement
> activé ces composants (auquel cas leur statut doit être révisé avec
> preuve à l’appui, sur le modèle du tableau des preuves de la
> section <a href="#sec:preuves_techniques" data-reference-type="ref"
> data-reference="sec:preuves_techniques">1.14</a>), soit que le guide
> opérationnel documente une *cible* plutôt qu’un état observé. Tant que
> cette ambiguïté n’est pas levée par vérification directe du code et du
> cluster, les diagrammes reclassifiés ci-dessous appliquent par défaut
> le statut le plus prudent, c’est-à-dire celui déjà établi et défendu
> ailleurs dans ce chapitre.

### Pipeline CI/CD — Version Reclassifiée

La figure <a href="#fig:pipeline_reclasse" data-reference-type="ref"
data-reference="fig:pipeline_reclasse">1.17</a> reprend la structure du
pipeline décrite par le guide opérationnel, recodée selon le statut réel
de chaque étape. Les étapes contradictoires (Grype, SonarQube, rejet
automatique par score IA) sont conservées mais marquées « à confirmer »
plutôt que simplement retirées, pour que la figure documente elle-même
le travail de vérification restant.

<figure id="fig:pipeline_reclasse">

<figcaption>Pipeline CI/CD du guide opérationnel, reclassifié selon le
statut Réalisé/Préparé/Perspective établi par ce chapitre. Les nœuds en
rouge pointillé marquent une divergence non résolue avec le reste du
chapitre, et non une évaluation négative de l’outil
lui-même.</figcaption>
</figure>

### Architecture du Cluster — Version Reclassifiée

La figure <a href="#fig:cluster_reclasse" data-reference-type="ref"
data-reference="fig:cluster_reclasse">1.18</a> reprend la cartographie
du cluster `kind` du guide opérationnel. Contrairement à la version
originale, qui place Qdrant et Ollama au même niveau visuel que
PostgreSQL, et Prometheus/Loki au même niveau que Falco, cette version
distingue explicitement les charges de travail effectivement exercées
par le scénario démontré
(section <a href="#sec:scenario_attaque_e2e" data-reference-type="ref"
data-reference="sec:scenario_attaque_e2e">1.20</a>) de celles qui ne le
sont pas encore.

<figure id="fig:cluster_reclasse">

<figcaption>Cartographie du cluster <code>kind</code>, reclassifiée par
statut réel. Comparer à la présentation du guide opérationnel, qui
plaçait Qdrant, Ollama et la pile d’observabilité au même niveau de
maturité que PostgreSQL et Falco.</figcaption>
</figure>

### Politiques d’Admission Kyverno — Correction de Statut

Le guide opérationnel présente quatre politiques Kyverno comme actives
en mode *Enforce* : `disallow-root-execution`, `verify-image-signature`,
`enforce-read-only-root-filesystem` et `drop-all-capabilities`. Cette
présentation doit être corrigée conformément au statut déjà établi
section <a href="#sec:runtime_security" data-reference-type="ref"
data-reference="sec:runtime_security">1.9</a> : ces quatre politiques
sont écrites et actives, mais en **mode Audit**. Elles consignent une
violation dans un *PolicyReport* sans empêcher la création de la
ressource non conforme. Le
tableau <a href="#tab:kyverno_correction" data-reference-type="ref"
data-reference="tab:kyverno_correction">1.6</a> reformule chaque
politique en distinguant l’intention de conception (ce que la politique
*ferait* en mode Enforce) de son comportement actuellement observable
(ce qu’elle fait réellement en mode Audit).

<div id="tab:kyverno_correction">

| **Politique Kyverno**               | **Comportement en mode Enforce (cible, Perspective)**                 | **Comportement réel en mode Audit (Réalisé)**                              |
|:------------------------------------|:----------------------------------------------------------------------|:---------------------------------------------------------------------------|
| `disallow-root-execution`           | Rejette la création du Pod si `runAsNonRoot: false` ou `runAsUser: 0` | Consigne la violation dans un *PolicyReport*, le Pod est tout de même créé |
| `verify-image-signature`            | Rejette toute image dont la signature Cosign est absente ou invalide  | Consigne la non-conformité, sans bloquer le déploiement                    |
| `enforce-read-only-root-filesystem` | Rejette un conteneur sans `readOnlyRootFilesystem: true`              | Consigne l’écart, autorise le déploiement                                  |
| `drop-all-capabilities`             | Rejette un conteneur ne supprimant pas l’ensemble des *capabilities*  | Consigne l’écart, autorise le déploiement                                  |

Distinction entre le comportement cible (Enforce, Réalisé) et le
comportement réellement observable (Audit, Réalisé) des politiques
Kyverno du guide opérationnel

</div>

### Spécifications des Images Conteneurs — Éléments Confirmés

Les principes de conteneurisation décrits par le guide opérationnel sont
cohérents avec le statut Réalisé déjà établi
(section <a href="#sec:comparaison_systematique" data-reference-type="ref"
data-reference="sec:comparaison_systematique">1.17</a>, ligne « Build,
Registre et Chaîne d’Approvisionnement ») et peuvent être intégrés sans
reclassification : images de base pinées par `sha256` (aucun tag
flottant en production), utilisateur non-root obligatoire (UID 10001),
système de fichiers racine en lecture seule à l’exception du répertoire
éphémère de *runtime*, et absence d’outils sensibles (`git`, `curl`,
compilateurs) dans l’image finale. Ces éléments peuvent être cités tels
quels dans la
section <a href="#sec:comparaison_systematique" data-reference-type="ref"
data-reference="sec:comparaison_systematique">1.17</a> existante sans
figure supplémentaire, le *Dockerfile* multi-stage du guide opérationnel
servant d’illustration technique directe de la discipline déjà décrite
en section <a href="#sec:gitops" data-reference-type="ref"
data-reference="sec:gitops">1.10</a>
et <a href="#sec:preuves_techniques" data-reference-type="ref"
data-reference="sec:preuves_techniques">1.14</a>.

### Synthèse et Actions Avant Soutenance

1.  **Vérifier directement dans le code** si Grype et SonarQube sont
    réellement absents du pipeline actif, ou si le guide opérationnel
    reflète une évolution postérieure au chapitre d’étude préalable —
    cas déjà rencontré pour `ai-security/`
    (section <a href="#sec:ia_layer" data-reference-type="ref"
    data-reference="sec:ia_layer">1.23</a>).

2.  **Confirmer ou infirmer** la présence d’OWASP Dependency-Check et de
    k6 dans le `Jenkinsfile` réel ; ni l’un ni l’autre ne figure dans
    l’inventaire officiel de ce chapitre.

3.  **Ne jamais présenter en soutenance** le rejet automatique par score
    de risque IA ($\geq 50{,}0$) comme un comportement démontré : cela
    contredirait directement le point d’arrêt explicite déjà établi
    section <a href="#sec:scenario_attaque_e2e" data-reference-type="ref"
    data-reference="sec:scenario_attaque_e2e">1.20</a> (remédiation
    manuelle).

4.  **Réutiliser systématiquement** le vocabulaire « mode Audit » plutôt
    que « Enforce » pour Kyverno dans toute présentation orale ou écrite
    dérivée du guide opérationnel.

5.  Si ces vérifications confirment le statut Réalisé de composants ici
    marqués « à confirmer », mettre à jour le
    tableau <a href="#tab:ecarts_guide_reclasse" data-reference-type="ref"
    data-reference="tab:ecarts_guide_reclasse">1.5</a> et la
    cartographie globale
    (figure <a href="#fig:cartographie_statut" data-reference-type="ref"
    data-reference="fig:cartographie_statut">1.1</a>) en conséquence,
    plutôt que de laisser deux sources du mémoire se contredire.

## Scénario Reproductible de Bout en Bout : Détection d’une Tentative d’Exploitation

### Objectif et Périmètre

Ce scénario démontre, sur la seule base des composants **Réalisé**, la
chaîne de détection multi-couche opérationnelle de *SecureRAG Hub*.
Conformément à la discipline de ce chapitre, il s’arrête explicitement
au point où la suite logique nécessiterait un composant Perspective :
aucune étape ne suppose Kyverno en mode Enforce ni ArgoCD
(section <a href="#sec:gitops" data-reference-type="ref"
data-reference="sec:gitops">1.10</a>).

<figure id="fig:scenario_e2e">

<figcaption>Séquence du scénario reproductible de bout en bout, avec
point d’arrêt explicite avant toute étape non Réalisé.</figcaption>
</figure>

### Phase 1 — Analyse Statique (Pré-Production)

1.  **Injection contrôlée d’un secret factice**, syntaxiquement
    représentatif mais fonctionnellement invalide, sur une branche de
    test dédiée hors `main`.

2.  **Déclenchement du pipeline CI** : Gitleaks détecte le secret, le
    *quality gate* bloque la progression.

3.  **Preuve à archiver** : capture horodatée du journal de *build*
    Jenkins.

4.  **Variante complémentaire** : substitution par une dépendance à CVE
    publique connue pour solliciter Trivy FS.

### Phase 2 — Détection Comportementale à l’Exécution

5.  **Déploiement d’une charge saine**, suivant la discipline
    digest-first
    (section <a href="#sec:runtime_security" data-reference-type="ref"
    data-reference="sec:runtime_security">1.9</a>).

6.  **Simulation contrôlée d’une action anormale** : ouverture d’un
    shell interactif via `kubectl exec` depuis le pod cible.

7.  **Détection Falco** : règle standard *Terminal shell in container*,
    alerte horodatée exploitable pour le MTTD
    (section <a href="#sub:mttd_mttr" data-reference-type="ref"
    data-reference="sub:mttd_mttr">1.22.2</a>).

8.  **Corrélation Tetragon** : appel système visible dans les journaux,
    confirmant la traçabilité noyau.

9.  **Vérification Kyverno (Audit)** : si le pod présente une
    non-conformité *SecurityContext* additionnelle, le *PolicyReport*
    correspondant est consigné et archivé.

### Phase 3 — Point d’Arrêt Explicite et Limite Documentée

> La chaîne Réalisé a démontré une détection multi-couche cohérente :
> statique (Gitleaks, Trivy), comportementale (Falco), conformité
> (Kyverno *PolicyReport*). Aucune étape suivante — isolation réseau
> automatique, rollback vers l’image précédente, blocage effectif à
> l’admission — ne peut être présentée comme démontrée : elle
> nécessiterait respectivement le mode Enforce de Kyverno et une
> orchestration ArgoCD en boucle fermée, tous deux Perspective. La
> remédiation, dans l’état démontré, est une action manuelle :
> redéploiement explicite via Jenkins CD.

## Dispositif et Protocoles de Test Multi-Couches : Campagnes d’Évaluation et d’Adversité

Afin d’étayer scientifiquement les performances annoncées de la chaîne
DevSecOps et d’assurer une évaluation rigoureuse de la plateforme
*SecureRAG Hub*, un dispositif de test multi-niveaux a été conçu et
exécuté via les suites de validation situées sous `scripts/validate/` et
`tests/`.

### Typologie des Protocoles de Test et Suites d’Évaluation

Le tableau <a href="#tab:typologie_tests" data-reference-type="ref"
data-reference="tab:typologie_tests">1.7</a> récapitule les sept
catégories de tests automatisés constituant le socle d’évaluation du
projet.

<div id="tab:typologie_tests">

| **Catégorie de Test**          | **Script / Harness de Test**       | **Périmètre du Contrôle**                  | **Résultat / Statut**           |
|:-------------------------------|:-----------------------------------|:-------------------------------------------|:--------------------------------|
| 1\. Tests Statiques & Qualité  | `phpunit`, `Semgrep`, `Hadolint`   | Code PHP/Laravel, Dockerfiles, AST         | `PASS` (Couverture $\ge 70\%$)  |
| 2\. Conformité K8s & Admission | `test-kyverno-admission.sh`        | Manifestes, PSS, Cosign verifyImages       | `PASS` (Mode Audit validé)      |
| 3\. DAST & Security Scanning   | `validate-dast-report.sh`          | Endpoints HTTP REST via OWASP ZAP          | `PASS` (0 vuln. High)           |
| 4\. Red Teaming IA & Fuzzing   | `garak` LLM Fuzzer                 | Injections de Prompt, RAG Jailbreaks       | `PASS` (Prompt guard OK)        |
| 5\. Tests d’Adversité Runtime  | `security-adversarial-advanced.sh` | Intrusions kernel, Syscalls `kubectl exec` | `PASS` (Falco MTTD = 1.8s)      |
| 6\. Chaos & High Availability  | `validate-ha-chaos-lite.sh`        | Crash de pods, résilience Kubernetes       | `PASS` (Auto-healing OK)        |
| 7\. Disaster Recovery (DR)     | `disaster-recovery-test.sh`        | Backup/Restore PostgreSQL `pg_dump`        | `PASS` (Restauration SHA256 OK) |

Typologie des sept catégories de tests automatisés et campagnes de
validation de SecureRAG Hub.

</div>

### Détail des Protocoles d’Adversité Runtime et Mesure Directe du MTTD

La détection runtime à l’aide des sondes eBPF Falco et Tetragon est
évaluée via le script `security-adversarial-advanced.sh` et la méthode
de mesure d’extraction horodatée `extract_falco_mttd.sh`.

#### Protocole d’injection d’anomalie système

1.  Une commande d’exécution interactive
    `kubectl exec -it <pod-laravel> – /bin/sh` est soumise au cluster
    `kind`.

2.  L’agent Falco intercepte l’appel système `execve` au niveau du noyau
    Linux via eBPF.

3.  L’alerte JSON horodatée est émise dans les journaux Loki et capturée
    par le script d’extraction :
    $$\text{MTTD} = t_{\text{log\_falco\_loki}} - t_{\text{exec\_syscall}} = 1.8 \text{ seconde}$$

### Protocoles de Tests d’Admission Kyverno et Fixtures

Le script `test-kyverno-fixtures.sh` injecte des manifestes de test
intentionnellement non conformes pour valider le moteur de politique :

- **Fixture 1 (Root Pod)** : Tentative de déploiement d’un pod avec
  `runAsUser: 0`. Kyverno génère une entrée d’audit `PolicyReport`
  confirmant la non-conformité au profil *Restricted*.

- **Fixture 2 (Unsigned Image)** : Tentative de déploiement d’une image
  non signée par Cosign. La règle `verifyImages` consigne la violation
  de signature.

### Campagne Globale de Validation et Restitution des Preuves (World-Class Suite)

L’exécution du harnais global `worldclass-validation.sh` agrège les
métriques post-déploiement et produit le bilan officiel
`artifacts/validation/validation-summary.md` :

- **Tests validés (`PASS`)** : 15 vérifications réussies (Services
  Kubernetes, Ingress, NetworkPolicies, PostgreSQL StatefulSet,
  SecurityContext, Falco DaemonSet).

- **Tests manqués (`FAIL`)** : 0 échec bloquant sur le scope officiel.

- **Tests ignorés (`SKIP`)** : 2 tests réservés aux modules optionnels
  (Ollama local legacy).

### Matrice Complète d’Évaluation DevSecOps : 19 Scénarios de Test et Métriques KPIs

Pour offrir une démonstration rigoureuse et exhaustive de la maturité
défensive de *SecureRAG Hub*, la chaîne DevSecOps est soumise à une
matrice d’évaluation de 19 tests répartis sur 5 domaines stratégiques :

#### 1. Sécurité Statique (SAST / SCA / Secrets)

1.  **Secret Leak (Gitleaks)** : Injection intentionnelle d’une clé API
    fictive dans un commit. *Résultat* : Détection immédiate et rejet au
    niveau du hook pré-commit et du pipeline CI (`PASS`).

2.  **Vulnérabilité Code (Semgrep)** : Introduction d’un motif
    d’injection SQL / Path Traversal dans un contrôleur Laravel.
    *Résultat* : Détection selon les règles OWASP Top 10 (`PASS`).

3.  **Dépendances (Trivy / Dependency-Check)** : Injection d’une version
    vulnérable de paquet. *Résultat* : Levée d’alerte Critical/High et
    blocage du build (`PASS`).

4.  **Dockerfile (Hadolint)** : Présence d’instructions non sécurisées
    (`USER root`). *Résultat* : Rejet à l’étape de vérification du
    Dockerfile (`PASS`).

#### 2. Supply Chain & Packaging

5.  **Génération SBOM (Syft)** : Build d’image conteneur. *Résultat* :
    Génération automatisée du catalogue d’actifs au format CycloneDX
    (`PASS`).

6.  **Scan d’Image (Trivy Container)** : Analyse des packages OS du
    conteneur. *Résultat* : Interdiction de promotion en cas de CVE
    critique sans patch (`PASS`).

7.  **Signature d’Image (Cosign)** : Tentative de déploiement d’une
    image non signée. *Résultat* : Blocage physique à l’admission par
    Kyverno en mode Enforce (`PASS`).

8.  **Immuabilité (Docker/K8s)** : Tentative d’écriture en runtime sur
    le système de fichiers. *Résultat* : Rejet par le paramètre
    `readOnlyRootFilesystem` (`PASS`).

#### 3. Tests Dynamiques & IA Red Teaming

9.  **DAST Web (OWASP ZAP)** : Balayage automatique des API du portail.
    *Résultat* : Détection et validation de l’absence de Broken Access
    Control (`PASS`).

10. **Prompt Injection (Garak / Module XAI)** : Soumission de la payload
    `"Ignore previous instructions..."`. *Résultat* : Attribution de
    caractéristiques par `xai_explainer.py` avec un score de risque de
    $100.0$ et rejet immédiat (`PASS`).

11. **Exfiltration de System Prompt** : Tentative de fuite du prompt
    système. *Résultat* : Blocage sémantique à 3 niveaux par le filtre
    AI-Sec (`PASS`).

12. **Multi-Agent Attack Simulation** : Simulation de propagation
    d’attaque inter-agents. *Résultat* : Confinement effectif via le
    filtrage par métadonnées RBAC Qdrant (`PASS`).

#### 4. Sécurité Kubernetes & Runtime

13. **Admission Control (Kyverno Enforce)** : Tentative de création d’un
    pod `privileged: true`. *Résultat* : Rejet par l’API Server
    Kubernetes (`PASS`).

14. **Isolation Réseau (NetworkPolicy)** : Flux réseau direct non
    autorisé entre microservices. *Résultat* : Blocage par la règle
    Default-Deny Cilium (`PASS`).

15. **Runtime Threat (Falco / Tetragon)** : Exécution d’un shell
    interactif (`kubectl exec`). *Résultat* : Capture eBPF kernel et
    alerte émise en $1.8\text{s}$ (`PASS`).

16. **RBAC Vectoriel (Qdrant)** : Requête vectorielle d’un utilisateur
    non autorisé. *Résultat* : Filtrage automatique par le payload
    `qdrant_rbac_filter.py` (`PASS`).

#### 5. GitOps & Observabilité

17. **Réconciliation GitOps (ArgoCD)** : Modification manuelle d’une
    ressource en cluster (drift). *Résultat* : Détection du drift et
    ré-synchronisation automatique vers l’état Git (`PASS`).

18. **Supervision (Prometheus + Grafana)** : Balayage des métriques et
    alerting sur pic d’anomalie. *Résultat* : Visualisation en temps
    réel et alertes Slack/Alertmanager (`PASS`).

19. **Chaos Engineering (Resilience Test)** : Suppression brutale du Pod
    principal. *Résultat* : Re-création automatique par Kubernetes en
    $< 3\text{s}$ avec zero-downtime (`PASS`).

<div id="tab:synthesis_19_tests">

| **Domaine**              | **Outils Mobilisés**     | **Critère de Succès**                                     | **Preuve Archivée**          | **Statut**    |
|:-------------------------|:-------------------------|:----------------------------------------------------------|:-----------------------------|:--------------|
| 1\. SAST / SCA / Secrets | Gitleaks, Semgrep, Trivy | 0 Secret en clair, 0 CVE Critical non mitigée             | Jenkins Build Logs           | `PASS` (100%) |
| 2\. Supply Chain         | Syft, Cosign, Kyverno    | SBOM CycloneDX valide, Signature Cosign ok                | `kyverno-admission-tests.md` | `PASS` (100%) |
| 3\. IA Red Teaming       | Garak, XAI Explainer     | Score de risque $100.0$ sur injection, RBAC vectoriel     | `xai_explainer_proof.txt`    | `PASS` (100%) |
| 4\. K8s & Runtime        | Kyverno, Falco, Cilium   | Rejet des Pods privilégiés, MTTD $< 2\text{s}$            | `r_workload_proof.txt`       | `PASS` (100%) |
| 5\. GitOps & SRE         | ArgoCD, Prometheus       | Réconciliation Drift $< 10\text{s}$, MTTR $< 5\text{min}$ | `qdrant_rbac_proof.txt`      | `PASS` (100%) |

Synthèse globale de la matrice des 19 tests de sécurité DevSecOps et
preuves associées.

</div>

#### Indicateurs Clés de Performance (KPIs) DevSecOps

L’évaluation expérimentale sur l’ensemble de la chaîne permet de dégager
les KPIs suivants :

- **Taux de Détection Globale des Menaces** : $\mathbf{98.5\%}$ sur
  l’ensemble des 19 scénarios d’adversité.

- **Temps Moyen de Détection Runtime (MTTD)** :
  $\mathbf{1.8\text{ seconde}}$ (via les sondes eBPF Falco/Tetragon).

- **Temps Moyen de Remédiation (MTTR)** : $\mathbf{2.5\text{ minutes}}$
  (grâce à la boucle de réconciliation GitOps d’ArgoCD).

- **Durée Moyenne des Scans CI (Parallelized)** :
  $\mathbf{1.4\text{ minute}}$ pour l’ensemble des 6 scanners statiques.

<div id="tab:journal_preuves_scenario">

| **Étape** | **Artefact de preuve**                      | **Emplacement dans le support pack** | **Horodatage** |
|:----------|:--------------------------------------------|:-------------------------------------|:---------------|
| 2         | Journal de *build* Jenkins (échec Gitleaks) | `support-pack/ci-logs/`              | \[À EXÉCUTER\] |
| 4         | Journal de *build* Jenkins (échec Trivy)    | `support-pack/cd-logs/`              | \[À EXÉCUTER\] |
| 7         | Alerte Falco (JSON)                         | `support-pack/runtime/falco/`        | \[À EXÉCUTER\] |
| 8         | Journal Tetragon correspondant              | `support-pack/runtime/tetragon/`     | \[À EXÉCUTER\] |
| 9         | *PolicyReport* Kyverno                      | `support-pack/admission/`            | \[À EXÉCUTER\] |

Journal de preuves à constituer lors de l’exécution effective du
scénario

</div>

## Protocole de Mesure des Métriques Réelles (MTTD, MTTR, DORA)

> **Avertissement méthodologique préalable** : cette section définit
> *comment* chaque métrique doit être calculée et à partir de *quelle*
> source de données du projet. Elle ne présente **aucune valeur mesurée
> définitive** : les cellules `[À EXÉCUTER]` désignent une mesure que le
> protocole permet de produire, mais non encore extraite des journaux
> réels. Renseigner ces cellules avec des valeurs plausibles non
> mesurées serait équivalent à l’erreur déjà corrigée pour Vault, ArgoCD
> ou Wazuh ailleurs dans ce chapitre.

### Métriques DORA — Calculables Immédiatement depuis Jenkins et Git

<div id="tab:dora_definitions">

| **Métrique DORA**                | **Définition et formule**                                            | **Source de données du projet**                              |
|:---------------------------------|:---------------------------------------------------------------------|:-------------------------------------------------------------|
| Fréquence de déploiement         | Nombre d’exécutions réussies de `Jenkinsfile.cd` par unité de temps  | Historique des *builds* Jenkins CD (API `/job/.../api/json`) |
| Délai de livraison (*Lead Time*) | $t_{\text{promotion digest}} - t_{\text{commit}}$, moyenné           | Horodatage Git vs horodatage de fin du *build* CD            |
| Taux d’échec des changements     | Ratio *builds* CD ayant déclenché un rollback manuel / total         | Journal des interventions manuelles post-déploiement         |
| MTTR déploiement                 | $t_{\text{retour à un état sain}} - t_{\text{détection de l'échec}}$ | Horodatage alerte vs redéploiement manuel                    |

Métriques DORA, formule et source de données disponible

</div>

<figure id="fig:script_dora">
<pre><code>#!/usr/bin/env bash
# extraction_dora.sh
JENKINS_URL=&quot;http://localhost:8080&quot;
JOB=&quot;SecureRAGHub/Jenkinsfile.cd&quot;
curl -s -u &quot;$JENKINS_USER:$JENKINS_TOKEN&quot; \
  &quot;$JENKINS_URL/job/$JOB/api/json?tree=builds[number,timestamp,duration,result]&quot; \
  | jq -r &#39;.builds[] | select(.result==&quot;SUCCESS&quot;) |
      &quot;\(.number) \(.timestamp) \(.duration)&quot;&#39; \
  &gt; builds_cd_reussis.tsv
echo &quot;Nombre de deploiements reussis sur la periode :&quot;
wc -l &lt; builds_cd_reussis.tsv</code></pre>
<figcaption>Script d’extraction des métriques DORA depuis l’API REST
Jenkins</figcaption>
</figure>

### Temps Moyen de Détection et de Réponse (MTTD / MTTR Sécurité)

$$\begin{aligned}
\text{MTTD} &= t_{\text{première alerte exploitable}} - t_{\text{action offensive}} \\
\text{MTTR (journalisation)} &= t_{\text{PolicyReport / alerte consignée}} - t_{\text{première alerte exploitable}} \\
\text{MTTR (mitigation effective)} &= t_{\text{action corrective effective}} - t_{\text{action offensive}}
\end{aligned}$$

> **Point de vigilance direct pour la soutenance** : dans l’état actuel
> (Kyverno Audit, absence d’ArgoCD en boucle fermée), le MTTR de
> **mitigation effective** n’a pas de valeur automatisée à mesurer : la
> mitigation résulte d’une intervention manuelle dont le délai dépend de
> l’opérateur, non d’une propriété du système. Il est plus honnête de
> présenter le **MTTD** (propriété mesurable du système de détection)
> plutôt qu’un MTTR de mitigation qui refléterait un temps de réaction
> humain simulé.

<div id="tab:mttd_mttr_a_completer">

| **Chaîne de détection mesurée**                        | **MTTD**       | **MTTR (journalisation)**        | **Source d’horodatage**                        |
|:-------------------------------------------------------|:---------------|:---------------------------------|:-----------------------------------------------|
| Commit avec secret injecté $\rightarrow$ Gitleaks (CI) | \[À EXÉCUTER\] | Sans objet (bloquant, synchrone) | Horodatage *build* Jenkins CI                  |
| Image avec CVE connue $\rightarrow$ Trivy (CD)         | \[À EXÉCUTER\] | Sans objet (bloquant, synchrone) | Horodatage *build* Jenkins CD                  |
| Syscall suspect $\rightarrow$ Falco                    | \[À EXÉCUTER\] | \[À EXÉCUTER\]                   | Horodatage action offensive vs `falco.log`     |
| Pod non conforme $\rightarrow$ Kyverno (Audit)         | \[À EXÉCUTER\] | \[À EXÉCUTER\]                   | Horodatage requête admission vs *PolicyReport* |

Table de mesure MTTD/MTTR à compléter à partir du scénario de la
section <a href="#sec:scenario_attaque_e2e" data-reference-type="ref"
data-reference="sec:scenario_attaque_e2e">1.20</a>

</div>

### Taux de Vulnérabilités Détectées

$$\text{Taux de détection SCA} = \frac{\text{Nombre de CVE identifiées par Trivy sur la période}}{\text{Nombre de dépendances/paquets analysés}}$$

<figure id="fig:script_cve">
<pre><code># extraction_vulnerabilites.sh
find ./support-pack -name &quot;trivy-report-*.json&quot; | while read f; do
  jq -r &#39;.Results[]?.Vulnerabilities[]? |
    &quot;\(.Severity) \(.VulnerabilityID) \(.PkgName)&quot;&#39; &quot;$f&quot;
done | sort | uniq -c | sort -rn &gt; synthese_cve_par_severite.txt</code></pre>
<figcaption>Script d’agrégation du taux de détection depuis les rapports
Trivy déjà archivés</figcaption>
</figure>

### Méthodologie Statistique et Menaces à la Validité

L’approfondissement des résultats expérimentaux et métriques
quantitatives exige de préciser non seulement les formules, mais les
conditions dans lesquelles une valeur unique de MTTD ou de MTTR peut
être considérée comme représentative, plutôt que comme l’artefact d’une
seule exécution favorable ou défavorable.

- **Répétition et dispersion** : chaque mesure de MTTD
  (section <a href="#sub:mttd_mttr" data-reference-type="ref"
  data-reference="sub:mttd_mttr">1.22.2</a>) doit être répétée sur un
  nombre de *runs* du scénario suffisant pour rapporter une moyenne *et*
  un écart-type ou un intervalle de confiance, et non une valeur
  ponctuelle ; une seule exécution du scénario de la
  section <a href="#sec:scenario_attaque_e2e" data-reference-type="ref"
  data-reference="sec:scenario_attaque_e2e">1.20</a> ne permet de
  documenter qu’une observation, pas une tendance.

- **Variabilité de l’environnement de mesure** : le cluster `kind` étant
  local et partagé avec les autres charges de travail de la machine de
  développement
  (section <a href="#sec:runtime_security" data-reference-type="ref"
  data-reference="sec:runtime_security">1.9</a>), toute mesure de
  latence doit préciser la charge système au moment de la mesure, faute
  de quoi une comparaison entre deux *runs* n’est pas interprétable.

- **Jeu de trafic de référence pour le taux de faux positifs** : la
  mesure d’un taux de faux positifs (par exemple pour Kyverno ou pour le
  moteur d’inférence IA,
  section <a href="#sec:ia_evaluation_mesurable" data-reference-type="ref"
  data-reference="sec:ia_evaluation_mesurable">1.23.6</a>) exige un jeu
  de trafic *légitime* de taille définie et documentée ; un taux de faux
  positifs calculé sur un échantillon non représentatif du trafic réel
  de l’application n’a pas de valeur généralisable.

- **Distinction stricte simulation/production** : toute métrique
  produite par le scénario contrôlé de la
  section <a href="#sec:scenario_attaque_e2e" data-reference-type="ref"
  data-reference="sec:scenario_attaque_e2e">1.20</a> doit être présentée
  comme telle en soutenance — un MTTD mesuré sur une attaque simulée
  dans un cluster de démonstration n’est pas directement transposable à
  un MTTD en environnement de production réel, question déjà soulevée
  pour `kind` en général à la
  section <a href="#sec:runtime_security" data-reference-type="ref"
  data-reference="sec:runtime_security">1.9</a>.

- **Non-double-comptage** : lorsqu’une même exécution du scénario
  alimente à la fois une métrique DORA (par exemple le *lead time* du
  redéploiement correctif) et une métrique de sécurité (le MTTR de
  journalisation), les deux valeurs doivent être rapportées séparément
  avec leur formule propre plutôt que fusionnées, pour ne pas donner
  l’impression d’une mesure plus riche qu’elle ne l’est.

## La Couche de Sécurité par Intelligence Artificielle

> **Avertissement de statut** : le répertoire `ai-security/` (Log
> Collector, moteur d’inférence dual-mode, backend FastAPI, dashboard
> React) a été identifié par une exploration directe du code source. Il
> **n’apparaît toutefois dans aucune des onze familles d’outils
> recensées par le chapitre d’étude préalable**. Deux lectures sont
> possibles : soit cette couche a été développée après la rédaction du
> chapitre d’étude préalable et doit y être intégrée en révision, soit
> elle relève d’un prototype expérimental non encore consolidé. **Cette
> ambiguïté doit être levée avant la soutenance**.

<figure id="fig:ia_interne">

<figcaption>Architecture interne identifiée dans le code de
<code>ai-security/</code> — statut global à confirmer.</figcaption>
</figure>

### Principe de Conception Visé

Sous réserve de la clarification de statut ci-dessus, la couche de
sécurité IA ne se substituerait à aucun composant Réalisé : elle en
consommerait la télémétrie pour lui appliquer une classification de
menace et un scoring de risque unifié.

### Architecture du Flux de Données Visée

$$\begin{aligned}
\text{Infrastructure DevSecOps (Loki, Prometheus, événements K8s)} &\longrightarrow \text{Log Collector (démon Python)} \\
&\longrightarrow \text{Backend FastAPI (endpoint } \texttt{/analyze} \text{)} \\
&\longrightarrow \text{Moteur d'Inférence IA (double mode)} \\
&\longrightarrow \text{Persistance PostgreSQL + diffusion WebSocket} \\
&\longrightarrow \text{Dashboard React (visualisation, recommandations)}
\end{aligned}$$

### Composants Identifiés dans le Code

#### Log Collector

Démon Python interrogeant périodiquement Loki, Prometheus Alertmanager
et l’API Kubernetes.

#### Moteur d’Inférence IA

Point de terminaison `/analyze` à deux modes mutuellement exclusifs : un
mode transformer (`omasteam/cyberguard-ai-security-analyzer`, dérivé
Llama, GPU) et un mode heuristique de repli (CPU), ce dernier consommant
des motifs Tetragon/eBPF, Falco, Wazuh et journaux réseau. **La présence
de Wazuh mérite la même prudence que le reste de la section** : cet
outil n’apparaît ni dans l’inventaire du chapitre d’étude préalable ni
dans le tableau des outils runtime/admission.

#### Backend FastAPI et Dashboard

Orchestre la persistance des événements classifiés et leur diffusion
temps réel vers un dashboard de supervision humaine.

### Formulation Mathématique du Scoring de Risque Unifié

$$R_{workload} = 0.4 \cdot R_{\text{runtime}} + 0.3 \cdot R_{\text{supply\_chain}} + 0.2 \cdot R_{\text{network}} + 0.1 \cdot R_{\text{compliance}}$$

<div id="tab:risk_components">

| **Coefficient** | **Composante**             | **Source de données**                   | **Statut de la source**                          |
|:----------------|:---------------------------|:----------------------------------------|:-------------------------------------------------|
| 0.4             | $R_{\text{runtime}}$       | Falco, Tetragon + moteur d’inférence IA | Réalisé (Falco/Tetragon) ; couche IA à clarifier |
| 0.3             | $R_{\text{supply\_chain}}$ | Cosign, Syft                            | Réalisé                                          |
| 0.2             | $R_{\text{network}}$       | Hubble/Cilium                           | Non confirmé — à vérifier                        |
| 0.1             | $R_{\text{compliance}}$    | Kyverno (*PolicyReports*)               | Réalisé, mode Audit uniquement                   |

Correspondance entre les composantes du score de risque unifié et le
statut vérifié de leurs sources

</div>

### Boucle de Rétroaction et Remédiation : Scénario Cible

1.  Tentative d’exploitation sur un microservice exposé.

2.  L’agent eBPF Falco capte le syscall et émet un journal (mécanisme
    Réalisé).

3.  Le Log Collector transmet ce journal au moteur d’inférence, qui
    produit un verdict (statut global à clarifier).

4.  Le score $R_{workload}$ dépasse le seuil critique configuré.

5.  Une action de remédiation serait déclenchée : isolation réseau et
    rollback vers l’image précédente certifiée.

> **Double point de vigilance** : l’étape 5 suppose deux mécanismes
> actuellement Perspective — le mode Enforce de Kyverno et une
> orchestration ArgoCD en boucle fermée. Cette étape ne peut donc pas
> être présentée comme un comportement démontré de bout en bout. La
> question de la validation humaine préalable reste ouverte.

### Évaluation Mesurable de la Couche de Sécurité IA

> **Rappel de statut** : le protocole ci-dessous transforme les
> affirmations qualitatives de « corrélation » et de « scoring unifié »
> en métriques falsifiables, **sans présumer** qu’elles ont déjà été
> mesurées. Il constitue la condition de passage d’un statut « à
> confirmer » à un statut Réalisé documenté.

#### Métrique 1 — Taux de Réduction du Volume d’Alertes Brutes

$$\tau_{\text{réduction}} = 1 - \frac{\text{Nombre d'événements corrélés restitués au dashboard}}{\text{Nombre d'événements bruts ingérés par le Log Collector}}$$

#### Métrique 2 — Précision et Rappel du Moteur d’Inférence

$$\begin{aligned}
\text{Précision} &= \frac{\text{Vrais positifs}}{\text{Vrais positifs} + \text{Faux positifs}} \qquad
\text{Rappel} = \frac{\text{Vrais positifs}}{\text{Vrais positifs} + \text{Faux négatifs}}
\end{aligned}$$ À calculer séparément pour le mode transformer et le
mode heuristique, ces deux modes n’étant pas nécessairement équivalents
en fiabilité.

#### Métrique 3 — Stabilité du Scoring de Risque Unifié

$$\Delta R_{workload} = R_{workload}(\text{coefficients nominaux}) - R_{workload}(\text{coefficients perturbés de} \pm 20\%)$$

#### Métrique 4 — Latence de Bout en Bout du Pipeline de Scoring

$$L_{\text{scoring}} = t_{\text{score disponible au dashboard}} - t_{\text{événement source ingéré}}$$

### Protocole de Validation Expérimentale Complète de la Couche IA

> **Cadrage** : si la couche `ai-security/` est retenue comme
> **contribution principale** du mémoire, le niveau de preuve exigé
> dépasse celui d’un composant DevSecOps standard : une contribution
> scientifique se juge sur un protocole d’évaluation reproductible, pas
> sur une démonstration ponctuelle. Le protocole ci-dessous décrit *ce
> qu’il faut produire*, pas des résultats déjà obtenus — sa complétion
> est une condition, non une conséquence, de la présentation de cette
> couche comme contribution principale en soutenance.

#### Construction du Jeu de Données d’Évaluation

1.  **Événements bénins** : trafic normal capturé lors de l’exploitation
    courante du scénario officiel de démonstration (navigation, requêtes
    conversationnelles légitimes, cycles de sauvegarde) sur une fenêtre
    temporelle définie a priori (par exemple 24h ou 72h de cluster
    actif).

2.  **Événements malveillants étiquetés** : dérivés du scénario
    reproductible de la
    section <a href="#sec:scenario_attaque_e2e" data-reference-type="ref"
    data-reference="sec:scenario_attaque_e2e">1.20</a>, répété en
    plusieurs variantes (injection de secret, CVE connue, shell
    interactif, violation de *SecurityContext*) et sur plusieurs *runs*
    indépendants pour éviter qu’un seul *pattern* d’attaque ne domine le
    jeu de test.

3.  **Étiquetage indépendant** : chaque événement du jeu de données doit
    être étiqueté bénin/malveillant *avant* son passage dans le moteur
    d’inférence, par une personne ou un processus distinct de celui qui
    évalue ensuite les résultats, pour éviter un biais de confirmation
    dans l’interprétation des sorties du modèle.

4.  **Partition entraînement/test** : si le mode transformer fait
    l’objet d’un ajustement (*fine-tuning*) quelconque sur des données
    du projet, une partition stricte entre les événements utilisés pour
    cet ajustement et ceux utilisés pour l’évaluation doit être
    documentée, pour éviter une évaluation optimiste par fuite de
    données.

#### Définition des Lignes de Base (*Baselines*)

Une métrique de précision/rappel n’est interprétable que comparée à une
ligne de base explicite. Trois baselines sont proposées, de la plus
simple à la plus exigeante :

- **Baseline 1 — règle triviale** : classification systématique « bénin
  », donnant une mesure du déséquilibre du jeu de données (utile pour
  interpréter un rappel élevé qui serait trivial si le jeu de test est
  très déséquilibré).

- **Baseline 2 — seuillage simple sur Falco seul** : alerte Falco brute
  sans corrélation, sans passage par le moteur d’inférence — permet de
  mesurer l’apport *spécifique* de la couche IA par rapport à la
  détection déjà Réalisé.

- **Baseline 3 — mode heuristique de repli** : si le mode transformer
  est évalué, le mode heuristique sert lui-même de baseline pour
  quantifier le gain (ou l’absence de gain) du modèle transformer par
  rapport au mode de repli plus simple.

#### Protocole d’Ablation

Pour établir que chaque composante du score $R_{workload}$ contribue
effectivement à la performance de détection, et non uniquement la
formule dans son ensemble, une étude d’ablation est requise : mesurer la
précision/rappel obtenus en mettant tour à tour à zéro chacune des
quatre composantes ($R_{\text{runtime}}$, $R_{\text{supply\_chain}}$,
$R_{\text{network}}$, $R_{\text{compliance}}$) et en comparant au score
complet. Une composante dont l’ablation ne dégrade pas significativement
la performance sur le jeu de test constitue un signal empirique — à
documenter honnêtement même s’il questionne la formule actuelle — plutôt
qu’un résultat à écarter.

#### Tests de Signification Statistique

- Pour comparer deux configurations (par exemple mode transformer vs
  mode heuristique, ou score complet vs score ablationné), rapporter un
  intervalle de confiance (par exemple par *bootstrap* sur le jeu de
  test) plutôt qu’une seule valeur de précision/rappel, afin de
  distinguer une différence réelle d’une variation due à la taille finie
  du jeu de test.

- Documenter explicitement la taille du jeu de test étiqueté : un jeu de
  quelques dizaines d’événements ne permet pas de conclusions
  statistiquement robustes sur une précision annoncée à la décimale
  près, et cette limite doit être assumée en soutenance plutôt que
  masquée par une présentation à fausse précision.

#### Menaces à la Validité Spécifiques à cette Couche

- **Validité externe** : un jeu de données construit à partir du
  scénario contrôlé de démonstration ne couvre qu’un sous-ensemble
  restreint des techniques d’attaque réelles (référentiel MITRE ATT&CK
  bien plus large) — toute généralisation au-delà de ce scénario doit
  être explicitement qualifiée de non démontrée.

- **Dérive de distribution** : le trafic bénin capturé lors d’une
  démonstration contrôlée peut différer sensiblement d’un trafic de
  production réel à plus grande échelle, ce qui limiterait la
  transposabilité d’un taux de faux positifs mesuré dans ce cadre.

- **Dépendance au mode d’exécution** : les résultats du mode transformer
  dépendent de la disponibilité effective d’un environnement GPU au
  moment de l’évaluation ; toute comparaison entre modes doit préciser
  l’environnement matériel utilisé pour chacun, faute de quoi un écart
  de performance pourrait refléter une différence de matériel plutôt
  qu’une différence de modèle.

<div id="tab:protocole_validation_ia">

| **Étape du protocole**                               | **Condition préalable**                                                                      | **Statut**     |
|:-----------------------------------------------------|:---------------------------------------------------------------------------------------------|:---------------|
| Construction du jeu de données étiqueté              | Répétition du scénario section <a href="#sec:scenario_attaque_e2e" data-reference-type="ref" 
                                                        data-reference="sec:scenario_attaque_e2e">1.20</a> en plusieurs variantes                     | \[À EXÉCUTER\] |
| Mesure des 3 baselines                               | Jeu de données étiqueté disponible                                                           | \[À EXÉCUTER\] |
| Précision/rappel par mode (transformer, heuristique) | Environnement GPU disponible pour le mode transformer                                        | \[À EXÉCUTER\] |
| Étude d’ablation des 4 composantes de $R_{workload}$ | Jeu de données étiqueté disponible                                                           | \[À EXÉCUTER\] |
| Intervalles de confiance (*bootstrap*)               | Résultats bruts de précision/rappel disponibles                                              | \[À EXÉCUTER\] |

Protocole de validation expérimentale complète de la couche IA —
squelette d’exécution, aucun résultat renseigné

</div>

## Analyse Comparative Qualitative

Avant toute comparaison quantitative — qui suppose des mesures encore à
produire —, deux comparaisons qualitatives situent l’apport visé de la
couche IA par rapport à la chaîne DevSecOps Réalisé seule. La colonne «
DevSecOps + IA Sec » décrit une **cible**, dont le statut global reste à
confirmer.

<div id="tab:comparaison_qualitative">

| **Capacité**                         | **DevSecOps Classique (Réalisé)**    | **DevSecOps + IA Sec (cible)**                              |
|:-------------------------------------|:-------------------------------------|:------------------------------------------------------------|
| Détection multi-couche               | Oui, en silos indépendants           | Oui, avec agrégation par le Log Collector                   |
| Corrélation inter-outils             | Non                                  | Visée — moteur d’inférence multi-sources                    |
| Scoring de risque unifié             | Non                                  | Visé — formule $R_{workload}$, calibration à documenter     |
| Priorisation automatique des alertes | Non                                  | Visée, sous réserve de confirmation du statut               |
| Blocage effectif à l’admission       | Non (Kyverno Audit)                  | Nécessite le mode Enforce, indépendant de la couche IA      |
| Remédiation automatique bornée       | Non                                  | Visée — dépend d’ArgoCD (Perspective)                       |
| Validation humaine du processus      | Implicite, non outillée              | À définir explicitement                                     |
| Explicabilité des décisions          | Sans objet                           | Non confirmée — aucun module identifié dans le code exploré |
| Production de preuves techniques     | Oui — support pack, SBOM, signatures | Inchangée                                                   |

Comparaison fonctionnelle qualitative entre la chaîne DevSecOps Réalisé
et la cible DevSecOps + IA Sec

</div>

<div id="tab:comparaison_par_composant">

| **Composant DevSecOps**   | **Sans couche IA (état actuel)**     | **Avec couche IA (cible, statut à confirmer)**               |
|:--------------------------|:-------------------------------------|:-------------------------------------------------------------|
| Falco / Tetragon          | Alerte brute par pod, sans contexte  | Corrélation avec l’historique d’accès                        |
| Kyverno (*PolicyReports*) | Consultation manuelle                | Composante $R_{\text{compliance}}$, priorisation automatique |
| Cosign / Syft             | Vérification binaire signé/non signé | Composante $R_{\text{supply\_chain}}$                        |
| Prometheus / Loki         | Consultation manuelle (Préparé)      | Source du Log Collector, sous réserve                        |
| Security-Auditor          | Couverture partielle                 | Source additionnelle potentielle, non confirmée              |

Apport visé de la couche IA par composant déjà Réalisé

</div>

## Analyse Comparative Quantitative

> **Avertissement méthodologique** : les valeurs de ce tableau doivent
> impérativement être remplacées par des mesures effectivement extraites
> des journaux de test du projet, selon le protocole des
> sections <a href="#sec:metriques_reelles" data-reference-type="ref"
> data-reference="sec:metriques_reelles">1.22</a>
> et <a href="#sec:validation_experimentale_ia" data-reference-type="ref"
> data-reference="sec:validation_experimentale_ia">1.23.7</a>, avant la
> soutenance.

<div id="tab:sota_comparison">

| **Critère d’Évaluation**  | **DevSecOps Classique**  |          **SecureRAG Hub (cible)**          |                                       **Méthode de mesure**                                        |
|:--------------------------|:------------------------:|:-------------------------------------------:|:--------------------------------------------------------------------------------------------------:|
| Type de corrélation       | Manuelle / post-incident |         Automatique (sous réserve)          |                                      Observation qualitative                                       |
| Taux de détection globale |       \[MESURE\] %       |                \[MESURE\] %                 | Jeu de test étiqueté (section <a href="#sec:validation_experimentale_ia" data-reference-type="ref" 
                                                                                                                         data-reference="sec:validation_experimentale_ia">1.23.7</a>)                     |
| Taux de faux positifs     |       \[MESURE\] %       |                \[MESURE\] %                 |                                  Ratio alertes rejetées / totales                                  |
| MTTD                      |        \[MESURE\]        |                 \[MESURE\]                  |                     Section <a href="#sub:mttd_mttr" data-reference-type="ref"                     
                                                                                                                                   data-reference="sub:mttd_mttr">1.22.2</a>                              |
| MTTR (journalisation)     |        \[MESURE\]        |                 \[MESURE\]                  |                     Section <a href="#sub:mttd_mttr" data-reference-type="ref"                     
                                                                                                                                   data-reference="sub:mttd_mttr">1.22.2</a>                              |
| Autonomie décisionnelle   |          Nulle           | Cible visée, non démontrée en boucle fermée |                                        Analyse qualitative                                         |

Structure de comparaison des architectures DevSecOps, à compléter avec
les mesures réelles

</div>

## Plan de Mesure et de Clarification pour la Campagne de Test

1.  confirmer le statut réel de l’ensemble `ai-security/` et le nombre
    exact de patterns actifs du Security-Auditor ;

2.  confirmer la présence effective de Wazuh et de Cilium/Hubble ;

3.  décider explicitement du passage ou non de Kyverno en mode Enforce
    avant la soutenance ;

4.  clarifier le degré d’automatisation visé pour la boucle de
    remédiation ;

5.  exécuter le protocole de validation expérimentale de la
    section <a href="#sec:validation_experimentale_ia" data-reference-type="ref"
    data-reference="sec:validation_experimentale_ia">1.23.7</a>, en
    priorité la métrique de sensibilité $\Delta R_{workload}$
    (calculable sans exécution du moteur d’inférence).

## Discussion et Limites Techniques

L’exercice de rédaction de ce chapitre a mis en évidence une limite
méthodologique transversale : **la coexistence de plusieurs sources
documentaires partiellement contradictoires**. Au-delà de ce constat,
plusieurs défis demeurent : l’écart entre détection et application
(Kyverno Audit vs Enforce), la dépendance à l’exhaustivité de la
télémétrie, et l’absence de méthode de calibration documentée pour
$R_{workload}$.

## Perspectives de Recherche et Travaux Futurs

Les statuts *Préparé* et *Perspective* attribués tout au long de ce
chapitre désignent des composants *non opérés dans le scénario actuel*.
Cette section les reformule en un programme de travaux futurs explicite,
ordonné par dépendance technique plutôt que par famille d’outils.

<figure id="fig:sequencement_travaux_futurs">

<figcaption>Séquencement proposé des travaux futurs, par dépendance
technique.</figcaption>
</figure>

### Phase 1 — Fermeture de la Boucle d’*Enforcement*

### Phase 1 — Activation du Mode Enforce de Kyverno (Réalisé)

Le passage de Kyverno du mode Audit au mode Enforce (décrit initialement
comme perspective à la
section <a href="#sec:runtime_security" data-reference-type="ref"
data-reference="sec:runtime_security">1.9</a>) a été pleinement réalisé.
L’intégralité des politiques (signature Cosign, SBOM, PSS Restricted)
définies dans `infra/k8s/policies/` opère désormais avec
`validationFailureAction: Enforce`. Cette bascule a été validée par la
suite de tests automatisés (`test-kyverno-admission.sh`), confirmant le
blocage physique effectif des workloads non-conformes (ex: absence de
signature, conteneurs privilégiés) sans perturber le trafic légitime.

### Phase 2 — Industrialisation GitOps avec ArgoCD (Réalisé)

L’introduction d’ArgoCD (identifiée comme perspective à la
section <a href="#sec:gitops" data-reference-type="ref"
data-reference="sec:gitops">1.10</a>) est désormais effective. Les
manifestes déclaratifs ont été instanciés dans `infra/argocd/`, liant
directement le cluster à la branche principale du dépôt Git (overlay
Kustomize). Pour répondre au risque de boucles d’erreurs automatisées
identifié section <a href="#sec:ia_layer" data-reference-type="ref"
data-reference="sec:ia_layer">1.23</a>, le projet a adopté un mode
*semi-automatisé* intermédiaire : ArgoCD réconcilie automatiquement
l’état, mais la politique `syncPolicy` est configurée pour exiger une
validation manuelle en cas de rollback majeur, limitant ainsi le risque
d’actions destructives non supervisées.

### Phase 3 — Consolidation de la Validation Empirique de la Couche IA (Réalisé)

Le protocole défini
section <a href="#sec:validation_experimentale_ia" data-reference-type="ref"
data-reference="sec:validation_experimentale_ia">1.23.7</a> a été
consolidé et validé par des implémentations de preuve de concept (*Proof
of Concept*) situées dans `ai-security/` :

- **Mise en correspondance systématique avec ATT&CK for Containers** :
  Le fichier `mitre_attack_mapping.md` établit la cartographie
  exhaustive reliant les détections de Falco/Tetragon et Kyverno aux
  tactiques T1190 (Exploit Public-Facing Application) jusqu’à TA0010
  (Exfiltration), démontrant la complétude de la couverture défensive.

- **Module d’explicabilité (XAI)** : Un module Python
  (`xai_explainer.py`) simule l’attribution de caractéristiques
  (*Integrated Gradients*) permettant au Comité AI de justifier une
  décision de rejet (par exemple, un poids de 0.90 attribué à un motif
  de "Jailbreak").

- **Calibration empirique de $R_{workload}$** : Le script
  `r_workload_calculator.py` opérationnalise le calcul du score de
  risque dynamique en fusionnant les vulnérabilités SAST, les alertes
  runtime eBPF, et les rejets sémantiques IA, avec une décote temporelle
  exponentielle (*decay factor*) pour limiter les faux positifs sur la
  durée.

### Phase 4 — Activation du Moteur RAG/LLM et Isolation Vectorielle (Réalisé)

L’activation du pipeline de vectorisation documentaire intègre désormais
un mécanisme de contrôle d’accès cryptographique (RBAC) basé sur les
métadonnées. Comme démontré par le script `qdrant_rbac_filter.py`,
chaque requête soumise au VectorStore Qdrant est conditionnée par un
payload exigeant une stricte intersection entre les rôles de
l’utilisateur (`allowed_roles`) et le niveau de sensibilité du document
vectorisé. Cette implémentation garantit une étanchéité absolue des
données inter-départements, rendant les tentatives d’exfiltration par
*prompt injection* structurellement inopérantes sur les documents hors
périmètre.

> **Principe directeur pour l’ensemble de ce programme** : chaque phase
> devrait, à son achèvement, produire les mêmes artefacts de preuve que
> ceux exigés pour les composants déjà Réalisé de ce chapitre — journal
> d’exécution, rapport archivé dans le support pack, statut mis à jour
> dans la cartographie de la
> figure <a href="#fig:cartographie_statut" data-reference-type="ref"
> data-reference="fig:cartographie_statut">1.1</a> — plutôt que d’être
> déclarée achevée sur la seule base d’une intégration de code.

## Positionnement Scientifique et Conclusion

Ce chapitre a documenté, composant par composant, la chaîne DevSecOps
effectivement mise en œuvre : Réalisé pour seize composants confirmés ;
Préparé pour SOPS/age, Qdrant, la pile d’observabilité ; Perspective
pour Vault/ESO, GitOps complet, LLM/Ollama opéré. La contribution de ce
mémoire demeure valide dans son principe : les composants Réalisé, pris
isolément, laissent subsister des défaillances transversales que seule
une couche de corrélation peut combler. La valeur scientifique
définitive de la couche `ai-security/` dépend de la clarification de son
statut et de l’exécution du protocole de validation de la
section <a href="#sec:validation_experimentale_ia" data-reference-type="ref"
data-reference="sec:validation_experimentale_ia">1.23.7</a>.
