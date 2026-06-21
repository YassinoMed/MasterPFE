# Chapitre Mémoire : Phase Post-Déploiement et Amélioration Continue DevSecOps

## Statut : DISPONIBLE (STYLE ACADÉMIQUE)

Ce document présente une section rédigée en français académique et formel, destinée à être insérée dans le mémoire de projet de fin d'études de SecureRAG Hub.

---

## 1. Pourquoi la chaîne DevSecOps ne s'arrête pas au déploiement

Traditionnellement, la sécurité dans le cycle de développement logiciel (SSDLC) se focalise principalement sur la phase pré-déploiement (SAST, SCA, scans de secrets, builds sécurisés). Cependant, considérer que le passage en production marque la fin des vérifications de sécurité constitue une faille méthodologique majeure. Une fois l'application déployée au sein d'un cluster Kubernetes, de nouveaux vecteurs d'attaques dynamiques, des dérives de configuration (configuration drift) ou des vulnérabilités zero-day peuvent survenir à tout moment.

> **« Dans SecureRAG Hub, le déploiement Kubernetes n’est pas la fin de la chaîne DevSecOps. Il constitue le point de départ d’une phase de validation post-déploiement visant à vérifier le bon fonctionnement applicatif, la conformité des images exécutées, le respect des politiques de sécurité Kubernetes, la disponibilité des preuves techniques et l’alimentation d’une boucle d’amélioration continue. »**

---

## 2. Les Composants Clés de la Phase Post-Déploiement

### 2.1 Rôle de la Validation Post-Déploiement
La validation post-déploiement automatisée agit comme une barrière d'assurance qualité et de sécurité en continu. Elle permet de s'assurer, de manière déterministe, que les descripteurs Kubernetes ont été appliqués avec succès, que les conteneurs sont en état de marche (`Running` et `Ready`) et qu'aucun service critique n'est indisponible en raison de dysfonctionnements de démarrage (ex: `CrashLoopBackOff` ou `ImagePullBackOff`).

### 2.2 Rôle de la Preuve Runtime (Runtime Image Proof)
Dans une chaîne logistique logicielle sécurisée (Supply Chain Security), il est crucial de garantir l'authenticité des workloads exécutés. La preuve runtime consiste à interroger directement l'API Kubernetes pour obtenir l'identifiant unique (SHA256 digest) de chaque conteneur en cours d'exécution. Cette valeur est ensuite confrontée aux digests officiels et signés lors de la phase de CI/CD. Cela élimine définitivement les attaques basées sur l'usurpation d'images ou les déploiements non autorisés d'images tierces utilisant des tags mutables comme `latest`.

### 2.3 Rôle de la Sécurité Runtime (Kernel & Calls System Audit)
Les contrôles statiques au niveau d'admission (comme Kyverno) ou les configurations de pods (SecurityContext) restreignent les privilèges de base mais ne bloquent pas toutes les tentatives d'intrusion actives. La sécurité runtime s'appuie sur des outils d'analyse système avancés comme **Falco** et **Tetragon**. En écoutant directement les appels système au niveau du noyau Linux (via eBPF), le système est capable de détecter instantanément et d'alerter lors de comportements suspects (tels que le lancement d'un terminal interactif dans un conteneur web ou une tentative d'écriture dans un répertoire système en lecture seule).

### 2.4 Rôle de l'Observabilité
L'observabilité moderne ne sert pas uniquement à monitorer les pannes matérielles ou les temps de réponse. En DevSecOps, elle corrèle les données de performance applicative (SLO de disponibilité et de latence) avec les métriques de sécurité (violations de politiques Kyverno, alertes Falco, logs système Loki). Cette centralisation offre aux équipes de détection une visibilité à 360 degrés sur la santé globale et le niveau d'exposition du cluster.

### 2.5 Rôle du Support Pack (Evidence Collection)
Dans le cadre d'audits de conformité de sécurité (comme ISO 27001 ou SOC2) ou d'une soutenance de fin d'études, il est indispensable de pouvoir présenter des preuves irréfutables de la conformité du système. Le support pack regroupe de manière automatique, à chaque déploiement, l'ensemble des rapports générés (rapports de scans Semgrep/Trivy, manifestes appliqués, digests réels vérifiés par Cosign, logs de validation) sous une archive compressée et signée.

### 2.6 Rôle de la Boucle Fermée (Feedback Loop)
Le DevSecOps s'inscrit dans un modèle d'amélioration continue. Tout dysfonctionnement détecté au runtime (que ce soit une faille applicative détectée par smoke test ou une violation de règle système Falco) doit obligatoirement remonter sous forme d'alerte, être analysé par l'équipe d'ingénierie, et donner lieu à un correctif (correction de code Laravel, durcissement de configuration Kustomize, ou ajustement de politique Kyverno). Cette boucle fermée de feedback boucle l'ensemble du cycle de vie du logiciel et renforce de manière continue la résilience du système.
