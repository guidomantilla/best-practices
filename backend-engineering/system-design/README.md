# System Design Best Practices

Principles for designing software systems — from code structure inside a module to the topology of a distributed system. Organized by **zoom level**, not by pattern taxonomy.

This is the **index**. Each level has its own file.

---

## Reading order

Read the four zoom levels in order, smallest to largest:

1. [`code-level.md`](code-level.md) — patterns inside a class or module (GoF, idioms).
2. [`application-level.md`](application-level.md) — how code is organized inside one deployable (Clean, Hexagonal, layered, package boundaries).
3. [`integration-level.md`](integration-level.md) — how services coordinate and communicate (EIP, sagas, event-driven, service mesh).
4. [`system-level.md`](system-level.md) — global topology (monolith, microservices, serverless, event-driven, hybrid).

Each level builds vocabulary the next one assumes. If you're new to the repo, this sequence is the shortest path from "what's a pattern" to "what's an architecture".

Then there are three cross-level files. They aren't levels — they apply across all four:

- [`scalability.md`](scalability.md) and [`resilience.md`](resilience.md) are **quality-attribute lenses**. Read them after you have the four zoom levels in mind, and apply each lens to the level you're currently working at (e.g. *"how does this integration pattern hold up under 10× load?"* / *"what fails first when this dependency goes down?"*).
- [`methodology.md`](methodology.md) is the **meta layer** — ADRs, fitness functions, trade-off analysis, quality-attribute scenarios. Read it when you're about to make a decision and need a record of why you chose this design instead of the alternatives.

If you're not new and just want to look something up, the **Scope** table below maps every file to the question it answers.

---

## Well-Architected Pillars

A well-architected system addresses these pillars explicitly. Each links to where the content lives in this repo.

| Pillar | Where it's covered |
|---|---|
| **Operational Excellence** | [`../ci-cd/`](../ci-cd/README.md) (pipelines, deployment, DORA) · [`../iac/`](../iac/README.md) (infrastructure as code) · [`../observability/`](../observability/README.md) (monitoring, alerting, runbooks) |
| **Security** | [`../secure-coding/`](../secure-coding/README.md) (12 areas + CORS/gateway) · [`../../zero-trust/`](../../zero-trust/README.md) (CISA ZTMM) |
| **Reliability** | [resilience.md](resilience.md) (fault tolerance, DR, chaos, assume breach) |
| **Performance** | [scalability.md](scalability.md) (scaling, load balancing, caching, async, auto-scaling) · [`../observability/`](../observability/README.md) (RED/USE metrics) · [`../data-design/`](../data-design/README.md) (queries, indexing, caching) |
| **Cost** | [methodology.md](methodology.md) §5 (cost as quality attribute) · [`../observability/`](../observability/README.md) §12 (observability cost) · [`../data-design/lifecycle.md`](../data-design/lifecycle.md) (storage tiering, retention) |

For the full framework with checklists and cloud-provider convergence, see [`../../well-architected/`](../../well-architected/README.md).

---

## Scope

| File | Zoom level | Question it answers |
|---|---|---|
| [code-level.md](code-level.md) | Inside a class/module | How do I solve this recurring problem in code? |
| [application-level.md](application-level.md) | Inside ONE deployable | How do I organize code inside my service? |
| [integration-level.md](integration-level.md) | Between deployables | How do my services coordinate and communicate? |
| [system-level.md](system-level.md) | Global topology | How many deployables, what's the overall architecture? |
| [scalability.md](scalability.md) | Cross-level | How do I handle more load? |
| [resilience.md](resilience.md) | Cross-level | How do I survive failures? |
| [methodology.md](methodology.md) | Cross-level | How do I make and validate architecture decisions? |

---

## The Zoom Levels

```
┌─────────────────────────────────────────────────────┐
│  System Level                                       │
│  (Microservices, Monolith, Event-Driven, Serverless)│
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │  Integration Level                          │    │
│  │  (Saga, Circuit Breaker, CDC, Router)       │    │
│  │                                             │    │
│  │  ┌─────────────────────────────────┐        │    │
│  │  │  Application Level              │        │    │
│  │  │  (Clean, Hexagonal, Layers)     │        │    │
│  │  │                                 │        │    │
│  │  │  ┌───────────────────────┐      │        │    │
│  │  │  │  Code Level           │      │        │    │
│  │  │  │  (GoF Patterns)       │      │        │    │
│  │  │  └───────────────────────┘      │        │    │
│  │  └─────────────────────────────────┘        │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

### Key insight
The same concept can manifest at different zoom levels:
- **CQRS**: application-level (separate read/write models in one service) OR system-level (separate read/write services)
- **Event Sourcing**: application-level (persistence pattern) OR integration-level (events as communication)
- **Circuit Breaker**: code-level (library pattern) OR integration-level (service mesh feature)

When this happens, the pattern is mentioned at each relevant level with a note about where else it applies.

---

## Cross-Cutting Principles

### 1. Complexity Budget

Every system has a complexity budget. Spend it wisely.

- Simple problems deserve simple solutions (monolith for 3 developers, not microservices)
- Complexity should be proportional to the problem's actual difficulty
- Each architectural pattern adds complexity — only adopt it when the benefit exceeds the cost
- "We might need it later" is not sufficient justification for added complexity today

### 2. Reversibility

Prefer decisions that are easy to reverse.

- Monolith → microservices is easier than microservices → monolith
- Internal API → public API is easier than changing a public API
- Adding a component is easier than removing one (coupling accumulates)
- When uncertain, choose the option that's cheapest to change later

### 3. Boundaries

Good architecture is about drawing boundaries in the right places.

- Boundaries separate things that change for different reasons
- Boundaries protect fast-changing code from slow-changing code
- A boundary is expensive — don't draw one unless you have a reason
- Wrong boundaries are worse than no boundaries (coordinate changes across boundaries)

### 4. Trade-offs, Not Best Practices

At the system level, there are no universally "right" answers — only trade-offs.

- Consistency vs availability
- Coupling vs duplication
- Performance vs simplicity
- Flexibility vs predictability
- Autonomy vs standardization

Document WHY you made a decision, not just what you decided. Future you (or the next team) needs to understand the trade-off context.

---

## How to Use This Reference

- Building a new service? Start with `application-level.md` (internal structure) + `system-level.md` (where it fits in the topology)
- Solving a specific code problem? Check `code-level.md` (GoF patterns)
- Services struggling to communicate? Check `integration-level.md` (EIP patterns)
- System falling over under load? Check `scalability.md` + `resilience.md`

---

## References

- [Martin Fowler — Patterns of Enterprise Application Architecture (2002)](https://martinfowler.com/eaaCatalog/)
- [Erich Gamma et al. — Design Patterns: Elements of Reusable OO Software (1994)](https://en.wikipedia.org/wiki/Design_Patterns)
- [Gregor Hohpe & Bobby Woolf — Enterprise Integration Patterns (2003)](https://www.enterpriseintegrationpatterns.com/)
- [Sam Newman — Building Microservices (2021, 2nd ed)](https://samnewman.io/books/building_microservices_2nd_edition/)
- [Martin Kleppmann — Designing Data-Intensive Applications (2017)](https://dataintensive.net/)
- [Robert C. Martin — Clean Architecture (2017)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Heroku — The Twelve-Factor App](https://12factor.net/)
