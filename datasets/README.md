# Générateur de Datasets AISEC — Architecture

## Pipeline de transformation

```
┌─────────────────────────────────────────────────────────────────┐
│                    SOURCES DE LOGS SÉCURITÉ                       │
├──────────┬──────────────┬──────────────┬────────────────────────┤
│  Falco   │    Trivy     │   Kyverno    │   Audit-log K8s       │
│ (20 evts)│ (435 audits)│(191 reports) │   (849K lignes)        │
└────┬─────┴──────┬───────┴──────┬───────┴────────┬───────────────┘
     │            │              │               │
     ▼            ▼              ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│              EXTRACTEUR DE FEATURES (Python)                    │
│  rule, severity, process, command, file, user, MITRE tags      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              OLLAMA — Qwen2.5-0.5B-Instruct                      │
│  (temp=0.1, seed=42, num_predict=150)                        │
│                                                               │
│  4 types de prompts :                                        │
│  ├── CLASSIFICATION → MITRE ATT&CK tactic                     │
│  ├── SEVERITY       → 1-5 rating                              │
│  ├── REMEDIATION   → action corrective                       │
│  └── EXPLANATION    → explication analyste                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              GUARDRAILS SECAI (3 couches)                       │
│  ├── scan_prompt_injection → BLOCK si injection dans le log  │
│  ├── scan_output          → SANITIZE si secret dans la répons│
│  └── canary_tokens        → IR-404 si prompt fuit             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              DATASET JSONL (fine-tuning ready)                   │
│                                                               │
│  {                                                            │
│    "instruction": "Falco: Read sensitive file untrusted...",  │
│    "response": "Credential Access",                            │
│    "metadata": {                                               │
│      "type": "classification",                                │
│      "severity": "Warning",                                     │
│      "rule": "Read sensitive file untrusted",                  │
│      "mitre_tags": ["T1555", "mitre_credential_access"],      │
│      "guardrail_verdict": "ALLOW"                              │
│    }                                                           │
│  }                                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

```bash
# Générer depuis les logs Falco (rapide, 3 events)
python3 scripts/ai/generate-datasets.py --source falco --max-events 3

# Générer depuis tous les sources (complet)
python3 scripts/ai/generate-datasets.py --source all --max-events 50

# Types spécifiques
python3 scripts/ai/generate-datasets.py --types classification,severity

# Output personnalisé
python3 scripts/ai/generate-datasets.py --output datasets/my-aisec/
```

## Fine-tuning (après génération)

```bash
# Avec LoRA/QLoRA (recommandé pour 0.5B)
python3 -m torch.distributed.run --nproc_per_node=1 \
  finetune.py \
  --base_model Qwen/Qwen2.5-0.5B-Instruct \
  --dataset datasets/aisec/classification.jsonl \
  --lora_rank 16 \
  --epochs 3 \
  --output_dir models/aisec-classifier
```

## Intégration avec la plateforme

| Composant | Rôle dans le pipeline |
|---|---|
| **Falco** (2 pods) | Fournit les events runtime (shell, /etc/shadow, binary execution) |
| **Trivy Operator** (435 reports) | Fournit les vulnérabilités et audits de configuration |
| **Kyverno** (191 reports) | Fournit les violations de policy |
| **Ollama** (Qwen2.5-0.5B) | Transforme les logs en annotations structurées |
| **Guardrails SECAI** (12 modules) | Protège contre les injections dans les logs et les fuites |
| **Qdrant** | Peut stocker les datasets pour RAG (recherche par similarité) |
| **Pipeline Jenkins** | Peut automatiser la génération périodique des datasets |

## Sécurité du pipeline

| Risque | Mitigation | Preuve |
|---|---|---|
| Log contient une injection prompt | `scan_prompt_injection` → BLOCK | 28/28 tests |
| Réponse LLM contient un secret | `scan_output` → SANITIZE | 28/28 tests |
| Prompt système fuit dans la réponse | `canary_tokens` → IR-404 | 15/15 tests |
| Log contient de la PII | `presidio_pii` → MASQUÉ | 10/10 tests |
| Dataset falsifié | `transparency_log` → chaînage SHA-256 | 11/11 tests |
