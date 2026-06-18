# Incident Response Runbook — SecureRAG Hub

> **Scope:** All incidents affecting SecureRAG Hub production services.
> **Audience:** SRE on-call, DevSecOps, Incident Commanders.

---

## 1. Severity Definitions

| Severity | Label | Description | Response Time | SLA |
|----------|-------|-------------|---------------|-----|
| **SEV1** | CRITICAL | Complete service outage, data loss, or security breach affecting production. Customer-facing impact. | < 5 min acknowledge | RTO: 1h |
| **SEV2** | HIGH | Partial service degradation, feature unavailability, or non-critical data issue. No customer-facing impact. | < 15 min acknowledge | RTO: 4h |
| **SEV3** | MEDIUM | Minor performance impact, non-critical bug, or operational issue. No user-facing impact. | < 1h acknowledge | RTO: 24h |
| **SEV4** | LOW | Cosmetic issue, documentation gap, enhancement request. No service impact. | Next business day | Next release |

**RTO** = Recovery Time Objective. **RPO** = Recovery Point Objective (default: 1h for critical services).

---

## 2. Incident Lifecycle

### 2.1 Detection
- Automated alert from Prometheus / Alertmanager / Falco
- User-reported via support channel
- Manual observation during routine checks
- Security scan or penetration test discovery

### 2.2 Triage
1. **Acknowledge** the alert (within response time per severity)
2. **Classify** severity using definitions above
3. **Declare** incident by posting in `#securerag-incidents`
4. **Assign** Incident Commander (IC) — the first qualified responder
5. **Open** incident timeline document

### 2.3 Response
1. IC assesses scope and impact
2. IC assigns roles: Comms Lead, Ops Lead, Security Lead (if applicable)
3. Response team executes runbook steps for the detected symptom
4. IC tracks progress and updates timeline
5. Communications Lead drafts stakeholder updates

### 2.4 Mitigation
1. Apply immediate fix (rollback, scale, failover, block traffic)
2. Verify mitigation effectiveness via monitoring
3. Document workaround if permanent fix is delayed
4. IC declares mitigation complete when impact stops growing

### 2.5 Resolution
1. Deploy permanent fix after root cause confirmed
2. Monitor for stabilization (minimum 15 min for SEV1, 5 min for SEV2+)
3. IC declares incident resolved
4. Postmortem ticket created (mandatory for SEV1/SEV2)

### 2.6 Closure
1. Postmortem completed and reviewed
2. Action items tracked in project management system
3. Runbook updated if gaps identified
4. Stakeholder summary sent

---

## 3. Escalation Path

```
Responder (On-call SRE)
  │
  ├── Level 1: On-call SRE
  │     Response: Initial triage, runbook execution
  │
  ├── Level 2: SRE Lead / DevSecOps Lead
  │     Trigger: SEV1 declared, SEV2 unresolved after 30min
  │     Response: Cross-team coordination, complex diagnosis
  │
  ├── Level 3: Engineering Manager
  │     Trigger: SEV1 unresolved after 1h, multi-service impact
  │     Response: Resource allocation, executive communication
  │
  └── Level 4: VP Engineering / CTO
        Trigger: SEV1 exceeding RTO, customer escalation, security breach
        Response: Crisis management, public communication
```

### Escalation Contacts

| Level | Contact | Method |
|-------|---------|--------|
| L1 | On-call SRE | PagerDuty / Slack `@sre-oncall` |
| L2 | SRE Lead | Phone / Slack `@sre-lead` |
| L3 | Engineering Manager | Phone / Email |
| L4 | VP Engineering | Phone / Email |

---

## 4. Communication Templates

### 4.1 Incident Acknowledgment

```
[SEV${SEVERITY}] [${DATE}] ${ALERT_NAME} — Acknowledged

- Service: ${SERVICE}
- Impact: ${IMPACT_DESCRIPTION}
- Responder: ${NAME}
- Time: ${TIMESTAMP} UTC

Investigating. Next update in 15 minutes.
```

### 4.2 Incident Update

```
[SEV${SEVERITY}] [${DATE}] ${ALERT_NAME} — Update ${N}

- Status: Investigating / Mitigating / Resolved / Monitoring
- Current findings: ${FINDINGS}
- Action taken: ${ACTIONS}
- Next update: ${TIME}
```

