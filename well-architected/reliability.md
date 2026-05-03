# Reliability

How to ensure a system performs its intended function correctly and consistently, and recovers quickly from failures.

---

## Principles

- **Design for failure**: everything fails — design so the system survives it
- **Automatically recover from failure**: detect, respond, recover — without human intervention where possible
- **Test recovery procedures**: untested recovery is not recovery, it's hope
- **Scale horizontally**: increase aggregate capacity, not individual instance capacity
- **Stop guessing capacity**: monitor, measure, auto-scale based on demand

---

## Design Principles (Converged AWS/Azure/GCP)

### 1. Fault Tolerance

Build so that a single failure doesn't cascade:

- **Redundancy**: no single points of failure (multiple instances, multi-AZ, replicas)
- **Isolation**: failure in component A doesn't take down component B (bulkhead pattern)
- **Circuit breakers**: stop calling a failing dependency, fail fast with fallback
- **Timeouts on everything**: no unbounded waits — connection, query, request, end-to-end deadline
- **Idempotency**: operations safe to retry without side effects
- **Graceful degradation**: offer reduced functionality instead of total failure

### 2. Recovery

When things fail, recover fast:

| Concept | What it means |
|---|---|
| **RTO** (Recovery Time Objective) | How long can the system be down? |
| **RPO** (Recovery Point Objective) | How much data loss is acceptable? |
| **MTTR** (Mean Time to Recover) | Average time from incident to resolution |

- **Automated failover**: database, DNS, load balancer — switch without human intervention
- **Rollback capability**: deploy previous known-good version in minutes, not hours
- **Backup and restore**: automated, tested, with defined RPO
- **Disaster recovery plan**: documented, practiced, with clear RTO/RPO per service

### 3. Change Management

Most outages are caused by changes:

- **Small, frequent deployments**: reduce blast radius per change
- **Automated testing before deploy**: catch failures before production
- **Progressive rollout**: canary/blue-green — validate with real traffic before full rollout
- **Automated rollback**: health checks fail → revert automatically
- **Change tracking**: every change is auditable (who, what, when, why)

### 4. Monitoring & Alerting for Reliability

- **SLIs** (Service Level Indicators): the metrics that define "healthy" (latency, error rate, availability)
- **SLOs** (Service Level Objectives): the targets for those metrics (p99 < 200ms, 99.9% availability)
- **Error budgets**: acceptable amount of unreliability — spend it on velocity, save it during instability
- **Alert on SLO burn rate**: "at this rate we'll exhaust our error budget in 2 hours" — not threshold alerts

### 5. Testing Reliability

| Test type | What it validates |
|---|---|
| **Failover testing** | Does traffic reroute when an instance dies? |
| **Chaos engineering** | Does the system behave as expected under failure conditions? |
| **Load testing** | Where does the system break under pressure? |
| **DR drills** | Can we recover from a regional failure within RTO? |
| **Game days** | Can the team respond to incidents effectively? |

### 6. Data Durability

- Backups automated and tested (restore regularly — don't wait for an incident)
- Replication across availability zones
- Point-in-time recovery where available
- Deletion protection on critical resources
- Backup retention aligned with RPO requirements

---

## Checklist

```
[ ] No single points of failure in critical path
[ ] Automated failover for databases and critical services
[ ] Circuit breakers on all external dependencies
[ ] Timeouts set on all external calls
[ ] Health checks (liveness + readiness) on all services
[ ] SLIs and SLOs defined for critical services
[ ] Rollback mechanism exists and has been tested
[ ] Backups automated and restore tested regularly
[ ] DR plan exists with defined RTO/RPO
[ ] Chaos/failure testing conducted periodically
[ ] Multi-AZ deployment for production
[ ] Error budget tracked and used for velocity decisions
```

---

## Anti-patterns

- "It hasn't failed yet" as a reliability strategy
- Single-AZ deployment for production services
- No health checks (dead instances serve traffic)
- Timeout of 30 seconds on a health check (defeats the purpose)
- Backups that have never been restored (unknown if they work)
- DR plan written 3 years ago, references services that no longer exist
- Same person who causes the incident is the only one who can fix it
- Over-engineering for five-nines when three-nines is sufficient (unnecessary cost and complexity)
- No error budget (reliability team and feature team are permanently in conflict)

---

## References

- [AWS — Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/)
- [Azure — Reliability](https://learn.microsoft.com/en-us/azure/well-architected/reliability/)
- [Google — Reliability](https://cloud.google.com/architecture/framework/reliability)
- [Google SRE Book — Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
