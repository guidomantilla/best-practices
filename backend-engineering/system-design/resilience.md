# Resilience Patterns

How to survive failures — build systems that degrade gracefully instead of collapsing catastrophically. Cross-level — applies to any architecture.

---

## 1. Design for Failure

Everything will fail. The question is not IF but WHEN and HOW.

### Principles
- **Assume every dependency will fail** — network, database, external APIs, DNS, even time
- **Assume breach** (zero trust) — design as if an attacker is already inside the network. Don't rely on perimeter security. Each service protects itself independently. See `../../zero-trust/`.
- **Fail gracefully** — degraded experience is better than no experience
- **Fail fast** — detect failure quickly, don't wait for timeouts when you can detect immediately
- **Blast radius minimization** — a failure in one component shouldn't cascade to everything. Microsegmentation + per-service auth limits what a compromised component can reach.

### What can fail
- Network (partitions, latency spikes, DNS)
- Dependencies (database, cache, external APIs, message broker)
- Infrastructure (disk full, OOM, CPU exhaustion, cloud provider outage)
- **Security components** (authorization service, policy engine, identity provider) — design for their failure too
- Software (bugs, memory leaks, deadlocks, configuration errors)
- Human (wrong deploy, bad config change, accidental deletion)

---

## 2. Redundancy

Eliminate single points of failure.

| Level | How |
|---|---|
| **Compute** | Multiple instances behind load balancer, across AZs |
| **Data** | Database replicas, cross-region backups, multi-AZ deployments |
| **Network** | Multiple paths, redundant load balancers, multi-CDN |
| **Region** | Active-active or active-passive across regions (for critical systems) |

### Anti-patterns
- Single instance of anything critical (one DB, one Redis, one service instance)
- Redundancy without health checks (two instances but traffic goes to the dead one)
- "We have replicas" but failover is manual (takes 30 minutes in an incident)
- All redundancy in one availability zone (AZ failure takes everything)

---

## 3. Graceful Degradation

When something fails, offer reduced functionality instead of total failure.

### Patterns

| Pattern | Example |
|---|---|
| **Feature degradation** | Search is down → show cached/popular results instead of error |
| **Read from cache** | DB is down → serve stale cached data with "data may be outdated" warning |
| **Fallback service** | Primary payment processor down → route to secondary |
| **Static fallback** | API is down → serve a static pre-generated response |
| **Partial response** | One enrichment service failed → return data without that enrichment, not a 500 |

