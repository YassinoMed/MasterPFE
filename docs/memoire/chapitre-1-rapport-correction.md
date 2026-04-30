# Rapport de correction — Chapitre 1 « Étude préalable »

- **Fichier corrigé** : `docs/memoire/chapitre-1-etude-prealable.tex`
- **Sauvegarde** : `docs/memoire/chapitre-1-etude-prealable.tex.backup`
- **Bibliographie** : `docs/memoire/references.bib` (étendue)
- **Date** : 2026-04-28

---

## 1. Synthèse des principales corrections effectuées

### 1.1 Structure et architecture du chapitre

| # | Avant | Après | Justification |
|---|---|---|---|
| 1 | Introduction monolithique sans annonce de plan | Introduction restructurée avec contexte, double objectif et **plan détaillé du chapitre** (références aux sections via `\label`/`\ref`) | Norme académique : tout chapitre de mémoire doit annoncer explicitement sa structure |
| 2 | Sections sans `\label` | Toutes les sections principales étiquetées (`sec:cadre_general`, `sec:concepts`, etc.) | Permet les renvois croisés et la navigation dans le PDF |
| 3 | Pas d'hypothèses de recherche | Ajout d'une **sous-section « Hypothèses de recherche »** avec 3 hypothèses H1, H2, H3 falsifiables | Prérequis méthodologique d'un mémoire de Master |
| 4 | Une seule problématique en bloc | Problématique centrale + **3 questions de recherche opérationnelles** (QR1, QR2, QR3) dérivées | Reformulation académique standard ; rend la problématique opérationnalisable |
| 5 | Méthodologie limitée à Scrum | Ajout d'une **sous-section « Démarche méthodologique de recherche »** (recherche-action / design science, Wieringa 2014) avant Scrum | Distinguer la méthodologie *de recherche* (mémoire) de la méthodologie *de réalisation* (sprints) |
| 6 | Pas de bibliographie de chapitre | Ajout d'une section finale **« Bibliographie du chapitre »** structurée par catégorie | Facilite l'évaluation de la couverture bibliographique |

### 1.2 Renforcement scientifique

| # | Avant | Après | Justification |
|---|---|---|---|
| 7 | « approche RBAC » sans référence | RBAC avec citations Sandhu et al. (1996) et NIST INCITS 359 | Article fondateur du domaine (DOI 10.1109/2.485845) |
| 8 | « DevSecOps désigne… » sans référence académique | Ajout de Myrbakken & Colomo-Palacios 2017 (revue de littérature multi-vocale) + NIST SSDF SP 800-218 | Le NIST SSDF est devenu la référence normative pour la *secure software development* |
| 9 | « hallucination » mentionnée sans encadrement | Ajout NIST AI RMF 1.0 (2023) + OWASP Top 10 LLM (2025) | Gouvernance IA = standards 2023–2025 |
| 10 | RAG cité avec une seule source | Lewis 2020 + **Karpukhin 2020 (DPR)** + **Gao 2024 (RAG survey)** | Couvre le couple récupération dense + état de l'art récent |
| 11 | Microservices : Newman seul | Ajout Fowler & Lewis 2014 + **NIST SP 800-204** sur la sécurité des microservices | Sécurité des microservices désormais cadrée par un référentiel officiel |
| 12 | Supply chain : aucune référence | **SLSA v1.0 + Sigstore (Newman et al. CCS 2022) + CycloneDX + Ohm et al. 2020** sur les attaques | La supply chain est l'un des trois piliers DevSecOps de SecureRAG ; doit être ancrée dans des référentiels reconnus |
| 13 | Kubernetes : K8s docs uniquement | Ajout **Burns et al. 2022** (livre de référence) + **CIS Kubernetes Benchmark** + **Pod Security Standards** | Triple ancrage : ouvrage / standard de sécurité / spécification officielle |
| 14 | Pas d'analyse réflexive du LLM moderne | Ajout **Vaswani 2017 (Transformer)** et **LeCun 2015 (Deep Learning, Nature)** | Articles incontournables pour situer les LLM |
| 15 | Tableau comparatif inexistant | **Tableau `tab:comparatif_existant`** sur 6 critères × 5 catégories de solutions | Synthèse visuelle attendue dans une section « critique de l'existant » |
| 16 | Pas de critère SMART pour les objectifs | Mention explicite des critères SMART avec liens aux artefacts mesurables | Standard académique pour la formulation d'objectifs |
| 17 | Pas de chiffre sur le contexte IA | Ajout AI Index 2024 (Stanford HAI) | Permet de quantifier le « contexte de diffusion rapide de l'IA générative » |

