# Trade-Off Analysis

Every architecture decision is a trade-off. There are no "best practices" at the architecture level — only **context-dependent decisions with consequences**. Based on Richards/Ford and Bass/Clements/Kazman.

---

## The Core Principle

**"Everything in software architecture is a trade-off."** — Richards/Ford, First Law of Software Architecture

**"Why is more important than how."** — Richards/Ford, Second Law of Software Architecture

If a developer proposes a solution and can't articulate what they're giving up, they haven't analyzed the trade-off.

---

## Common Trade-Offs

### Performance vs Modifiability

| Choose performance | Choose modifiability |
|---|---|
| Tight coupling, optimized data structures | Loose coupling, abstractions, interfaces |
| Inline code, fewer layers | Clean Architecture, hexagonal, multiple layers |
| Denormalized data | Normalized data |
| **When**: latency is critical (trading, gaming, real-time) | **When**: system evolves frequently (SaaS, startup) |

### Consistency vs Availability (CAP)

| Choose consistency | Choose availability |
|---|---|
| Strong consistency (ACID, synchronous replication) | Eventual consistency (BASE, async replication) |
| System may reject requests during partition | System always responds, may return stale data |
| **When**: financial transactions, inventory | **When**: social feeds, recommendations, analytics |

### Coupling vs Duplication

| Choose coupling (share code) | Choose duplication (copy code) |
|---|---|
| Shared library, one source of truth | Each service has its own copy |
| Change once, affects all consumers | Change independently, may drift |
| **When**: truly shared logic (auth, serialization) | **When**: services evolve at different rates, different teams |

### Simplicity vs Flexibility

| Choose simplicity | Choose flexibility |
|---|---|
| Monolith, 3-layer, concrete implementations | Microservices, plugin architecture, interfaces everywhere |
| Fast to build, easy to understand | Adapts to change, swappable components |
| **When**: small team, known problem, short lifespan | **When**: large team, uncertain requirements, long lifespan |

### Cost vs Reliability

| Choose cost | Choose reliability |
|---|---|
| Single instance, single AZ | Multi-instance, multi-AZ, multi-region |
| Manual failover | Automated failover |
| Longer recovery time (RTO) | Near-zero downtime |
| **When**: dev/staging, internal tools, low-impact services | **When**: production, revenue-critical, SLA commitments |

### Autonomy vs Standardization

| Choose autonomy | Choose standardization |
|---|---|
| Each team picks their own stack/tools | Organization mandates stack/tools |
| Innovation, speed for individual teams | Consistency, knowledge sharing, easier hiring |
| **When**: teams are senior, domains are diverse | **When**: teams are mixed-level, cross-team collaboration is frequent |

### Build vs Buy vs Managed

| Build | Buy/Managed |
|---|---|
| Full control, no vendor lock-in | Less ops burden, faster time to market |
| Ongoing maintenance cost (your team) | Ongoing license/service cost (vendor) |
| **When**: it's your core competency, or no product fits | **When**: it's not your differentiator, managed service exists |

---

## Trade-Off Analysis Method

When making an architecture decision:

### 1. Identify the Decision
What exactly are you deciding? Be specific.
- ❌ "Which database should we use?"
- ✅ "Should we use PostgreSQL or DynamoDB for the order management service, given 500 orders/day with complex queries?"

### 2. List Quality Attributes Affected
Which -ilities does this decision impact?
- Performance, scalability, modifiability, cost, reliability, security, testability, deployability...

### 3. Evaluate Each Option Against Each QA

| | Option A: PostgreSQL | Option B: DynamoDB |
|---|---|---|
| **Performance** | Complex queries fast (joins, CTEs) | Key lookups fast, complex queries expensive |
| **Scalability** | Vertical + read replicas | Horizontal, near-infinite |
| **Modifiability** | Schema migrations needed | Schema-less, flexible |
| **Cost** | Predictable (instance-based) | Pay-per-request (unpredictable at scale) |
| **Team expertise** | High | Low |
| **Consistency** | Strong (ACID) | Eventual (by default) |

### 4. Make the Decision Explicit
Document in an ADR (see [adrs.md](adrs.md)):
- What you chose
- What you're gaining
- What you're giving up (consciously)
- Under what conditions you'd revisit

### 5. Define Fitness Functions
How will you know if the decision was right? What would trigger a reassessment?
- "If order volume exceeds 50K/day, revisit database choice"
- "If query latency p99 exceeds 500ms, add read replica or caching layer"

---

## The ATAM Method (Simplified)

Architecture Tradeoff Analysis Method (Bass/Clements/Kazman) — simplified for practical use:

### Steps
1. **Present the architecture** — what does the system look like?
2. **Identify quality attribute drivers** — what matters most? (from stakeholders)
3. **Generate quality attribute scenarios** — concrete, measurable (see [quality-attributes.md](quality-attributes.md))
4. **Analyze architectural approaches** — for each scenario, which tactics/patterns are used?
5. **Identify sensitivity points** — which decisions most affect quality attributes?
6. **Identify trade-off points** — which decisions affect multiple quality attributes in opposing directions?
7. **Document risks and non-risks** — what's well-addressed, what's risky?

### When to Use ATAM
- Major architecture decisions (new system, major refactor, technology migration)
- Multiple stakeholders with competing quality attribute priorities
- The decision is expensive to reverse

### When NOT to Use ATAM
- Small decisions that can be easily changed
- Prototypes and experiments
- Single-developer projects (just use ADRs)

---

## Decision Heuristics

When the analysis is inconclusive, these heuristics help:

| Heuristic | What it means |
|---|---|
| **Prefer reversible decisions** | If you can easily change later, pick the simpler option now |
| **Defer until the last responsible moment** | Don't decide until you have enough information, but don't delay past the point where delay is costly |
| **Start simple, evolve** | Monolith → modular → extract services (not the reverse) |
| **Optimize for the constraint** | Which quality attribute is MOST critical? Optimize for that, accept trade-offs on others |
| **Conway's Law** | Your architecture will mirror your team structure — design for the team you have |
| **Second-system syndrome** | Beware of over-engineering the second version based on all the lessons of the first |

---

## Anti-patterns

- **"Best practice" without context**: "always use microservices" / "always use event sourcing" — trade-offs ignored
- **Analysis paralysis**: analyzing forever, never deciding — a reversible bad decision is better than no decision
- **Resume-driven decisions**: choosing technology because it looks good on a resume, not because it fits
- **No documentation**: decision made, reasons forgotten in 3 months
- **Ignoring team expertise**: technically optimal choice that nobody on the team knows how to operate
- **Sunk cost fallacy**: "we already built X, so we must keep using it" — even when Y is clearly better now
- **Cargo culting**: "Netflix uses Kafka, so we should too" — without Netflix's problems or scale
- **One-size-fits-all**: same architecture for every service regardless of requirements

---

## References

- [Richards, Ford — Chapter 19-20: Architecture Decisions, Trade-Off Analysis](https://www.oreilly.com/library/view/fundamentals-of-software/9781098175504/)
- [Bass, Clements, Kazman — ATAM (Chapter 21)](https://www.sei.cmu.edu/library/software-architecture-in-practice-fourth-edition/)
- [Martin Fowler — Trade-Offs in Distributed Systems](https://martinfowler.com/articles/patterns-of-distributed-systems/)
