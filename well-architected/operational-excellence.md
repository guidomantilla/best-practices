# Operational Excellence

How to run, monitor, and continuously improve systems and processes.

---

## Principles

- **Operations as code**: everything that can be automated should be — deployments, monitoring, incident response, infrastructure
- **Make frequent, small, reversible changes**: small deployments reduce risk and make rollback trivial
- **Refine operations frequently**: after incidents, after releases, after scaling events — learn and improve
- **Anticipate failure**: pre-mortems, runbooks, game days — prepare for what will go wrong
- **Learn from all operational events**: not just failures — successes and near-misses are learning opportunities too

---

## Design Principles (Converged AWS/Azure/GCP)

### 1. Automate Everything

| Area | Manual (bad) | Automated (good) |
|---|---|---|
| Deployments | SSH + scripts | CI/CD pipeline |
| Infrastructure | Console clicks | IaC (Terraform, Pulumi) |
| Monitoring setup | Manual dashboard creation | Dashboards as code, auto-discovery |
| Incident response | Human reads alert, decides action | Automated runbooks, auto-remediation |
| Scaling | Human adds instances | Auto-scaling policies |
| Configuration | Manual edits on servers | Config as code, GitOps |

### 2. Observability

Know the state of your system at all times:
- **Logs**: structured, centralized, searchable — what happened
- **Metrics**: RED (services), USE (infrastructure) — how is it behaving
- **Traces**: distributed, correlated — where did time go
- **Alerts**: actionable, SLO-based — what needs attention

Anti-pattern: dashboards that nobody looks at, alerts that nobody acts on, logs that nobody searches.

### 3. Safe Deployments

- Deploy frequently (daily or more) in small increments
- Automated testing before deploy (unit, integration, API, security scans)
- Progressive rollout (canary, blue-green, feature flags)
- Automated rollback on failure (health check fails → revert automatically)
- Immutable artifacts (build once, deploy same artifact everywhere)

### 4. Incident Management

| Phase | What happens |
|---|---|
| **Detect** | Monitoring/alerting identifies the issue (automated, not user-reported) |
| **Respond** | On-call acknowledges, follows runbook, communicates status |
| **Mitigate** | Restore service (rollback, failover, scale, disable feature flag) |
| **Resolve** | Fix root cause |
| **Learn** | Blameless post-mortem, update runbooks, improve monitoring |

### 5. Runbooks

Every alert should have a runbook:
- **What**: description of the alert and what it means
- **Impact**: who/what is affected
- **Steps**: diagnostic steps, mitigation actions, escalation path
- **Resolution**: how to fix permanently (not just mitigate)

Anti-pattern: alert fires, on-call engineer has no idea what to do, spends 30 minutes figuring out what the alert even means.

### 6. Continuous Improvement

- **Blameless post-mortems**: after every incident — what happened, why, how to prevent
- **Operational reviews**: periodic review of metrics, alerts, deployment frequency, MTTR
- **Toil reduction**: identify repetitive manual work, automate it
- **DORA metrics**: measure deployment frequency, lead time, change failure rate, MTTR — track trends

---

## Checklist

```
[ ] Deployments are automated via CI/CD pipeline
[ ] Infrastructure is managed as code (no manual console changes)
[ ] Monitoring covers logs, metrics, traces — centralized
[ ] Alerts are actionable with runbooks
[ ] Incident response process is defined and practiced
[ ] Post-mortems are conducted after incidents
[ ] Rollback is automated and tested
[ ] DORA metrics are tracked
[ ] On-call rotation is defined
[ ] Configuration changes are versioned and reviewable
```

---

## Anti-patterns

- "It works on my machine" (no parity between environments)
- Deploying on Fridays without automated rollback
- Alert fatigue (hundreds of alerts, nobody acts on any)
- No post-mortems (same incident repeats every quarter)
- Manual deployments that take 2 hours and a checklist
- "The one person who knows how to deploy" (bus factor = 1)
- Toil accepted as normal ("that's just how it works here")

---

## References

- [AWS — Operational Excellence Pillar](https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/)
- [Azure — Operational Excellence](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/)
- [Google — Operational Excellence](https://cloud.google.com/architecture/framework/operational-excellence)
- [Google SRE Book](https://sre.google/sre-book/table-of-contents/)
