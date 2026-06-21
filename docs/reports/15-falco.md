# 15 — Falco Runtime Security

> **Date :** 2026-06-18  
> **Verdict :** ❌ NOT DEPLOYED

---

## Résumé Exécutif

Falco n'est pas déployé sur le cluster. Aucun pod dans le namespace `falco`. Les 16 règles MITRE ATT&CK sont définies mais pas actives.

---

## État Actuel

| Composant | Statut |
|-----------|:------:|
| Falco DaemonSet | ❌ Non déployé |
| Falcosidekick | ❌ Non déployé |
| Falco Talon | ❌ Non déployé |
| Règles custom (16) | ✅ Définies (226 lines) |
| Helm values | ✅ Prêtes |

---

## Règles Disponibles (security/falco/custom-rules.yaml)

| Règle | MITRE | Sévérité |
|-------|:-----:|:--------:|
| Shell in Container | T1059 | WARNING |
| Network Tool Executed | T1105/T1059 | WARNING |
| Write to etc Directory | T1059 | WARNING |
| Reverse Shell Indicator | T1059 | CRITICAL |
| Write Below Sensitive Path | T1505/T1136 | ERROR |
| User Account Mutation | T1136 | CRITICAL |
| Package Manager in Container | T1059/T1105 | ERROR |
| Sensitive File Read | T1552 | ERROR |
| Privilege Escalation | T1611 | CRITICAL |
| Log Tampering | T1070 | WARNING |
| Outbound Unexpected Port | TA0011 | WARNING |
| Suspicious K8s API Verb | T1613 | WARNING |

---

## Recommandations

1. Déployer Falco via Helm : `helm upgrade --install falco falcosecurity/falco -f security/falco/values.yaml`
2. Déployer Falcosidekick pour les alertes
3. Configurer Alertmanager pour recevoir les alertes Falco

---

## Conclusion

16 règles Falco prêtes, couvrant les techniques MITRE ATT&CK les plus critiques. Le déploiement est la seule étape manquante.
