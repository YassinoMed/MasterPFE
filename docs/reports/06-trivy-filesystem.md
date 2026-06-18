# 06 — Trivy Filesystem Scan

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

Scan Trivy filesystem exécuté avec les scanners `vuln,secret,misconfig`. Trivy a analysé les manifests Kubernetes des tests d'admission et de chaos. Les résultats montrent des findings MEDIUM sur les manifests de test (images non signées, latest tags).

---

## Résultats par Sévérité

| Sévérité | Nombre | Détail |
|:--------:|:------:|--------|
| CRITICAL | 0 | Aucun |
| HIGH | 1 | Litmus ClusterRole `pods/exec` |
| MEDIUM | 11 | Images untrusted registry, latest tags, RBAC |
| LOW | 0 | Aucun |

---

## Détail des Findings

| Fichier | Sévérité | ID | Description |
|---------|:--------:|:---|-------------|
| `tests/admission/negative/03-unsigned-image.yaml` | MEDIUM | KSV-0125 | Image from untrusted registry |
| `tests/admission/negative/04-image-latest-tag.yaml` | MEDIUM | KSV-0013 | Latest tag used |
| `tests/admission/negative/04-image-latest-tag.yaml` | MEDIUM | KSV-0125 | Image from untrusted registry |
| `tests/admission/negative/05-cleartext-password.yaml` | MEDIUM | KSV-0125 | Image from untrusted registry |
| `tests/admission/positive/01-conformant-pod.yaml` | MEDIUM | KSV-0125 | Image from untrusted registry |
| `tests/chaos/litmus-experiments.yaml` | MEDIUM | KSV-0042 | Litmus ClusterRole pods/log |
| `tests/chaos/litmus-experiments.yaml` | MEDIUM | KSV-0048 | Litmus ClusterRole wide perms |
| `tests/chaos/litmus-experiments.yaml` | HIGH | KSV-0053 | Litmus ClusterRole pods/exec |

---

## Analyse

- Les findings MEDIUM sur les fichiers de test sont **attendus** (images fictives pour tester Kyverno)
- Le finding HIGH sur Litmus est **normal** (nécessaire pour le chaos engineering)
- Aucun finding sur le code production

---

## Recommandations

1. Ignorer les findings sur `tests/admission/` (fausses images de test)
2. Documenter les exceptions Litmus dans `.trivyignore`
3. Ajouter un scan spécifique PROD vs NON_PROD

---

## Conclusion

Aucune vulnérabilité critique sur le code production. Les findings MEDIUM/HIGH se limitent aux fichiers de test et sont justifiés.
