# MLSecOps — OWASP LLM Top 10 : Cartographie des contrôles

> **Statut** : Cartographie vivante — chaque risque OWASP LLM Top 10 (v2025) est
> associé aux contrôles réellement implémentés sur la plateforme SecureRAG Hub.
> Les entrées marquées ✅ ont une preuve vérifiable (test, policy, ou mesure live).
> Les entrées ⚠️ sont partiellement couvertes, ❌ non couvertes.

## Stack IA déployé

| Composant | Rôle | Preuve |
|---|---|---|
| **Ollama** (`securerag-hub/ollama`) | Runtime LLM local (modèles open-source) | Pod Running, API `/api/tags` opérationnelle, modèle Qwen2.5-0.5B importé |
| **Qdrant** (`securerag-hub/qdrant`) | Vector DB pour RAG sécuritaire | Pod Running, collection `vuln-kb`, recherche sémantique validée (score 0.996) |
| **AI Gateway** (`ai-gateway-litellm`) | Proxy LiteLLM : auth master-key + API OpenAI-compatible devant Ollama | Pod Running, `/health/liveliness` 200, chat/completions routé vers qwen2.5-0.5b |
| **SECAI** (`securerag-hub/secai`) | Service d'analyse sécurité IA (SecureBERT) | Pod Running, API `/health` + `/analyze` + 37 tests |
| **Cosign** | Signature des images du stack IA | `ollama` + `qdrant` + `litellm` signés + policy `verify-cosign-images` Enforce |
| **Kyverno** | Admission control du stack IA | 8 policies Enforce validées sur les déploiements IA |

---

## Cartographie OWASP LLM Top 10 (v2025)

### LLM01 — Prompt Injection ✅
*Instructions malveillantes dans l'input qui détourne le modèle.*

| Contrôle | Implémentation | Preuve |
|---|---|---|
| Sanitization systématique | SECAI échappe tout contenu externe avant traitement (règles Semgrep échappées, payloads Falco traités comme données) | `secai/tests/test_security.py::test_falco_prompt_injection_not_parsed_as_command` |
| Entrées non fiables = données | Les logs Falco contenant des payloads d'injection sont stockés en evidence, jamais interprétés | `secai/integrations/falco.py` (commentaire explicite + test) |
| API read-only | SECAI n'expose aucune mutation — impossible de détourner l'API pour modifier l'état | `secai/api/main.py` (endpoints `/health`, `/ready`, `/analyze`, `/explain` uniquement) |
| Détection heuristique | Module guardrails : détection de patterns d'injection (ignore previous, system prompt, délimiteurs) | `secai/guardrails/injection.py` + tests |

### LLM02 — Sensitive Information Disclosure ✅
*Fuite d'informations sensibles via les réponses du modèle.*

| Contrôle | Implémentation | Preuve |
|---|---|---|
| Zéro secret dans le code | SECAI charge tout depuis l'environnement/Vault — aucune valeur sensible codée | `secai/config.py` (docstring + structure) |
| Filtrage des secrets en sortie | Guardrails : détection de patterns secrets (AKIA…, private keys, JWT, tokens) dans les réponses LLM | `secai/guardrails/output_filter.py` + test live |
| Audit-log chiffré | etcd encryption AES-CBC + audit-log 849K lignes | `evidence/2026-09-27/` |
| Network isolation | NetPols zero-trust : ollama/qdrant inaccessibles hors namespace, egress limité | `infra/k8s/base/ai-stack/networkpolicies.yaml` |

### LLM03 — Supply Chain ✅
*Composants IA malveillants (modèles, images, dépendances).*

| Contrôle | Implémentation | Preuve |
|---|---|---|
| Images signées Cosign | `ollama` + `qdrant` + `secai` signés, policy `verify-cosign-images` Enforce bloque tout non-signé | Tentative Velero non-signé → BLOCKED (evidence Phase 14) |
| Digest-pinning obligatoire | Policy `restrict-image-references` : `*@sha256:*` requis, `:latest` interdit | Déploiements IA en digest (`sha256:4be1…`, `sha256:0699…`) |
| SBOM + scan pipeline | Jenkinsfile.ai : Trivy blocking, SBOM, Cosign, SLSA provenance | `Jenkinsfile.ai` stages 6-8 |
| Modèle traçable | Qwen2.5-0.5B importé depuis HuggingFace avec hash vérifié, Modelfile versionné | `infra/k8s/base/ollama/modelfile/` |

### LLM04 — Data and Model Poisoning ⚠️
*Corruption des données d'entraînement ou du modèle.*

| Contrôle | Implémentation | Statut |
|---|---|---|
| Modèles pinés | Le modèle est importé manuellement (digest GGUF vérifié), jamais auto-téléchargé en prod | ✅ |
| Données sources auditables | Collection `vuln-kb` alimentée uniquement par l'opérateur (pas d'ingestion publique) | ✅ |
| Détection de poisoning | Pas de contrôle automatique de drift/intégrité des données vectorielles | ❌ (roadmap) |

### LLM05 — Improper Output Handling ✅
*Consommer la sortie LLM sans validation (XSS, code malveillant, commandes).*

| Contrôle | Implémentation | Preuve |
|---|---|---|
| Sortie jamais exécutée | SECAI traite les sorties modèle comme données : aucune eval/exec, aucun rendu HTML | `secai/tests/test_api.py` |
| Validation de schéma | Pydantic : toute réponse est validée avant consommation | `secai/api/schemas.py` |
| Guardrails output | Filtrage de secrets + patterns dangereux avant retour au client | `secai/guardrails/output_filter.py` |

