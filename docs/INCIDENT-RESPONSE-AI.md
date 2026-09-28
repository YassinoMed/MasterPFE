# Playbooks — Réponse aux incidents IA/ML (MLSecOps IR)

> **Scope** : incidents touchant le stack IA de SecureRAG Hub (Ollama,
> Qdrant, LiteLLM Gateway, SECAI, modèles, collections vectorielles).
> **Tiré d'incidents RÉELS** de la plateforme — notamment IR-501
> (crash kube-apiserver sous charge CI, 2026-09-28 10:44, documenté dans
> `evidence/2026-09-27/mlsecops-ai-stack-proof.md`).

## Outils de détection disponibles (tous opérationnels)

| Outil | Déclencheur | Script |
|---|---|---|
| Poisoning check | point Qdrant hors baseline | `scripts/security/qdrant-poisoning-check.py --check` |
| Model registry | sha256 GGUF ≠ fiche registry | `scripts/security/verify-model-registry.sh` |
| Drift monitor | hash de sortie changé / latence ×3 | `scripts/security/model-drift-monitor.py --check` |
| Guardrails IN | injection dans un prompt | logs SECAI (verdict BLOCK + règle GI-xx) |
| Guardrails OUT | secret dans une réponse | logs SECAI (verdict BLOCK + règle GO-xx) |
| Factuality | claims non tracés dans le contexte | `secai/guardrails/factuality.py` |
| Falco | shell en conteneur, lecture /etc/shadow | règles securerag (namespace securerag-hub) |

---

## IR-401 — Poisoning d'une collection vectorielle

**Symptôme** : `qdrant-poisoning-check.py --check` retourne `ALERTE POISONING`
(exemple réel : point 999 « CVE-2026-FAKE » exhortant à désactiver le
firewall — détection et remédiation démontrées en live le 2026-09-28).

**Procédure** :
1. **Qualifier** — lire `security/reports/qdrant-poisoning-alert.json` :
   point NOUVEAU / MODIFIÉ / SUPPRIMÉ ?
2. **Confiner** — supprimer le(s) point(s) suspect(s) :
   `POST /collections/vuln-kb/points/delete {"points":[<id>]}`
3. **Vérifier** — re-exécuter `--check` : le hash global DOIT revenir à
   la valeur de baseline (preuve de confinement complet).
4. **Rechercher l'origine** — qui a écrit ? Audit-log Kubernetes
   (`audit-*.log`), tokens Qdrant (aucun exposé : NetPol ingress SECAI
   uniquement — une écriture externe = compromission en amont).
5. **Durcir** — la collection n'est ingérée QUE par l'opérateur
   documenté ; tout point hors pipeline est par définition hostile.
6. **Compte-rendu** — attacher l'alerte JSON + le diff à l'evidence.

**Détecté en live le 2026-09-28** : attaque simulée → détection en <1s →
remédiation → hash global restauré (`d2661aaa…`). Cycle complet documenté.

---

## IR-402 — Substitution / altération de modèle

**Symptôme** :
- `verify-model-registry.sh` → `MISMATCH` (sha256 différent), ou
- `model-drift-monitor.py --check` → `OUTPUT CHANGÉ` sur des probes
  fixes avec temp=0 (le même modèle deterministe doit donner les mêmes
  sorties — test NÉGATIF démontré : fake GGUF → MISMATCH exit 1).

**Procédure** :
1. **Stopper l'inférence** — les réponses d'un modèle non identifié ne
   doivent plus servir : `kubectl scale deploy/ollama --replicas=0`
   (en respectant la discipline GitOps : commit + ArgoCD, PAS kubectl
   direct sur la prod — cf. IR-501 leçon).
2. **Prouver** — relever le sha256 du GGUF dans le PVC ollama-models
   et le comparer à `models/registry/qwen2.5-0.5b-instruct.yaml`.
3. **Restaurer** — re-déployer le GGUF officiel (hash du registry),
   re-vérifier.
