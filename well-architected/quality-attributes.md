# Quality Attributes

The "-ilities" — non-functional requirements that define how a system behaves, not what it does. Based on Bass/Clements/Kazman (*Software Architecture in Practice*) and Richards/Ford (*Fundamentals of Software Architecture*).

---

## What Are Quality Attributes

Functional requirements define WHAT the system does ("user can place an order").
Quality attributes define HOW WELL it does it ("order placement responds in < 200ms at p99 under 1000 concurrent users").

Architecture is primarily driven by quality attributes, not functional requirements. Most functional requirements can be implemented in any architecture. Quality attributes constrain which architectures are viable.

---

## The -ilities Catalog

| Quality Attribute | What it means | Tension with |
|---|---|---|
| **Availability** | System is operational when needed (uptime) | Cost, simplicity |
| **Scalability** | System handles increased load | Cost, simplicity, consistency |
| **Performance** | System responds within acceptable time/throughput | Cost, modifiability |
| **Reliability** | System performs correctly over time | Cost, performance |
| **Security** | System protects against unauthorized access and data breach | Usability, performance |
| **Modifiability** | System can be changed easily (new features, refactoring) | Performance (abstractions cost) |
| **Testability** | System can be easily tested at all levels | Simplicity (DI, interfaces add structure) |
| **Deployability** | System can be deployed frequently with low risk | Simplicity, coupling |
| **Observability** | System's internal state can be understood from external outputs | Cost, performance |
| **Interoperability** | System can exchange data with other systems | Coupling, simplicity |
| **Usability** | System is easy and efficient for users to interact with | Development time |
| **Maintainability** | System can be maintained, debugged, and evolved over time | Up-front development time |
| **Portability** | System can run in different environments | Performance (abstractions), complexity |
| **Elasticity** | System scales up AND down automatically with demand | Cost of auto-scaling infrastructure |

### Key insight: you can't have them all

Every system must choose which quality attributes matter most. Optimizing for one often degrades another:

- High **availability** requires redundancy → increases **cost**
- High **security** requires auth/encryption → impacts **performance** and **usability**
- High **modifiability** requires abstractions → may reduce **performance**
- High **performance** may require tight coupling → reduces **modifiability**

This is why trade-off analysis matters — see [trade-off-analysis.md](trade-off-analysis.md).

---

## Quality Attribute Scenarios

The formal way to specify a quality attribute requirement (Bass). Not "the system should be fast" but a structured scenario:

### Template

```
Source:    [who/what triggers it]
Stimulus:  [what happens]
Artifact:  [what part of the system is affected]
Environment: [under what conditions]
Response:  [what the system does]
Measure:   [how to verify]
```

### Examples

**Performance:**
```
Source:     1000 concurrent users
Stimulus:  Submit checkout request
Artifact:  Order service
Environment: Normal operation, peak hours
Response:  Order is processed and confirmed
Measure:   p99 latency < 500ms, throughput > 200 orders/sec
```

**Availability:**
```
Source:     Primary database
Stimulus:  Instance crashes
Artifact:  User-facing API
Environment: Normal operation
Response:  System fails over to replica, continues serving requests
Measure:   < 30 seconds downtime, zero data loss (RPO = 0)
```

**Security:**
```
Source:     Unauthenticated external user
Stimulus:  Attempts to access admin API
Artifact:  API Gateway
Environment: Normal operation
Response:  Request rejected with 401
Measure:   100% of unauthenticated requests blocked, logged, alerted after N attempts
```

**Modifiability:**
```
Source:     Development team
Stimulus:  Add a new payment provider
Artifact:  Payment module
Environment: Development
Response:  New provider integrated without modifying existing providers
Measure:   Change requires < 2 days, no regression in existing providers
```

### Why scenarios matter
- **Turns vague requirements into testable specifications** — "the system should be reliable" becomes measurable
- **Drives architecture decisions** — the scenario tells you what the architecture must support
- **Feeds fitness functions** — the measure becomes an automated test (see [fitness-functions.md](fitness-functions.md))
- **Enables trade-off conversations** — "if we need p99 < 100ms AND five-nines availability, here's what it costs"

---

## Prioritizing Quality Attributes

You can't optimize for everything. Prioritize based on:

1. **Business criticality**: what matters most to users and revenue?
2. **Risk**: what's most likely to cause problems if not addressed?
3. **Stakeholder input**: different stakeholders care about different attributes (ops cares about deployability, users care about performance)
4. **Domain constraints**: healthcare requires security/compliance, e-commerce requires availability/performance

### Common profiles

| System type | Top priority | Secondary |
|---|---|---|
| E-commerce | Availability, Performance, Security | Scalability, Cost |
| Internal tool | Modifiability, Maintainability | Usability |
| Financial system | Security, Reliability, Availability | Performance, Auditability |
| Startup MVP | Modifiability, Deployability | (everything else — just ship) |
| IoT platform | Scalability, Reliability | Performance, Security |
| Healthcare | Security, Compliance, Availability | Reliability |

---

## Anti-patterns

- "The system should be fast, secure, reliable, scalable, and maintainable" — everything is priority = nothing is priority
- Quality attributes discussed only after implementation ("why is it slow?" — because nobody specified performance requirements)
- No measurable criteria ("the system should be highly available" — what does "highly" mean?)
- Architect mandates quality attributes without stakeholder input (over-engineering for attributes nobody cares about)
- Same quality attribute profile for all services (the admin dashboard doesn't need five-nines)

---

## References

- [Bass, Clements, Kazman — Quality Attribute Scenarios (Ch. 3-4)](https://www.sei.cmu.edu/library/software-architecture-in-practice-fourth-edition/)
- [Richards, Ford — Architecture Characteristics (Ch. 4-5)](https://www.oreilly.com/library/view/fundamentals-of-software/9781098175504/)
- [Wikipedia — List of System Quality Attributes](https://en.wikipedia.org/wiki/List_of_system_quality_attributes)