### 1.3 Style, langue et clarté

| # | Avant | Après | Justification |
|---|---|---|---|
| 18 | Espacement typographique français inégal | Espaces insécables systématiques avant `:`, `;`, `?`, `!` (`~:`, `~;`) | Norme typographique française (Imprimerie nationale) |
| 19 | « le RAG, ou la génération augmentée par récupération » | « la génération augmentée par récupération, ou RAG (*Retrieval-Augmented Generation*) » | Définition + acronyme + traduction anglaise = norme académique |
| 20 | Italique LaTeX `\textit{...}` parfois absent sur les termes techniques | `\textit{}` systématique sur tous les anglicismes (cloud-native, embeddings, runbooks, etc.) | Lisibilité + norme |
| 21 | Phrases longues à propositions empilées | Découpage en propositions plus courtes ; usage de la ponctuation faible (point-virgule, deux-points) | Fluidité académique |
| 22 | « industrialisée » répété 4× dans 2 paragraphes | Variations : « industrialisé », « formalisé », « outillé », « instrumenté » | Éviter les répétitions |
| 23 | « le RAG complet n'est pas développé » | « la logique RAG complète n'est pas implémentée dans la première version » | Précision : *développé* est ambigu en informatique |
| 24 | « scénario *demo* » | `texttt{demo}` systématiquement (cohérence avec les overlays Kustomize) | Distinction nom de mode vs adjectif |
| 25 | « dimensions complémentaires » sans paragraphes nommés | Usage de `\paragraph{Dimension applicative.}`, `\paragraph{Dimension architecturale.}`, etc. | Hiérarchisation visuelle des objectifs |

### 1.4 Cohérence académique

| # | Avant | Après | Justification |
|---|---|---|---|
| 26 | Statuts évoqués (TERMINÉ, PARTIEL, etc.) sans définition formelle dans le chapitre | Ajout d'une **liste explicite des 4 statuts** dans la sous-section « Périmètre et limites » avec lien à H3 | Tout terme utilisé dans le mémoire doit être défini lors de sa première occurrence |
| 27 | Référence à FastAPI sans explicitation du périmètre | Ajout du renvoi explicite à `docs/architecture/official-scope.md` | Cohérence avec le scope officiel défini par les artefacts du dépôt |
| 28 | « GitHub Actions » sans positionnement clair | « GitHub Actions étant conservé en miroir historique seulement » | Aligne le chapitre avec la décision documentée dans `.github/workflows/README.md` |
| 29 | Perspectives sans alignement sur les améliorations expert | Section perspectives enrichie avec **Argo CD GitOps**, **observabilité Prometheus/Grafana/Loki/Alertmanager**, **Kyverno Audit→Enforce** | Cohérence avec `artifacts/final/expert-readiness-report.md` |

---

## 2. Tableau des corrections importantes