4. **Rechercher** — qui a pu écrire dans le PVC ? StorageClass local-path
   sur nœud unique : inspecter les events du PV.
5. **Post-incident** — re-baseliner le drift monitor
   (`model-drift-monitor.py --baseline`) après restauration vérifiée.

---

## IR-403 — Dégradation runtime du modèle

**Symptôme** : drift monitor → `LATENCE ×N (>3)` sur plusieurs probes,
sans changement de hash de sortie.

**Procédure** :
1. Vérifier la contention : `kubectl top pod -n securerag-hub`,
   pression mémoire du nœud (cf. IR-501 — les builds CI lourds
   affament le nœud).
2. Si contention CI : c'est le CI qui doit s'isoler (runner dédié),
   pas le runtime LLM.
3. Après résolution, re-exécuter `--check` : retour à la normale.

---

## IR-404 — Jailbreak / injection passant les guardrails

**Symptôme** : une requête produit un comportement aberrant malgré les
guardrails (ou : bypass détecté par garak en scan continu).

**Procédure** :
1. **Extraire le payload** depuis les logs SECAI (verdict + evidence).
2. **Ajouter une règle GI-xx** dans `secai/guardrails/injection.py`
   + test de non-régression dans `secai/tests/test_guardrails.py`.
3. **Relancer le corpus red-team** (`scripts/ci/run-mlsecops-scans.sh`
   → 13/13 payloads attendus) — si le nouveau payload n'est pas
   neutralisé, itérer.
4. **Alerte** : le drift monitor + garak informent de la santé du
   modèle face aux attaques émergentes.

---

## IR-405 — Fuite de secret via une réponse LLM

**Symptôme** : logs SECAI `guardrail OUT blocked ... rule=GO-xx`
(secret détecté dans une sortie — le scan_output l'a neutralisé).

**Procédure** :
1. **Consolider la barrière** — le secret a été bloqué en sortie ;
   vérifier la source : le CONTEXTE RAG contenait le secret ?
   → alors c'est un incident upstream (rapport/log contaminé).
2. **Purger la source** — retirer le secret du document source et des
   collections (cf. IR-401 procédure de modification contrôlée).
3. **Rotation** — si le secret était réellement actif : rotation Vault
   (la plateforme est intégrée Vault/ESO).
4. **Evidence** — la réponse neutralisée n'est JAMAIS sortie (message
   standardisé) : attacher les traces du blocage.

---

## IR-501 — Indisponibilité plateforme sous charge CI (CAS RÉEL)

**Incident réel 2026-09-28 10:44** : build kaniko CI (pip install torch,
multi-GB) sur le cluster kind → apiserver en saturation mémoire →
handler timeouts → shutdown. 6443 refused ~16 min.

**Timeline** (constatée) :
```
10:44:43  apiserver: http: Handler timeout (leases coordonnées)
10:44:55  apiserver: shutdown quota evaluator → CRASH
10:48     kubelet: connection refused 6443 (restart attempt 1, cale)
11:00     docker restart securerag-dev-control-plane → Ready en 60s
```
**Impact** : builds CI interrompus ; aucun service platforme perdu
(etcd intact, récupération zéro-perte) ; stack IA 15/15 PASS après.

**Leçons (implémentées)** :
1. Les builds CI lourds sur un nœud partagé affament le control-plane →
   **runner CI dédié obligatoire** (documenté dans Jenkinsfile.ai).
2. Le PVC ollama-models + Registry ont protégé les artefacts : zéro
   perte de modèle, re-vérification immédiate possible (IR-402 check).
3. La reprise de test (`test-ai-stack-final.sh` 15/15) est LE critère
   de retour à la normale post-incident.

---

## Critères de sévérité

| Niveau | Exemple | Réponse |
|---|---|---|
| SEV-1 | secret réel fuyant (GO-x bloqué mais source contaminée) | rotation immédiate |
| SEV-2 | poisoning détecté, modèle substitué, apiserver down | confinement < 15 min |
| SEV-3 | dégradation latence, partial-factuality | sous 24h, revue humaine |
