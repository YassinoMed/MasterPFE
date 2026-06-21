# Postmortem Template — SecureRAG Hub

> **Blameless Culture Statement:** This postmortem is a blameless, fact-based analysis.
> We focus on understanding the systemic causes of the incident, not on individual actions.
> Every team member is encouraged to contribute openly without fear of blame.
> The goal is to improve our systems and processes, not to assign fault.

---

## 1. Incident Summary

| Field | Value |
|-------|-------|
| **Date** | `YYYY-MM-DD` |
| **Title** | Short descriptive title |
| **Severity** | SEV1-CRITICAL / SEV2-HIGH / SEV3-MEDIUM / SEV4-LOW |
| **Duration** | `T-started` → `T-resolved` (total: `XhYmin`) |
| **Affected Services** | List of services impacted |
| **Detected By** | Monitoring alert / User report / Manual check |
| **Incident Commander** | Name |

---

## 2. Timeline

| Time (UTC) | Event |
|------------|-------|
| `HH:MM` | Detection — how the incident was first identified |
| `HH:MM` | Response — who was notified and when they responded |
| `HH:MM` | Triage — initial assessment and severity classification |
| `HH:MM` | Mitigation — actions taken to reduce impact |
| `HH:MM` | Workaround — temporary fix applied (if any) |
| `HH:MM` | Resolution — confirmed service restoration |
| `HH:MM` | Closure — postmortem initiated, stakeholders notified |

---

## 3. Impact

| Metric | Value |
|--------|-------|
| Total downtime | `Xh Ymin` |
| Users affected | `N` |
| Requests failed | `N` |
| Error budget consumed | `X%` |
| Data loss | `Yes / No / Partial` |

---

## 4. Root Cause Analysis — 5 Whys

| Why | Answer |
|-----|--------|
| **1.** What happened? | |
| **2.** Why did it happen? | |
| **3.** Why was that the case? | |
| **4.** Why was that condition present? | |
| **5.** Why did the existing controls fail to prevent this? | |

**Summary of root cause:** *One paragraph describing the fundamental systemic issue.*

---

## 5. Contributing Factors

- Factor 1 (e.g., missing monitoring)
- Factor 2 (e.g., insufficient capacity planning)
- Factor 3 (e.g., undocumented dependency)

---

## 6. Detection Gaps

- How could detection have been faster?
- Were there existing alerts that should have fired?
- Did the escalation path work as expected?

---

## 7. Action Items

| # | Action | Type | Owner | Deadline | Status |
|---|--------|------|-------|----------|--------|
| 1 | Add monitoring for X | prevent | @team | YYYY-MM-DD | :white_large_square: |
| 2 | Create runbook for Y | process | @team | YYYY-MM-DD | :white_large_square: |
| 3 | Update deployment for Z | mitigate | @team | YYYY-MM-DD | :white_large_square: |
| 4 | Add integration test for W | test | @team | YYYY-MM-DD | :white_large_square: |

**Types:** `prevent` (prevents recurrence), `mitigate` (reduces impact), `process` (improves response), `test` (validates fix)

---

## 8. Metrics

### MTTD (Mean Time to Detection)

```
Detection time - Incident start time = X minutes
```

### MTTR (Mean Time to Resolution)

```
Resolution time - Detection time = X minutes
```

### Breakdown

| Phase | Duration |
|-------|----------|
| Detection → Triage | `Xmin` |
| Triage → Mitigation | `Xmin` |
| Mitigation → Resolution | `Xmin` |
| **Total (MTTR)** | **`Xmin`** |

---

## 9. What Went Well

- ✅ Item 1
- ✅ Item 2
- ✅ Item 3

## 10. What Went Wrong

- ❌ Item 1
- ❌ Item 2
- ❌ Item 3

## 11. Lessons Learned

- Lesson 1
- Lesson 2
- Lesson 3

---

## 12. Supporting Evidence

- [Link to Grafana dashboard snapshot]()
- [Link to alert history]()
- [Link to logs]()
- [Link to chat transcript]()
- [Link to related PR/commits]()

---

## 13. Approval

| Role | Name | Date |
|------|------|------|
| Incident Commander | | `YYYY-MM-DD` |
| Engineering Lead | | `YYYY-MM-DD` |
| SRE Lead | | `YYYY-MM-DD` |

---

*This postmortem follows Google SRE best practices: blameless, fact-based, and action-oriented.*