### Principles
- **Define degradation modes** for each dependency BEFORE an incident (not during)
- **Communicate degradation to the user** (don't silently serve stale data without indication)
- **Prioritize critical paths** — if you must shed load, shed non-critical first (search degrades before checkout)
- **Circuit breaker + fallback** — circuit opens → serve fallback immediately
- **Security component failure** — if the authz/policy engine is down: fail-closed (deny all) is safer, but may not be acceptable for all endpoints. Consider: cached last-known-good decisions with short TTL as fallback, while non-cached requests are denied.

### Anti-patterns
- All-or-nothing (one dependency down = entire system down)
- Silent degradation (serving stale data as if it's fresh — user makes decisions on bad data)
- No pre-planned fallbacks (team invents solutions under incident pressure)

---

## 4. Timeouts & Deadlines

Every external call must have a timeout. No exceptions.

### Types

| Timeout | What it prevents |
|---|---|
| **Connection timeout** | Hanging on unreachable host (3-10s) |
| **Request timeout** | Slow response from dependency (5-30s for web, longer for batch) |
| **End-to-end deadline** | Total time budget for a user request across all hops |

### Deadline propagation
```
User → API Gateway (10s deadline)
  → Service A (8s remaining after gateway processing)
    → Service B (5s remaining)
      → Database (3s remaining)
```

Each hop subtracts its processing time. If deadline is exceeded, cancel and return error immediately (don't continue work nobody will use).

### Principles
- **Set timeouts on EVERY external call** (HTTP, DB, cache, gRPC, message broker)
- **Propagate deadlines** across service boundaries (context deadline in Go, gRPC deadlines)
- **Timeout < client patience** — if user gives up after 10s, your service should timeout before that
- **Cancel work on timeout** — don't let background work continue for a request that already timed out

### Anti-patterns
- No timeout (request hangs forever, connection pool exhausted, cascade failure)
- Timeout too long (30s timeout on a health check — defeats the purpose)
- No deadline propagation (downstream still working on a request that already timed out upstream)
- Timeout without cancellation (response discarded but DB query still running)

---

## 5. Idempotency

Operations that are safe to retry without side effects.

### Why it matters for resilience
- Network fails BETWEEN "request sent" and "response received" → client doesn't know if it succeeded
- Client retries → without idempotency, operation executes twice (double charge, duplicate order)

### Implementation patterns

| Pattern | How |
|---|---|
| **Idempotency key** | Client sends unique key, server stores it, rejects duplicates |
| **Natural idempotency** | Operation is inherently idempotent (SET vs INCREMENT, PUT vs POST) |
| **Deduplication table** | Store processed request IDs, check before processing |
| **Conditional writes** | `UPDATE ... WHERE version = N` (only succeeds once) |

### Principles
- All mutating operations exposed to clients should be idempotent (or provide idempotency key)
- Idempotency is the ONLY way to safely retry in a distributed system
- Store idempotency state durably (not in-memory — survives restarts)

### Anti-patterns
- No idempotency on payment/financial operations (retry = double charge)
- Idempotency key with short TTL (client retries after key expires → duplicate)
- Idempotency only on the first service (downstream still processes twice)

---

## 6. Health Checks & Self-Healing

Systems that detect and recover from their own problems.

### Health check types

| Check | What it answers | Used by |
|---|---|---|
| **Liveness** | Is the process alive and not deadlocked? | K8s (restart if failed) |
| **Readiness** | Can this instance serve traffic? | K8s/LB (remove from rotation if not ready) |
| **Startup** | Has the app finished initializing? | K8s (don't check liveness until ready) |
| **Deep health** | Are all dependencies reachable? | Monitoring, dashboards |

### Self-healing patterns
- **Auto-restart** on liveness failure (K8s, systemd)
- **Auto-replace** failed instances (ASG, K8s ReplicaSet)
- **Auto-failover** database (RDS Multi-AZ, Redis Sentinel)
- **Auto-scale** on resource pressure (HPA, cloud auto-scaling)

### Principles
- Liveness: check the process, NOT dependencies (don't restart because DB is down — you'll restart in a loop)
- Readiness: check dependencies (remove from LB if DB is unreachable — don't send traffic to it)
- Health checks should be fast and cheap (< 100ms, no expensive queries)
- Deep health checks for monitoring only (not for LB decisions — too many false positives)

### Anti-patterns
- Liveness check that depends on external service (cascade restarts when that service is slow)
- No readiness check (instance gets traffic before it's ready — errors during startup)
- Health check endpoint that does real work (adds load, can fail under pressure)
- No health checks at all (dead instances serve traffic, errors for users)

---

## 7. Chaos Engineering

Intentionally inject failures to find weaknesses BEFORE they find you.

### Principles
- **Start in staging** — build confidence before touching production
- **Have a hypothesis** — "if Redis goes down, the service should serve cached data with degraded latency"
- **Minimize blast radius** — test on one instance/one user first, not the whole system
- **Automate rollback** — if the experiment goes wrong, automated abort
- **Measure** — define what "healthy" looks like before breaking things

### Experiments to run

| Experiment | What it tests |
|---|---|
| Kill a service instance | Does traffic reroute? Does the LB detect it? |
| Add network latency (500ms) | Do timeouts trigger correctly? Does circuit breaker open? |
| Kill the database | Does the service degrade gracefully? Do caches work? |
| Fill disk to 100% | Does alerting fire? Does the service handle it? |
| DNS failure | Does the service retry with backoff? Does it recover when DNS returns? |
| Clock skew | Do time-dependent operations (JWT, certs, cron) handle skew? |

### Tooling

| Tool | What it does |
|---|---|
| **Chaos Monkey** (Netflix) | Randomly kill instances in production |
| **Litmus** | K8s-native chaos engineering |
| **Gremlin** | SaaS chaos platform (network, resource, state) |
| **Toxiproxy** | Simulate network conditions (latency, disconnect, bandwidth) |
| **tc** (Linux) | Network traffic control (add latency, packet loss) |

### Anti-patterns
- Chaos in production without monitoring (breaking things without measuring impact)
- No automated rollback (experiment goes wrong, manual intervention needed)
- Only testing instance failure (most real outages are network/latency, not crash)
- "We did chaos once" — it's a continuous practice, not a one-time event

---

## 8. Disaster Recovery

Plan for the worst — regional failure, data corruption, complete outage.

### RPO and RTO

| Metric | What it means | Question |
|---|---|---|
| **RPO** (Recovery Point Objective) | How much data loss is acceptable | "Can we lose the last 5 minutes of data?" |
| **RTO** (Recovery Time Objective) | How long can the system be down | "Can we be offline for 1 hour?" |

### Strategies

| Strategy | RPO | RTO | Cost |
|---|---|---|---|
| **Backup & restore** | Hours (last backup) | Hours (restore time) | Low |
| **Pilot light** | Minutes (replication lag) | Minutes-hours (scale up infra) | Medium |
| **Warm standby** | Seconds-minutes | Minutes (switch traffic) | High |
| **Active-active (multi-region)** | Near-zero | Near-zero (already running) | Very high |

### Principles
- **Define RPO/RTO per service** based on business impact (not everything needs active-active)
- **Test recovery regularly** — untested DR is not DR, it's hope
- **Automate failover** where possible (manual failover during a 3am incident is error-prone)
- **Document the runbook** — step-by-step recovery process that anyone on-call can follow

### Anti-patterns
- No DR plan (find out your backup doesn't restore during a real outage)
- DR plan that's never tested (3 years old, references services that don't exist)
- Active-active without handling split-brain (both regions accept writes — data conflict)
- RPO/RTO defined but not validated against actual recovery time

---

## References

- [Michael T. Nygard — Release It! (2018, 2nd ed)](https://pragprog.com/titles/mnee2/release-it-second-edition/)
- [Netflix — Chaos Engineering Principles](https://principlesofchaos.org/)
- [Google SRE Book — Embracing Risk](https://sre.google/sre-book/embracing-risk/)
- [AWS Well-Architected — Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/)
- [Martin Fowler — Circuit Breaker](https://martinfowler.com/bliki/CircuitBreaker.html)

For the well-architected perspective on reliability, see [`../../well-architected/reliability.md`](../../well-architected/reliability.md).