### 4.3 Incident Resolved

```
[SEV${SEVERITY}] [${DATE}] ${ALERT_NAME} — Resolved

- Duration: ${DURATION}
- Root cause: ${ROOT_CAUSE}
- Resolution: ${RESOLUTION}
- Postmortem: ${LINK}

Monitoring for stabilization.
```

### 4.4 Customer-Facing Status Page

```markdown
## Incident Report — ${DATE}

**What happened:**
Brief description of the incident.

**Impact:**
Description of user-facing impact including duration and affected features.

**Timeline:**
Key events from detection to resolution.

**Root Cause:**
Summary of underlying cause.

**Preventive Actions:**
List of actions being taken to prevent recurrence.
```

---

## 5. Incident Command System (ICS)

### Roles

| Role | Responsibility | Assigned To |
|------|----------------|-------------|
| **Incident Commander (IC)** | Overall coordination, decision-making, timeline tracking | First qualified responder |
| **Operations Lead** | Technical diagnosis, runbook execution, fix implementation | SRE on-call |
| **Communications Lead** | Stakeholder updates, status page, escalation notifications | Designated team member |
| **Scribe** | Timeline documentation, evidence collection, action item tracking | Dedicated note-taker |
| **Security Lead** | Security incident triage, containment, forensics | DevSecOps on-call |

### ICS Principles

- **One IC at a time** — clear chain of command
- **Span of control** — IC manages 3-5 direct reports
- **Incident action plan** — IC sets objectives each 30 min for SEV1
- **Transfer of command** — formal handover with briefing

### Handover Procedure

When IC or team member needs to hand over:

1. **Brief** incoming person on current status (what, impact, actions, next steps)
2. **Share** timeline document, active investigations, and decision log
3. **Clarify** outstanding questions and pending actions
4. **Confirm** handover in incident channel
5. **Stay** available for 15 min after handover for questions

```
─── IC Handover ───
Outgoing: @name
Incoming: @name
Time: HH:MM UTC
Status: [Investigating / Mitigating / Monitoring]
Key findings:
- ...
Open items:
- ...
Next steps:
- ...
─────────────────────
```

---

## 6. 5 Whys Analysis Template

Use for postmortem root cause analysis:

```
Problem Statement:
  What went wrong?

Why #1:
  [Direct cause]
Why #2:
  [Why was #1 true?]
Why #3:
  [Why was #2 true?]
Why #4:
  [Why was #3 true?]
Why #5:
  [Why was #4 true? — This is the root cause]

Systemic Root Cause:
  [One sentence describing the fundamental systemic issue]

Action Items:
  - [Action] → [Owner] → [Deadline]
```

---

## 7. Incident Classification Tags

| Tag | Meaning |
|-----|---------|
| `infra` | Infrastructure failure (compute, network, storage) |
| `app` | Application bug or misconfiguration |
| `security` | Security incident or vulnerability |
| `data` | Data loss, corruption, or inconsistency |
| `dependency` | External service dependency failure |
| `capacity` | Resource exhaustion or scaling failure |
| `deploy` | Deployment-related incident (bad release, rollback) |
| `human` | Human error (configuration mistake, fat-finger) |

---

## 8. Post-Incident Review Checklist

- [ ] Incident timeline documented
- [ ] 5 Whys completed
- [ ] Action items created with owners and deadlines
- [ ] Runbook updated with lessons learned
- [ ] Alert thresholds reviewed and adjusted if needed
- [ ] Monitoring coverage gap assessed
- [ ] Blameless postmortem published
- [ ] Stakeholder communication sent
- [ ] Action items tracked to closure

---

## 9. References

- [Postmortem Template](../postmortems/template.md)
- [Kubernetes Incidents Runbook](./kubernetes-incidents.md)
- [Service Incidents Runbook](./service-incidents.md)
- [Security Incidents Runbook](./security-incidents.md)
- [Disaster Recovery Runbook](./disaster-recovery.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [SRE Incident Response](./sre-incident-response.md)
- [Runtime Security Operations](./runtime-security-operations.md)
