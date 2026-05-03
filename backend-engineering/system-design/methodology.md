# Architecture Methodology

How to make, document, and validate architecture decisions. Tools for thinking about architecture — not patterns, but process.

For the full framework, see [`../../well-architected/`](../../well-architected/README.md).

---

## 1. Quality Attribute Scenarios

Non-functional requirements must be **measurable**, not vague.

### The problem
- ❌ "The system should be fast"
- ❌ "The system should be highly available"
- ❌ "The system should be secure"

These are useless — nobody can build to them, nobody can verify them.

### The solution: QA scenarios

```
Source:      [who/what triggers it]
Stimulus:    [what happens]
Artifact:    [what part of the system]
Environment: [under what conditions]
Response:    [what the system does]
Measure:     [how to verify — the number]
```

### Examples

**Performance:**
```
Source:      1000 concurrent users
Stimulus:   Submit checkout request
Artifact:   Order service
Environment: Peak hours, normal operation
Response:   Order is processed and confirmed
Measure:    p99 latency < 500ms, throughput > 200 orders/sec
```

**Availability:**
```
Source:      Primary database
Stimulus:   Instance crashes
Artifact:   User-facing API
Environment: Normal operation
Response:   Failover to replica, continue serving
Measure:    < 30s downtime, zero data loss
```

**Modifiability:**
```
Source:      Development team
Stimulus:   Add new payment provider
Artifact:   Payment module
Environment: Development
Response:   Integrated without modifying existing providers
Measure:    < 2 days, no regression
```

### Why this matters
- Turns vague requirements into testable specifications
- Drives architecture decisions (the scenario tells you what the architecture must support)
- Feeds fitness functions (the "measure" becomes an automated test)
- Enables trade-off conversations ("p99 < 100ms AND five-nines costs $X — is it worth it?")

For the full -ilities catalog and prioritization framework, see [`../../well-architected/quality-attributes.md`](../../well-architected/quality-attributes.md).

---

## 2. Architecture Decision Records (ADRs)

Document **why** you made a decision, not just what you decided.

### When to write an ADR
- Hard to reverse (choosing a database, framework, messaging system)
- Affects multiple teams or services
- Involves significant trade-offs
- Will be questioned later ("why Kafka over SQS?")

### Template (lightweight)

```markdown
# ADR-{number}: {Title}

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-{number}]

## Context
What problem are we solving? What constraints exist?

## Decision
What did we decide?

## Alternatives Considered
- Alternative A: pros, cons, why rejected
- Alternative B: pros, cons, why rejected

## Consequences
- Positive: what we gain
- Negative: what trade-offs we accept
- Risks: what could go wrong, when to revisit
```

### Example

```markdown
# ADR-007: Use PostgreSQL as Primary Database

## Status: Accepted

## Context
Order management service. ~500 orders/day, complex queries (joins across
orders, items, customers). Relational data, strong consistency required.

## Decision
PostgreSQL (managed via AWS RDS).

## Alternatives Considered
- MongoDB: flexible schema, but data is relational — $lookup is expensive
- DynamoDB: infinite scale, but complex ad-hoc queries are impractical

## Consequences
- Positive: ACID, rich queries, team expertise, mature ecosystem
- Negative: vertical scaling limits at high scale, RDS vendor lock-in
- Risks: if volume grows 100x, need read replicas or caching layer
```

### Principles
- **Write at decision time** — context is fresh, alternatives remembered
- **Include rejected alternatives** — the most valuable part
- **Keep short** — one page, not a thesis
- **Never edit old ADRs** — write a new one that supersedes
- **ADRs live in git** — next to the code, versioned, reviewable

### Where they live
```
/docs/adrs/
  0001-use-postgresql.md
  0002-adopt-event-driven-for-notifications.md
  0003-switch-from-rest-to-grpc-internal.md
```

For the full ADR guide with lifecycle and tooling, see [`../../well-architected/adrs.md`](../../well-architected/adrs.md).

---

## 3. Trade-Off Analysis

Every architecture decision has a cost. If you can't articulate what you're giving up, you haven't analyzed the trade-off.

### Common trade-offs

| Trade-off | Choose A when | Choose B when |
|---|---|---|
| **Performance vs Modifiability** | Latency is critical (trading, gaming) | System evolves frequently (SaaS) |
| **Consistency vs Availability** | Financial transactions, inventory | Social feeds, analytics |
| **Coupling vs Duplication** | Truly shared logic (auth library) | Services evolve independently |
| **Simplicity vs Flexibility** | Small team, known problem | Large team, uncertain requirements |
| **Cost vs Reliability** | Dev/staging, internal tools | Production, revenue-critical |
| **Autonomy vs Standardization** | Senior teams, diverse domains | Mixed-level teams, frequent collaboration |
| **Managed vs Self-hosted** | Zero ops capacity, regulatory need | Any scale where you have ops competence — self-hosted is cheaper. Cloud vendors recommend managed because they sell managed. |

### Method

