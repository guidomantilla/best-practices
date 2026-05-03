# System-Level Architecture

How many deployable units, how they relate, and the overall topology. The biggest decisions with the longest-lasting consequences.

---

## 1. Monolith

One deployable unit contains all functionality.

### Types

| Type | What it means |
|---|---|
| **Single-process monolith** | One binary/process, all code together |
| **Modular monolith** | One deployable, but internally separated into modules with clear boundaries |
| **Distributed monolith** | Multiple services that must be deployed together (worst of both worlds) |

### When monolith is right
- Small team (1-10 developers)
- Early stage product (discovering domain boundaries)
- Low operational complexity tolerance
- Strong consistency requirements (single database, ACID transactions)
- Simple deployment needs

### Advantages
- Simple deployment (one thing to deploy)
- Simple debugging (one process, one log stream)
- No network latency between components (in-process calls)
- ACID transactions across all data (one database)
- Refactoring is easy (IDE rename works across the whole codebase)

### Anti-patterns
- **Big ball of mud**: no internal structure, everything depends on everything
- **Distributed monolith**: split into services but must deploy all together (no independence)
- Premature decomposition into microservices when the domain isn't understood yet

---

## 2. Modular Monolith

A monolith with enforced internal boundaries. Best of both: simplicity of monolith + modularity for future extraction.

### Structure
```
/modules
  /orders        (own models, own DB schema/tables, own API)
  /payments      (own models, own DB schema/tables, own API)
  /users         (own models, own DB schema/tables, own API)
  /shared        (common utilities, shared kernel)
```

### Rules
- Modules communicate through defined interfaces (not direct DB access across modules)
- Each module owns its data (no cross-module table access)
- Module boundaries align with domain boundaries (bounded contexts)
- Modules CAN share a database, but each owns its tables

### Why it matters
- When you eventually need to extract a microservice, the boundary already exists
- Forces good separation discipline without operational overhead of distributed systems
- Easier to test, easier to reason about than a big ball of mud

### Anti-patterns
- Modules that access each other's database tables directly (no boundary)
- One giant `shared` module that everything depends on (hidden coupling)
- "Modular" but modules import from each other freely (boundaries not enforced)

---

## 3. Microservices

Multiple independently deployable services, each owning a bounded context.

### Characteristics
- **Independently deployable**: change and deploy one service without touching others
- **Owns its data**: each service has its own database/schema (no shared DB)
- **Organized around business capabilities**: not technical layers (not "auth service" for all, but "orders service" that handles its own auth)
- **Decentralized governance**: each team chooses its own stack/patterns

### When microservices are right
- Large organization (multiple teams need to deploy independently)
- Different scaling requirements per component (search scales differently than checkout)
- Different technology requirements per component (ML service in Python, API in Go)
- Clear domain boundaries are well understood

