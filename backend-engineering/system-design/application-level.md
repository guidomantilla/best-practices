# Application-Level Architecture

How to organize code **inside ONE deployable unit** — the internal structure of a service/application. This is NOT about how services talk to each other (that's integration-level) or how many services you have (that's system-level).

---

## 1. Layered Architecture (N-Layer / N-Tier)

The most common starting point.

### 3-Layer
```
┌─────────────────────────┐
│  Presentation Layer     │  (HTTP handlers, CLI, gRPC)
├─────────────────────────┤
│  Business Logic Layer   │  (domain rules, services, use cases)
├─────────────────────────┤
│  Data Access Layer      │  (repositories, DB queries, external APIs)
└─────────────────────────┘
```

### Rules
- Dependencies flow **downward** (presentation → business → data)
- Never skip layers (presentation should not call data directly)
- Each layer has a clear responsibility

### 3-Layer vs 3-Tier
- **Layer** = logical separation (packages/modules in the same process)
- **Tier** = physical separation (different servers/processes)

They often map 1:1, but not always. A monolith can have 3 layers in one tier.

### When to use
- Simple CRUD applications
- Small to medium services
- When the team is familiar with it (low cognitive overhead)

### Anti-patterns
- **Anemic domain model**: business layer is just pass-through (all logic in handlers or repositories)
- **Fat controllers**: presentation layer contains business logic
- **Skipping layers**: handler directly queries DB, bypassing service layer
- **Circular dependencies between layers**

---

## 2. Clean Architecture

Dependencies point **inward** toward the domain. External concerns (DB, HTTP, frameworks) are on the outside.

### Layers (inside → outside)
```
┌────────────────────────────────────────┐
│            Frameworks & Drivers        │  (HTTP, DB, external APIs, UI)
│  ┌──────────────────────────────────┐  │
│  │         Interface Adapters       │  │  (Controllers, Gateways, Presenters)
│  │  ┌──────────────────────────┐    │  │
│  │  │      Use Cases           │    │  │  (Application-specific business rules)
│  │  │  ┌──────────────────┐    │    │  │
│  │  │  │    Entities       │    │    │  │  (Enterprise-wide business rules)
│  │  │  └──────────────────┘    │    │  │
│  │  └──────────────────────────┘    │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

### The Dependency Rule
- Inner layers know NOTHING about outer layers
- Entities don't know about use cases
- Use cases don't know about controllers or databases
- Dependencies always point inward

### In practice (Go/TS/Python)
```
/domain         → entities, value objects, domain interfaces
/usecase        → application logic (orchestrates domain, defines ports)
/adapter        → implementations of ports (DB, HTTP client, external APIs)
/handler        → HTTP/gRPC handlers, CLI commands (drives use cases)
```

### When to use
- Services with significant business logic (not pure CRUD)
- Long-lived services that will evolve over years
- When you need to swap infrastructure without rewriting logic (DB migration, framework change)

### Anti-patterns
- Entities that import database packages (dependency rule violated)
- Use cases that know about HTTP status codes (leaking transport into business logic)
- Over-engineering for a simple CRUD service (Clean Architecture overhead for a 3-endpoint API)
- "Clean Architecture" with one implementation per interface and no tests (ceremony without benefit)

---

## 3. Hexagonal Architecture (Ports & Adapters)

Same idea as Clean Architecture, different vocabulary. Domain at center, driven/driving ports on the edges.

### Structure
```
         Driving Adapters                    Driven Adapters
         (input)                             (output)

    ┌──────────┐                        ┌──────────────┐
    │ HTTP API │───┐                ┌───│  PostgreSQL  │
    └──────────┘   │                │   └──────────────┘
    ┌──────────┐   │   ┌────────┐  │   ┌──────────────┐
    │   CLI    │───┼───│ Domain │──┼───│    Redis     │
    └──────────┘   │   └────────┘  │   └──────────────┘
    ┌──────────┐   │                │   ┌──────────────┐
    │  gRPC    │───┘                └───│  Email API   │
    └──────────┘                        └──────────────┘

         Ports                               Ports
         (interfaces                         (interfaces
          domain defines)                     domain defines)
