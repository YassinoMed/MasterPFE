# Runtime Security — SecureRAG Hub

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    RUNTIME SECURITY LAYER                      │
│                                                               │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐  │
│  │  Falco   │   │ Tetragon │   │ Cilium   │   │  Hubble  │  │
│  │ eBPF     │   │ eBPF     │   │ eBPF CNI │   │  Service │  │
│  │ Syscalls │   │ Kprobes  │   │ NetPolice│   │  Map     │  │
│  └────┬─────┘   └────┬─────┘   └────┬─────┘   └────┬─────┘  │
│       │              │              │               │         │
│       ▼              ▼              ▼               ▼         │
│  ┌──────────────────────────────────────────────────────┐     │
│  │              QUALITY GATE (Pipeline)                  │     │
│  │  secure-quality-gate.sh bloque si CRITICAL > 0       │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐     │
│  │              ALERTING                                  │     │
│  │  Falcosidekick → Wazuh + Slack + Prometheus           │     │
│  └──────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

## Falco

13 règles custom alignées MITRE ATT&CK.

### Rules
- T1059 — Shell in Container
- T1105 — Network Download Tools
- T1505 — Write to /etc/
- T1059 — Reverse Shell
- T1136 — User Account Mutation
- T1543 — Cron/Systemd Persistence
- T1552 — Sensitive File Read
- T1611 — Privilege Escalation
- T1070 — Log Tampering
- TA0011 — Unexpected Egress
- T1613 — Suspicious K8s API

### Validation
```bash
bash scripts/ci/validate-falco-rules.sh
bash scripts/ci/parse-falco.sh
```

## Tetragon

3 TracingPolicies.

### Policies
1. **Process Execution** — Détection de toute exécution de processus
2. **Reverse Shell** — Détection des shells inversés (curl, wget, nc, socat)
3. **kubectl exec** — Surveillance des accès kubectl exec

### Validation
```bash
bash scripts/ci/validate-tetragon-policies.sh
bash scripts/ci/parse-tetragon.sh
```

## Cilium + Hubble

5 CiliumNetworkPolicies :
1. default-deny-all
2. allow-dns-egress
3. allow-database-access
4. allow-harbor-registry
5. allow-monitoring-ingress

Hubble : Service map + observabilité réseau.

## Quality Gate Integration

Les checks runtime sont intégrés dans `secure-quality-gate.sh` :
- Falco CRITICAL > 0 → FAIL
- Tetragon kubectl exec > 0 → FAIL