1. **Identify the decision** specifically (not "which DB" but "PostgreSQL vs DynamoDB for order service with 500 orders/day and complex queries")
2. **List quality attributes affected** (performance, cost, modifiability, scalability...)
3. **Evaluate each option against each QA** (table format)
4. **Make the decision explicit** → document in ADR
5. **Define fitness functions** → how will you know if the decision was right?
6. **Define reassessment triggers** → "revisit if order volume exceeds 50K/day"

### Heuristics when analysis is inconclusive

| Heuristic | What it means |
|---|---|
| **Prefer reversible** | If you can easily change later, pick simpler now |
| **Defer until last responsible moment** | Don't decide until you have enough info |
| **Start simple, evolve** | Monolith → modular → extract services |
| **Optimize for the constraint** | Which QA is MOST critical? Optimize for that. |
| **Conway's Law** | Architecture will mirror team structure — design for the team you have |

### Anti-patterns
- "Best practice" without context ("always use microservices")
- Analysis paralysis (analyzing forever, never deciding)
- Resume-driven decisions (choosing tech for the resume, not the problem)
- Cargo culting ("Netflix uses Kafka, so should we" — without Netflix's problems)
- Ignoring team expertise (optimal choice nobody can operate)

For the full trade-off analysis framework and ATAM method, see [`../../well-architected/trade-off-analysis.md`](../../well-architected/trade-off-analysis.md).

---

## 4. Fitness Functions

Automated tests that validate architecture characteristics are maintained over time. Architecture degrades through thousands of small decisions — fitness functions catch the degradation in CI.

### Categories

| Category | What it validates | Example | Tools |
|---|---|---|---|
| **Structural** | Dependency direction, layer violations, circular deps | Domain doesn't import infrastructure | ArchUnit, go-arch-lint, dependency-cruiser |
| **Performance** | Latency budgets, bundle size, query time | p99 < 200ms, bundle < 200KB | k6, size-limit, Lighthouse CI |
| **Security** | All routes have auth, no secrets in code, no critical CVEs | Every endpoint has auth middleware | Custom test, Gitleaks, Trivy |
| **Maintainability** | Complexity, function length, duplication | Cyclomatic complexity < 15 | golangci-lint, ESLint, jscpd |
| **Operational** | Resources tagged, IaC drift, Dockerfile quality | All cloud resources have team tag | Checkov, Hadolint |

### How to implement

```
CI Pipeline:
  Lint + Fitness Functions → Test → Build → Scan → Deploy
           ↑
    Fail the build if architecture degrades
```

### Start small
1. Pick the **3 architecture rules** your team cares about most
2. Write automated checks for those 3
3. Run in CI, fail the build on violation
4. Add more as architecture evolves

### Anti-patterns
- Fitness functions as warnings (not failures — ignored)
- Too many at once (team rebels, disables all)
- Static thresholds that never evolve
- No fitness functions at all (architecture erodes by default)

For the full fitness functions guide with examples per category, see [`../../well-architected/fitness-functions.md`](../../well-architected/fitness-functions.md).

---

## 5. Cost as a Quality Attribute

Cost is not just a finance concern — it's an architecture decision. Every technical choice has a cost implication.

### What devs should consider

| Decision | Cost implication |
|---|---|
| **Monolith vs microservices** | More services = more instances, networking, observability cost |
| **Managed vs self-hosted** | Managed = higher per-unit cost, lower ops time. Self-hosted = cheaper at any scale where you have ops competence. Cloud vendors recommend managed because they sell it. |
| **Sync vs async** | Async adds messaging infra cost — worth it at scale, not for 100 req/day |
| **Multi-region** | 2x+ infrastructure cost — only when reliability requires it |
| **Cache layer** | Redis costs money — only add if it reduces enough DB load to justify |
| **Observability** | Every log line, metric, trace has a cost — instrument for insight, not completeness |

### Performance budgets with cost awareness

| Budget | Target | Enforce | Cost link |
|---|---|---|---|
| p99 latency | < 200ms | k6 in CI, RUM alerts | Scaling to hit latency target has compute cost |
| Bundle size | < 200KB gzipped | size-limit in CI | Larger bundles = more CDN egress cost |
| Query time | < 100ms (hot path) | pg_stat_statements alert | Slow queries = more DB compute, or need cache (Redis cost) |
| Log volume | < 5GB/day | Observability cost alert | $1.70/GB (Datadog) vs $0.10/GB (Loki) — 17x difference |

### Principles
- **Cost is visible** — tag resources, track per-service, review monthly
- **Cost is a trade-off** — not a constraint. Spending more is OK if justified by the QA it enables.
- **Right-size, don't over-provision** — monitor actual usage, auto-scale instead of pre-provisioning peak
- **Question managed services** — calculate total cost of ownership, not just sticker price
- **Dev/test environments cost money too** — scale down, schedule, use spot instances

For the full cost optimization framework, see [`../../well-architected/cost-optimization.md`](../../well-architected/cost-optimization.md).

---

## References

- [Richards, Ford — Fundamentals of Software Architecture (2nd ed, 2024)](https://www.oreilly.com/library/view/fundamentals-of-software/9781098175504/)
- [Bass, Clements, Kazman — Software Architecture in Practice (4th ed, 2021)](https://www.sei.cmu.edu/library/software-architecture-in-practice-fourth-edition/)
- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