### When microservices are WRONG
- Small team (< 5 developers) — operational overhead exceeds benefit
- Domain boundaries are unclear (you'll draw them wrong and pay the coordination tax)
- Team doesn't have DevOps maturity (CI/CD, monitoring, distributed tracing must exist FIRST)
- "Because Netflix does it" without Netflix's problems

### Decomposition strategies

| Strategy | How to split |
|---|---|
| **By business capability** | Orders, Payments, Shipping, Users |
| **By subdomain (DDD)** | Bounded contexts from domain modeling |
| **By team** | Team owns service end-to-end (Conway's Law) |
| **Strangler Fig** | Gradually extract from monolith, route traffic to new service |

### Anti-patterns
- **Distributed monolith**: services must deploy together (defeats the purpose)
- **Shared database**: multiple services read/write same tables (coupled, can't evolve independently)
- **Chatty services**: 50 inter-service calls per user request (latency, fragility)
- **Nano-services**: too granular (one function per service — operational overhead per function)
- **Wrong boundaries**: frequent cross-service changes indicate wrong decomposition
- **No service-to-service auth** (zero trust): internal services call each other without authentication — compromising one service = access to all. See `../integration-level.md` §13 (Service Mesh) and `../../zero-trust/identity.md` (Service Identity).

### Shared Services in Microservices (Zero Trust perspective)

Some capabilities are shared across all services. These are infrastructure-level services, not business services:

| Shared service | What it provides | Who owns it |
|---|---|---|
| **Identity Provider (IdP)** | User authentication, SSO, MFA | Platform / Auth team |
| **Authorization Service** | Centralized authz decisions (OpenFGA, OPA) | Platform / Auth team |
| **API Gateway** | Routing, rate limiting, coarse auth | Platform team |
| **Observability stack** | Logging, metrics, tracing collection | Platform team |
| **Secret Manager** | Credential storage, rotation, access control | Platform / Security team |

These are NOT business microservices — they're platform infrastructure. Every business service depends on them.

---

## 4. Event-Driven Architecture

Systems communicate primarily through events (facts about what happened).

### Patterns

| Pattern | How | When |
|---|---|---|
| **Event Notification** | Service publishes event, consumers decide what to do | Loose coupling, fan-out reactions |
| **Event-Carried State Transfer** | Event contains full state (consumer doesn't need to call back) | Reduce coupling, consumer has all data it needs |
| **Event Sourcing** | Store events as source of truth (derive state from event history) | Audit trail, temporal queries, complex domains |
| **CQRS** | Separate read model from write model | Different read/write patterns, different scaling needs |

### Event Sourcing
```
Events (append-only):
  OrderCreated { id, customer, items, total }
  OrderPaid { id, payment_ref }
  OrderShipped { id, tracking_number }

Current state = replay all events for that aggregate
```

**When**: full audit trail required, temporal queries ("what was the state last Tuesday"), complex domains with many state transitions.

**When NOT**: simple CRUD, when current state is all you need, when event schema evolution is too complex for the team.

### CQRS (Command Query Responsibility Segregation)
```
Commands → Write Model (normalized, optimized for writes)
Queries → Read Model (denormalized, optimized for reads)

Write Model publishes events → Read Model subscribes and updates projections
```

**When**: read and write patterns are fundamentally different (writes are complex domain logic, reads are simple projections), different scaling needs.

**When NOT**: read and write patterns are similar (standard CRUD), team size doesn't justify the complexity.

### Anti-patterns
- Event sourcing for everything (simple CRUD doesn't need event history)
- CQRS for a service with one read and one write endpoint
- Events without schema versioning (breaking consumers on evolution)
- No way to rebuild read models (corrupted projection = stuck)
- Eventual consistency where strong consistency is required (account balance)

---

## 5. Serverless

Functions/containers that scale to zero and execute on demand.

### Types

| Type | What it is | Examples |
|---|---|---|
| **FaaS (Function-as-a-Service)** | Single function triggered by event | AWS Lambda, Google Cloud Functions, Azure Functions |
| **Container-as-a-Service** | Container that scales to zero | Cloud Run, AWS Fargate, Azure Container Apps |
| **BaaS (Backend-as-a-Service)** | Managed services replacing custom backend | Firebase, Supabase, AWS Amplify |

### When serverless is right
- Sporadic/unpredictable traffic (scale to zero when idle)
- Event-driven workloads (file upload triggers processing, webhook triggers action)
- Simple APIs without complex state
- Cost optimization for low-traffic services (pay per invocation, not per hour)

### When serverless is wrong
- Long-running processes (Lambda max 15 min)
- Latency-sensitive with cold start issues
- Complex stateful applications
- High-throughput sustained traffic (cheaper to run containers 24/7)
- Vendor lock-in is unacceptable

### Anti-patterns
- Lambda per CRUD operation (over-decomposed — one Lambda per HTTP method per resource)
- Serverless for everything (some workloads are cheaper and simpler as containers)
- No cold start mitigation for latency-sensitive functions (provisioned concurrency or keep-warm)
- State in function memory (lost between invocations)

---

## 6. DDD Strategic Patterns

Domain-Driven Design at the system level — how to identify service boundaries.

### Bounded Context
A boundary within which a model is consistent and a term has one meaning.

```
In "Sales" context: Customer = someone who buys
In "Support" context: Customer = someone who files tickets
Same word, different models → different bounded contexts → potentially different services
```

### Context Map
How bounded contexts relate to each other:

| Relationship | What it means |
|---|---|
| **Shared Kernel** | Two contexts share a small common model (tightly coupled, coordinate changes) |
| **Customer-Supplier** | Upstream supplies data, downstream consumes (upstream accommodates downstream needs) |
| **Conformist** | Downstream accepts upstream's model as-is (no negotiation) |
| **Anti-Corruption Layer (ACL)** | Downstream translates upstream's model into its own (protects from external model) |
| **Open Host Service** | Upstream provides a well-defined protocol for multiple consumers |
| **Published Language** | Shared language/schema for communication (OpenAPI, protobuf) |

### Principles
- **Bounded context ≈ service boundary** (in microservices)
- **Anti-Corruption Layer** when integrating with legacy/external systems (don't let their model pollute yours)
- **Shared Kernel** only when absolutely necessary (creates coupling between contexts)

---

## 7. Choosing a System Architecture

| Situation | Recommendation |
|---|---|
| 1-5 developers, new product | Monolith (or modular monolith). Discover boundaries first. |
| 5-15 developers, known domain | Modular monolith. Enforce boundaries, extract services when needed. |
| 15+ developers, multiple teams | Microservices aligned with team boundaries (Conway's Law). |
| Spike/unpredictable traffic, simple logic | Serverless (FaaS or CaaS). |
| Complex domain with audit requirements | Event-driven (event sourcing if full history needed). |
| Read-heavy, different read/write patterns | CQRS (with or without event sourcing). |
| Existing monolith, need to scale parts independently | Strangler Fig — extract one service at a time. |

### The progression
```
Monolith → Modular Monolith → Extract critical services → Full microservices (if needed)
```

Most companies should stop at "Modular Monolith + 2-3 extracted services". Full microservices is for large organizations with many teams.

---

## References

- [Sam Newman — Building Microservices (2021)](https://samnewman.io/books/building_microservices_2nd_edition/)
- [Martin Fowler — Microservices](https://martinfowler.com/articles/microservices.html)
- [Martin Fowler — Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)
- [Martin Fowler — CQRS](https://martinfowler.com/bliki/CQRS.html)
- [Martin Fowler — Strangler Fig Application](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Eric Evans — Domain-Driven Design (2003)](https://www.domainlanguage.com/ddd/)
- [Vaughn Vernon — Implementing Domain-Driven Design (2013)](https://vaughnvernon.com/)