```

### Concepts
- **Port**: interface defined by the domain (what it needs, not how it's implemented)
- **Driving adapter** (primary): something that CALLS the domain (HTTP handler, CLI, test)
- **Driven adapter** (secondary): something the domain CALLS (DB, external API, messaging)

### The key insight
The domain defines the ports (interfaces). Adapters implement them. This means:
- Domain never imports infrastructure
- You can swap any adapter without touching domain code
- Tests use in-memory adapters (no DB needed)

### When to use
- Same as Clean Architecture (they're essentially the same concept with different names)
- When the team prefers the ports/adapters vocabulary

---

## 4. Domain-Driven Design (DDD) — Tactical Patterns

DDD at the application level (internal code structure). Strategic DDD (bounded contexts, context maps) is system-level — see `system-level.md`.

### Building blocks

| Pattern | What it is | Example |
|---|---|---|
| **Entity** | Object with identity that persists over time | `User`, `Order` (have an ID) |
| **Value Object** | Immutable object defined by its attributes, no identity | `Money(100, "USD")`, `Email("a@b.com")`, `Address` |
| **Aggregate** | Cluster of entities with one root, transactional boundary | `Order` (root) + `OrderItems` (children) |
| **Repository** | Abstraction for aggregate persistence | `OrderRepository.Save(order)` |
| **Domain Service** | Logic that doesn't belong to any single entity | `PricingService.CalculateDiscount(order, customer)` |
| **Domain Event** | Something that happened in the domain | `OrderPlaced`, `PaymentCompleted` |
| **Factory** | Complex object creation logic | `OrderFactory.CreateFromCart(cart)` |

### Aggregate rules
- External code references the aggregate only through its **root** (not child entities)
- Changes to the aggregate go through the root (root enforces invariants)
- One transaction = one aggregate (don't modify multiple aggregates in one transaction)
- Keep aggregates small (only what MUST be consistent together)

### Anti-patterns
- **Anemic domain model**: entities are just data bags (getters/setters), all logic in services
- **God aggregate**: one aggregate that contains everything (breaks transaction boundaries)
- **Cross-aggregate transactions**: modifying Order and Inventory in one transaction (use events instead)
- **DDD everywhere**: applying tactical patterns to simple CRUD (over-engineering)

### When to use DDD
- Complex business domain with many rules and invariants
- Domain experts available to collaborate on modeling
- Long-lived systems where the domain model will evolve significantly

### When NOT to use DDD
- Simple CRUD (read form → save to DB → done)
- Purely technical services (proxies, gateways, transformers)
- Team has no domain expert access

---

## 5. The Twelve-Factor App

12 principles for building cloud-native applications — how to design ONE service for portability, scalability, and operational hygiene.

| # | Factor | Principle | Covered in |
|---|---|---|---|
| 1 | **Codebase** | One codebase tracked in VCS, many deploys | — |
| 2 | **Dependencies** | Explicitly declare and isolate dependencies (lockfiles) | `../software-principles/` |
| 3 | **Config** | Store config in environment, not code | `../configuration/` |
| 4 | **Backing services** | Treat databases, caches, queues as attached resources (swappable via config) | Here |
| 5 | **Build, release, run** | Strictly separate build, release, and run stages | `../ci-cd/` |
| 6 | **Processes** | Execute as stateless processes (share-nothing) | Here |
| 7 | **Port binding** | Export services via port binding (self-contained, no app server required) | Here |
| 8 | **Concurrency** | Scale out via the process model (run more instances, not bigger instances) | `scalability.md` |
| 9 | **Disposability** | Fast startup and graceful shutdown (SIGTERM handling) | Here + `../iac/` |
| 10 | **Dev/prod parity** | Keep development, staging, and production as similar as possible | `../configuration/` + `../testing/` |
| 11 | **Logs** | Treat logs as event streams (write to stdout, let the platform collect) | `../observability/` |
| 12 | **Admin processes** | Run admin/management tasks as one-off processes (same codebase, same environment) | Here |

### Factors detailed here (4, 6, 7, 9, 12)

**Factor 4 — Backing services as attached resources**:
- Database, cache, queue, email service — all accessed via URL/config
- Swappable without code changes (local PostgreSQL vs RDS vs Cloud SQL — just change the URL)
- No distinction between "local" and "third-party" services in the code

**Factor 6 — Stateless processes**:
- No local state between requests (no in-process sessions, no local file uploads)
- Any state shared between requests lives in a backing service (Redis, DB, S3)
- Any instance can handle any request (enables horizontal scaling, rolling deploys)

**Factor 7 — Port binding**:
- The app IS the web server (no external Tomcat/Apache needed)
- Exports HTTP (or gRPC, etc.) by binding to a port
- One service = one port = one process

**Factor 9 — Disposability**:
- Startup in seconds (not minutes)
- Handle SIGTERM gracefully: stop accepting new work, finish in-flight, exit
- Crash-safe: any process can die at any time without data corruption (idempotent operations, transactional writes)

**Factor 12 — Admin processes**:
- Migrations, one-off scripts, REPL — run in the same environment as the app
- Same codebase, same config, same dependencies
- Not SSH into a server and run ad-hoc commands

### Anti-patterns
- Session state stored in process memory (sticky sessions, scaling problems)
- App requires external app server (Tomcat, Apache) instead of self-hosting
- Slow startup (5+ minutes — kills auto-scaling, rolling deploys)
- No SIGTERM handling (process killed mid-request, data corrupted)
- Admin scripts that require a different environment than the app

---

## 6. MVC / MVVM / MVP

Presentation-layer patterns for organizing UI logic. Brief mention for completeness — these are primarily frontend/mobile patterns.

| Pattern | Separation | Typical use |
|---|---|---|
| **MVC** (Model-View-Controller) | Controller handles input, Model holds state, View renders | Server-rendered (Rails, Django, Spring MVC) |
| **MVVM** (Model-View-ViewModel) | ViewModel exposes data to View via bindings | Frontend frameworks (WPF, SwiftUI, Vue.js) |
| **MVP** (Model-View-Presenter) | Presenter mediates between View and Model | Android (older), testable UI logic |

These are well-established and mostly framework-driven (the framework dictates the pattern). Not much to debate here — use what your framework provides.

---

## 7. Choosing an Application Architecture

| Situation | Recommendation |
|---|---|
| Simple CRUD, 3-5 endpoints | 3-layer is fine. Don't over-architect. |
| Service with business logic that will grow | Clean/Hexagonal. Invest in separation early. |
| Complex domain with many invariants | DDD tactical patterns inside Clean/Hexagonal. |
| Existing legacy codebase | Don't rewrite. Gradually extract boundaries (Strangler Fig at application level). |
| Prototype / MVP | Whatever is fastest. Refactor later if it succeeds. |
| Microservice (small, focused) | 3-layer or simplified Clean (don't need 5 layers for a 500-line service). |

### The progression
Most services start simple and evolve:
```
Script → 3-Layer → Clean/Hexagonal → Clean + DDD
```

Don't jump to the end. Evolve when complexity justifies it.

---

## 8. Authorization as Architecture (Zero Trust)

Authorization isn't just a security check — it's an architectural component that affects system design.

### Where authorization logic lives

| Approach | How | Trade-off |
|---|---|---|
| **Inline in handlers** | `if user.role == "admin"` in each endpoint | Simple, but scattered, inconsistent, hard to audit |
| **Middleware layer** | Auth middleware checks before handler executes | Centralized per service, but still per-service |
| **Policy engine (sidecar)** | OPA as sidecar, each pod evaluates policies locally | Fast (local), consistent policies, but must distribute policy updates |
| **Policy engine (service)** | Centralized authz service (OpenFGA, SpiceDB, Cedar) | Single source of truth, but adds network dependency per request |
| **Gateway + service** | Gateway does coarse auth (JWT valid?), service does fine-grained (can user X do Y on resource Z?) | Layered — recommended for zero trust |

### The progression
```
Inline checks → Middleware → Policy-as-code (OPA/Cedar) → Centralized authz service (OpenFGA/SpiceDB)
```

### Architecture implications

| Concern | Impact |
|---|---|
| **Latency** | External policy engine adds ~1-5ms per request (network call). Cache decisions where possible. |
| **Availability** | If the policy engine is down, can services authorize? Define fail-closed behavior + local cache fallback. |
| **Consistency** | Permission changes propagate how fast? Eventual consistency in the relationship graph? |
| **Multi-service** | Who is the source of truth for "can user X do Y in service B's domain"? |
| **Data flow** | RBAC: role in JWT (self-contained). FGA: relationship query to external service (dependency). |

See `../../zero-trust/identity.md` for auth patterns and `../../zero-trust/applications.md` for application access control.
