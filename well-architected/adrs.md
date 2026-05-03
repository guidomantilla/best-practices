# Architecture Decision Records (ADRs)

How to document architecture decisions so that future you (and the next team) understands WHY, not just WHAT.

---

## What is an ADR

A short document that captures a single architecture decision:
- **What** was decided
- **Why** it was decided (context, constraints, drivers)
- **What alternatives** were considered and rejected
- **What trade-offs** were accepted

ADRs are immutable — you don't edit an old ADR. If the decision changes, you write a new ADR that supersedes the old one.

---

## When to Write an ADR

Write an ADR when the decision:
- Is hard to reverse (choosing a database, a framework, a messaging system)
- Affects multiple teams or services
- Involves significant trade-offs (cost vs performance, consistency vs availability)
- Will be questioned later ("why did we choose Kafka over SQS?")
- Changes a previous decision

Don't write an ADR for:
- Trivial decisions (tab vs spaces, variable naming)
- Decisions the framework makes for you (React uses JSX — not a decision you made)
- Temporary experiments that will be discarded

---

## Template

```markdown
# ADR-{number}: {Title}

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-{number}]

## Date
{YYYY-MM-DD}

## Context
What is the situation? What problem are we solving? What constraints exist?

## Decision
What did we decide?

## Alternatives Considered
### Alternative A: {name}
- Pros: ...
- Cons: ...
- Why rejected: ...

### Alternative B: {name}
- Pros: ...
- Cons: ...
- Why rejected: ...

## Consequences
### Positive
- ...

### Negative (trade-offs accepted)
- ...

### Risks
- ...

## References
- Links to relevant docs, RFCs, tickets
```

---

## Example

```markdown
# ADR-007: Use PostgreSQL as Primary Database

## Status
Accepted

## Date
2026-03-15

## Context
We need a primary database for the order management service. The service handles
~500 orders/day with complex queries (joins across orders, items, customers,
payments). Data is relational with strong consistency requirements (financial data).
Team has experience with PostgreSQL and MySQL.

## Decision
Use PostgreSQL (managed, via AWS RDS).

## Alternatives Considered

### MySQL (RDS)
- Pros: team has some experience, widely supported
- Cons: weaker JSON support, fewer advanced features (CTEs, window functions)
- Why rejected: PostgreSQL has better feature set for our query patterns

### MongoDB
- Pros: flexible schema, good for rapid iteration
- Cons: no ACID across collections, data is relational (orders → items → customers),
  joins via $lookup are expensive
- Why rejected: data model is inherently relational, MongoDB would force denormalization
  that doesn't match our access patterns

### DynamoDB
- Pros: managed, scales infinitely, pay-per-request
- Cons: no joins (all data modeling via single-table design), team has no experience,
  complex queries require GSIs
- Why rejected: access patterns include complex ad-hoc queries that DynamoDB handles poorly

## Consequences

### Positive
- Strong consistency (ACID transactions across tables)
- Rich query capabilities (CTEs, window functions, full-text search)
- Team expertise reduces learning curve
- Mature ecosystem (tooling, ORMs, monitoring)

### Negative (trade-offs accepted)
- Vertical scaling limits (will need read replicas or sharding at scale)
- Managed RDS costs more than self-hosted (accepted for operational simplicity)
- Single-region by default (multi-region requires additional architecture)

### Risks
- If order volume grows 100x, may need to introduce read replicas or caching layer
- RDS maintenance windows may cause brief unavailability (mitigated by Multi-AZ)
```

---

## Where ADRs Live

```
/docs
  /adrs
    0001-use-postgresql.md
    0002-adopt-event-driven-for-notifications.md
    0003-switch-from-rest-to-grpc-internal.md
    ...
```

Or in a `decisions/` folder at the repo root. The key: they live in version control, next to the code.

---

## ADR Lifecycle

```
Proposed → Accepted → [lives as reference]
                   → Deprecated (no longer relevant — system changed)
                   → Superseded by ADR-{new} (decision was revisited)
```

Old ADRs are never deleted or edited. They form a **decision log** — the history of architectural evolution.

---

## Lightweight ADRs

For smaller decisions, a full template is overkill. A lightweight format:

```markdown
# ADR: Use Redis for Session Storage

**Context**: Sessions need sub-ms read latency, shared across service instances.
**Decision**: Redis (ElastiCache) with 24h TTL.
**Alternatives rejected**: PostgreSQL (too slow for session reads), in-memory (not shared across instances).
**Trade-off**: Redis adds an infrastructure component to manage.
```

4-5 lines. Still captures the why. Better than nothing.

---

## Principles

- **Document the WHY, not just the WHAT** — "we use Kafka" is useless without "because we need ordered, durable event streaming with multiple consumers"
- **Write at decision time, not after** — context is fresh, alternatives are remembered
- **Include rejected alternatives** — the most valuable part of an ADR is WHY you didn't choose the other options
- **Keep them short** — one page, not a thesis. If it takes more than 30 minutes to write, the decision isn't clear yet.
- **Review in PRs** — ADRs go through code review like any other artifact

---

## Anti-patterns

- No ADRs at all (6 months later: "why did we choose this?" — nobody remembers)
- ADRs that only state the decision without context or alternatives (useless)
- ADRs written retroactively months later (context lost, alternatives forgotten)
- ADRs in Confluence/wiki (not versioned with code, rot and become invisible)
- Editing old ADRs instead of writing new ones (history lost)
- ADRs for every trivial decision (noise — nobody reads them)
- ADR approval as a bureaucratic gate (should enable decisions, not slow them down)

---

## Tooling

| Tool | What it does |
|---|---|
| **adr-tools** | CLI to create, list, and manage ADRs (shell scripts) |
| **Log4brains** | ADR management + visualization (web UI from markdown ADRs) |
| **Markdown + git** | Simplest — just markdown files in a folder, versioned with git |

---

## References

- [Michael Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub Organization](https://adr.github.io/)
- [Joel Parker Henderson — Architecture Decision Record (collection of templates)](https://github.com/joelparkerhenderson/architecture-decision-record)