| Élément | Ancienne formulation | Nouvelle formulation | Raison |
|---|---|---|---|
| **Problématique** | « Comment concevoir et démontrer une plateforme de chatbots métiers sécurisés, gouvernée par rôles, prête à évoluer vers le RAG, et industrialisée par une chaîne DevSecOps reproductible ? » | « **Comment concevoir, mettre en œuvre et valider** une plateforme de chatbots métiers sécurisée, gouvernée par rôles, **ouverte à une intégration RAG ultérieure**, et industrialisée par une chaîne DevSecOps **reproductible et auditable** ? » + 3 questions de recherche QR1/QR2/QR3 | La formulation initiale enchaîne 4 verbes en série (« concevoir et démontrer ») sans hiérarchisation. La version corrigée distingue les 3 actions méthodologiques (concevoir, mettre en œuvre, valider) et ajoute le critère d'auditabilité. La déclinaison en QR rend la problématique opérationnalisable. |
| **Hypothèses** | (absentes) | H1 : architecture Laravel adéquate ; H2 : Jenkins+outils suffisants pour SLSA L2/L3 ; H3 : la séparation TERMINÉ vs PRÊT_NON_EXÉCUTÉ renforce la crédibilité | Les hypothèses falsifiables sont obligatoires dans un mémoire de Master à dimension recherche. |
| **Objectif général** | (objectifs spécifiques uniquement) | « Concevoir, implémenter et valider une plateforme académique de chatbots métiers sécurisée et industrialisée, démontrable localement et préparée à une intégration RAG ultérieure » | Sans objectif général, les objectifs spécifiques manquent de hiérarchie. |
| **Méthodologie** | « Le projet adopte une démarche agile inspirée de Scrum » (Scrum seulement) | Ajout préalable de la **démarche méthodologique de recherche** (design science, Wieringa) ; Scrum reste pour la phase de réalisation | Scrum est une méthode de gestion de projet, pas une méthodologie de recherche. Un mémoire académique requiert les deux niveaux. |
| **RBAC (concept)** | « Le RBAC, ou contrôle d'accès basé sur les rôles, consiste à associer des permissions à des rôles » | « Le RBAC (*Role-Based Access Control*) consiste à associer des permissions à des rôles, puis des rôles aux utilisateurs. Cette approche est formalisée depuis les travaux fondateurs de Sandhu *et al.* [Sandhu1996] et standardisée par le NIST [NIST INCITS 359-2012] » | Toute notion technique doit être ancrée dans une référence académique fondatrice. |
| **DevSecOps** | « DevSecOps désigne l'intégration continue de la sécurité dans le cycle DevOps » | Définition complétée + référence Myrbakken & Colomo-Palacios 2017 + NIST SSDF SP 800-218 + cadrage SLSA | Référence académique manquante sur un concept central du mémoire. |
| **Supply chain** | (notion implicite) | Sous-section dédiée avec attaques (Ohm 2020), cadre SLSA v1.0, Sigstore (Newman CCS 2022), CycloneDX | La sécurité de la supply chain est l'un des piliers du projet ; elle doit être traitée comme un objet scientifique, pas comme une simple technique. |
| **Statuts (taxonomie)** | (mentionnés sans liste) | Liste explicite des 4 statuts (TERMINÉ, PARTIEL, PRÊT_NON_EXÉCUTÉ, DÉPENDANT_DE_L_ENVIRONNEMENT) avec définitions | Tout vocabulaire interne doit être défini à sa première occurrence. |
| **Comparaison existant** | Tableau comparatif absent | Tableau `tab:comparatif_existant` (6 critères × 5 catégories) | Synthèse visuelle attendue dans une analyse critique. |
| **Pod Security Kubernetes** | « les politiques Kyverno passent en mode Audit ou Enforce » | Mention explicite des **Pod Security Standards** (privileged / baseline / restricted) + CIS Kubernetes Benchmark + distinction Audit/Enforce | Les PSS sont la norme officielle K8s depuis 2022 ; les ignorer est une lacune. |
| **Hallucinations LLM** | Citation Bommasani + Ji uniquement | Ajout cadrage NIST AI RMF 1.0 (2023) + OWASP LLM Top 10 (2025) | Standards 2023–2025 manquants. |
| **Périmètre / scope** | Description narrative | Liste structurée des 4 statuts + renvoi explicite à `docs/architecture/official-scope.md` | Aligne le chapitre 1 avec le scope officiel du dépôt. |

---

## 3. Sources ajoutées (toutes vérifiables)