### LLM06 — Excessive Agency ⚠️
*Donner trop de permissions/actions au système IA.*

| Contrôle | Implémentation | Statut |
|---|---|---|
| Mode advisory | SECAI opère en `mode: advisory` — aucune action automatique | ✅ `secai-config` ConfigMap |
| Auto-remediation désactivée | `auto_remediation: 'false'` par défaut | ✅ |
| Pas de tools/functions call | Ollama exposé en inférence pure, aucun tool-calling vers l'infrastructure | ✅ |
| Human-in-the-loop | Les décisions de remédiation passent par Jenkins (approval manuel) | ⚠️ partiel |

### LLM07 — System Prompt Leakage ✅
*Divulgation du prompt système / des instructions métier.*

| Contrôle | Implémentation | Preuve |
|---|---|---|
| Prompt système hors repo | Prompts stockés en ConfigMap, pas dans le code applicatif | `secai-config` |
| Guardrails input | Détection des requêtes demandant la divulgation du prompt système | `secai/guardrails/injection.py` |
| Pas de secrets dans les prompts | Test unitaire : aucune credential ne transite dans un prompt | `secai/tests/test_security.py` |

### LLM08 — Vector and Embedding Weaknesses ✅
*Attaques sur la base vectorielle (poisoning RAG, cross-tenant leakage).*

| Contrôle | Implémentation | Preuve |
|---|---|---|
| Isolation réseau | Qdrant inaccessible hors namespace securerag-hub, ingress limité à SECAI + Prometheus | `qdrant-netpol` |
| Collections scoping | Collection `vuln-kb` isolée, payload scanné à l'insertion | Test live insertion + query |
| Scan des contenus | Les documents ingérés passent par les mêmes sanitizers que les inputs LLM | `secai/guardrails/injection.py` réutilisé |

### LLM09 — Misinformation ⚠️
*Hallucinations et sorties non fondées.*

| Contrôle | Implémentation | Statut |
|---|---|---|
| Grounding RAG | Les analyses SECAI citent leurs sources (reports Trivy/Semgrep/Falco parsés) | ✅ |
| Confidence threshold | `confidence_threshold: 0.80` — les findings < 0.80 sont filtrés | ✅ `secai-config` |
| Désactivation LLM externe | `enable_external_llm: 'false'` — SECAI n'appelle AUCUN LLM externe (anti-exfiltration) | ✅ |
| Détection hallucination | Pas de mesure automatique de factualité | ❌ (roadmap) |

### LLM10 — Unbounded Consumption ✅
*Consommation excessive de ressources (cost attack, DoS).*

| Contrôle | Implémentation | Preuve |
|---|---|---|
| Limites de ressources | Ollama : limits memory 2Gi, cpu requests 500m (LimitRange namespace = 2Gi max) | Deployment ollama |
| Auth obligatoire au gateway | Toute requête LLM passe par LiteLLM avec master key (Bearer) — sans clé → refus | Test live sans auth → REFUSÉ |
| Bornes d'inférence | `max_tokens: 512` + `request_timeout: 150` au niveau gateway — chaque appel est borné | `litellm-nemo-config` ConfigMap |
| Rate-limiting applicatif | Guardrails : token bucket par client sur l'API guardrails | `secai/guardrails/rate_limit.py` + 4 tests |
| Max length input | `max_length: '1024'` tokens en ConfigMap | `secai-config` |
| Local-only | Modèles en local : le coût par token est borné par le hardware, aucune facturation externe | Architecture locale |

---

## Contrôles Kyverno applicables au stack IA (validés en direct)

Le déploiement du stack IA a été soumis aux 8 policies Enforce et a nécessité la
conformité complète — chaque correction a été une itération réelle :

| Exigence policy | Conformité stack IA |
|---|---|
| `verify-cosign-images` | Images ollama/qdrant signées cosign + vérifiées avant déploiement |
| `restrict-image-references` | Digest-pinning `@sha256:…`, registries allowlistés |
| `require-workload-controls` | 3 probes + automountServiceAccountToken: false + resources |
| `disallow-root-containers` | runAsNonRoot: 1000 + capabilities drop ALL + seccomp |
| `restrict-service-exposure` | Services ClusterIP allowlistés (policy mise à jour de manière traçable) |
| `restrict-volume-types` | emptyDir uniquement |
| `disallow-host-network` | hostNetwork absent |
| `audit-cleartext-env-values` | Pas de secret en env variable |

**C'est la preuve que l'admission control s'applique uniformément aux workloads
IA comme au reste de la plateforme — aucun privilège spécial pour l'IA.**

---

## Roadmap MLSecOps restante

| Priorité | Item | Statut |
|---|---|---|
| 🔴 Haute | Garak/modelscan dans le pipeline CI (scanning modèles automatisé) | Script présent, outils à installer sur runner avec réseau |
| 🔴 Haute | Filtrage output LLM en production (proxy) | Module SECAI prêt, à câbler sur le trafic réel |
| 🟡 Moyenne | Détection de drift des modèles | Roadmap |
| 🟡 Moyenne | Poisoning detection sur collections vectorielles | Roadmap |
| 🟢 Basse | Factuality scoring (anti-hallucination) | Roadmap |