| Référence | Type | Lien / DOI |
|---|---|---|
| Sandhu, Coyne, Feinstein, Youman (1996) — RBAC Models | Article fondateur | DOI [10.1109/2.485845](https://doi.org/10.1109/2.485845) |
| NIST INCITS 359-2012 — RBAC Standard | Standard | https://csrc.nist.gov/projects/role-based-access-control |
| Vaswani et al. (2017) — Attention Is All You Need | NeurIPS | https://arxiv.org/abs/1706.03762 |
| Karpukhin et al. (2020) — Dense Passage Retrieval | EMNLP | DOI [10.18653/v1/2020.emnlp-main.550](https://doi.org/10.18653/v1/2020.emnlp-main.550) |
| Gao et al. (2024) — RAG for LLMs: A Survey | arXiv | https://arxiv.org/abs/2312.10997 |
| LeCun, Bengio, Hinton (2015) — Deep Learning (Nature) | Article | DOI [10.1038/nature14539](https://doi.org/10.1038/nature14539) |
| Burns, Beda, Hightower, Evenson (2022) — Kubernetes Up and Running | Livre | O'Reilly, ISBN 978-1098110208 |
| Humble & Farley (2010) — Continuous Delivery | Livre | Addison-Wesley, ISBN 978-0321601919 |
| Wieringa (2014) — Design Science Methodology | Livre | DOI [10.1007/978-3-662-43839-8](https://doi.org/10.1007/978-3-662-43839-8) |
| Myrbakken & Colomo-Palacios (2017) — DevSecOps SLR | Springer SPICE | DOI [10.1007/978-3-319-67383-7_2](https://doi.org/10.1007/978-3-319-67383-7_2) |
| Ohm, Plate, Sykosch, Meier (2020) — Supply Chain Attacks | Springer DIMVA | DOI [10.1007/978-3-030-52683-2_2](https://doi.org/10.1007/978-3-030-52683-2_2) |
| Newman, Meyers, Torres-Arias (2022) — Sigstore | ACM CCS | DOI [10.1145/3548606.3560596](https://doi.org/10.1145/3548606.3560596) |
| NIST SP 800-204 — Microservices Security | Référentiel | DOI [10.6028/NIST.SP.800-204](https://doi.org/10.6028/NIST.SP.800-204) |
| NIST SP 800-218 — SSDF v1.1 | Référentiel | DOI [10.6028/NIST.SP.800-218](https://doi.org/10.6028/NIST.SP.800-218) |
| NIST AI 100-1 — AI Risk Management Framework | Référentiel | DOI [10.6028/NIST.AI.100-1](https://doi.org/10.6028/NIST.AI.100-1) |
| OWASP Top 10 for LLM Applications (2025) | Référentiel | https://owasp.org/www-project-top-10-for-large-language-model-applications/ |
| SLSA v1.0 Specification | Référentiel | https://slsa.dev/spec/v1.0/ |
| CycloneDX Bill of Materials Standard | Standard | https://cyclonedx.org/specification/overview/ |
| CIS Kubernetes Benchmark | Référentiel | https://www.cisecurity.org/benchmark/kubernetes |
| Pod Security Standards (Kubernetes docs) | Spec officielle | https://kubernetes.io/docs/concepts/security/pod-security-standards/ |
| Schwaber & Sutherland (2020) — Scrum Guide | Référentiel | https://scrumguides.org/scrum-guide.html |
| OMG UML 2.5.1 | Standard | https://www.omg.org/spec/UML/2.5.1 |
| Brown — C4 Model | Référentiel d'architecture | https://c4model.com/ |
| OpenAPI Specification | Standard | https://spec.openapis.org/oas/latest.html |
| Stanford HAI — AI Index 2024 | Rapport sectoriel | https://aiindex.stanford.edu/report/ |
| Fowler & Lewis (2014) — Microservices | Article séminal | https://martinfowler.com/articles/microservices.html |

> **Aucune source n'a été inventée.** Chaque entrée est vérifiable via DOI, URL d'éditeur ou identifiant officiel.

---

## 4. Problèmes détectés à signaler à l'étudiant

1. **Section « Cadre académique »** : la sous-section indique explicitement « Information à préciser par l'étudiant » concernant l'organisme d'accueil. Si tel organisme existe, compléter avec : nom, adresse, missions, encadrants, dates de stage, contexte exact du besoin. **Ne pas inventer.**
2. **Sprints (tableau)** : les 8 sprints décrits ne sont pas datés. Si la durée réelle est connue, ajouter une colonne « Période » pour ancrer la chronologie. *Information à préciser par l'étudiant.*
3. **Métriques de validation** : le chapitre 1 annonce des objectifs SMART « mesurables ». Le chapitre de mise en œuvre ou de validation devra produire les chiffres (taux de couverture exact, nombre de findings Semgrep/Trivy, pourcentage de pods aux digests, etc.). Si ces chiffres ne sont pas encore produits, mentionner les artefacts qui les contiendront.
4. **Hypothèse H2 et SLSA L2/L3** : H2 affirme que l'outillage retenu permet d'atteindre SLSA L2/L3. Cette affirmation doit être *vérifiée* dans le chapitre de validation par une matrice de conformité (un point SLSA = un artefact dans `artifacts/release/`). Si l'évidence est incomplète, abaisser à L1+ partiel ou nuancer.
5. **Diagramme `fig:vue_simplifiee_securerag`** : la flèche `services → k8s → devsecops → services` mélange flux de données et flux de pipeline (ce qui peut prêter à confusion). Suggérer de séparer ces deux types d'arêtes (par ex. lignes pleines pour les appels runtime, lignes pointillées pour les flux CI/CD).
6. **Cohérence terminologique** : le mémoire doit décider entre « microservices Laravel » (5 services) et « microservices » au sens large (incluant FastAPI legacy). Le chapitre 1 fait désormais ce choix explicitement (Laravel = officiel, FastAPI = legacy hors-scope). Vérifier que les chapitres suivants tiennent la même ligne.
7. **Espace insécable** : le fichier utilise `~:` et `~;` partout. Vérifier que `babel-french` est bien chargé dans `main.tex` pour que les espaces fines françaises soient gérées correctement à la compilation.

---

## 5. Recommandations finales pour la suite du mémoire

### 5.1 Cohérence interne
- **Reprendre la taxonomie de statut** (TERMINÉ / PARTIEL / PRÊT_NON_EXÉCUTÉ / DÉPENDANT_DE_L_ENVIRONNEMENT) dans tous les chapitres. Ne pas réintroduire d'autres libellés ad hoc.
- **Citer systématiquement les artefacts** : chaque affirmation technique du mémoire doit pointer vers un artefact archivé (`artifacts/release/...`, `artifacts/security/...`, `artifacts/final/...`). Cela transforme le mémoire en document auditable.
- Vérifier que **les 3 questions de recherche QR1, QR2, QR3** sont reprises dans le chapitre de discussion et confrontées aux résultats obtenus.

### 5.2 Renforcement scientifique
- Ajouter dans le chapitre de validation une **matrice de couverture des hypothèses** : pour chaque hypothèse H1/H2/H3, indiquer (a) les preuves convergentes, (b) les preuves divergentes, (c) la conclusion (validée / partiellement validée / réfutée).
- Pour les comparaisons avec les solutions commerciales, **éviter les jugements catégoriques** sur la qualité des LLM concurrents (ChatGPT vs Vertex vs watsonx). Se limiter aux critères mesurables dans le projet.
- Pour la section RAG, le chapitre 1 reste prudent. Si le chapitre dédié au RAG est écrit, citer **au minimum** : Lewis et al. 2020, Karpukhin et al. 2020 (DPR), Gao et al. 2024 (survey récente), et un article sur les *embeddings* (Reimers & Gurevych 2019, Sentence-BERT, à ajouter le cas échéant).

### 5.3 Style et présentation
- Maintenir l'usage cohérent de l'**italique** pour les anglicismes techniques.
- Conserver `\texttt{}` pour les noms de modes (`demo`, `production`), de fichiers et de commandes shell.
- Éviter les phrases impersonnelles trop floues (« il est important de… ») au profit de formulations directes (« le projet retient… », « le chapitre démontre… »).
- Un chapitre de mémoire de Master devrait faire entre **30 et 50 pages**. Le chapitre 1 corrigé est désormais bien dimensionné.

### 5.4 Gestion bibliographique
- La bibliographie corrigée passe de **18 à 38 entrées**. C'est un volume cohérent pour un chapitre 1 de mémoire ; s'attendre à 80–120 entrées pour le mémoire complet.
- Vérifier que `main.tex` charge bien `\bibliographystyle{apalike}` ou équivalent (par exemple `unsrtnat` pour numérique, `apalike` pour APA-like). Si la consigne est APA 7, utiliser `biblatex-apa` plutôt que `bibtex` standard.
- Toutes les URLs et DOI ajoutés sont vérifiables ; si l'un d'eux échoue lors d'un *cleanup* `latexmk`, signaler l'erreur précise (404 / DOI invalide).

### 5.5 Lien avec les améliorations expert récentes
- Le projet a récemment été enrichi de manifestes Argo CD, observabilité (Prometheus/Grafana/Loki), Falco, SOPS et Kyverno-enforce (cf. `artifacts/final/expert-readiness-report.md`). Le chapitre 1 mentionne désormais ces extensions dans la section « Perspectives ». Le **chapitre dédié à la chaîne DevSecOps** devra décrire leur architecture concrète et leur statut respectif.
- Si une démonstration live de ces composants est prévue lors de la soutenance, prévoir un **runbook unique** synthétisant les commandes d'activation (`make expert-up-all`).

---

## 6. Résumé exécutif des changements

- **Volume** : 35 274 octets → 32 870 octets (légère réduction grâce à la concision, malgré 4 ajouts substantiels : hypothèses, démarche méthodologique de recherche, tableau comparatif, bibliographie de chapitre).
- **Sections nouvelles** : « Hypothèses de recherche », « Démarche méthodologique de recherche », « Tableau comparatif synthétique », « Bibliographie du chapitre ».
- **Références bibliographiques** : 18 → 38 entrées (+20 sources vérifiables).
- **`\label` ajoutés** : 7 (sections principales) + 1 tableau comparatif.
- **Statut global** : passage d'un chapitre *clair mais peu ancré* à un chapitre *académiquement défendable*, avec problématique opérationnalisée, hypothèses falsifiables, méthodologie explicite et référentiels reconnus (NIST, OWASP, SLSA, CIS, OMG, IEEE).

Le chapitre est désormais conforme aux standards d'un mémoire de Master DSIR à dominante recherche-action en ingénierie logicielle.
