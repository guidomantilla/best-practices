# Integration-Level Patterns

How services **coordinate and communicate** with each other. Based on Enterprise Integration Patterns (Hohpe & Woolf, 2003) and modern distributed systems practice.

For the **contract/interface** design (message format, API shape), see `../contract-design/`. This file covers the **coordination logic** — how systems work together.

---

## 1. Orchestration vs Choreography

The two fundamental approaches to multi-service coordination.

| | Orchestration | Choreography |
|---|---|---|
| **How** | Central coordinator tells each service what to do | Each service reacts to events independently |
| **Coupling** | Orchestrator knows all participants | Services only know about events, not each other |
| **Visibility** | Easy to see the full flow (one place) | Hard to see the full flow (distributed) |
| **Single point of failure** | Orchestrator | None (but harder to debug) |
| **Change impact** | Change orchestrator when flow changes | Change individual services when their reaction changes |

### When to use which

| Use | When |
|---|---|
| **Orchestration** | Business process with strict ordering, complex compensation, clear ownership of the flow |
| **Choreography** | Loosely coupled reactions, fan-out (multiple systems react independently), no strict ordering needed |

### Anti-patterns
- Orchestrator that becomes a god service (all logic centralized, services are dumb executors)
- Choreography with implicit ordering assumptions (breaks when a new consumer subscribes)
- Mixing both without clarity (some steps orchestrated, some choreographed — nobody knows the full flow)

---

## 2. Saga Pattern

Manage distributed transactions across multiple services without 2PC (two-phase commit).

### The problem
```
Order Service → Payment Service → Inventory Service → Shipping Service
If Payment succeeds but Inventory fails → need to refund Payment
```

No single database transaction spans all services. Saga coordinates compensating actions.

### Types

| Type | How | When |
|---|---|---|
| **Orchestrated Saga** | Central saga coordinator manages steps and compensations | Complex flows, need visibility, clear ownership |
| **Choreographed Saga** | Each service publishes events, next service reacts | Simple flows, fewer steps, decoupled teams |

### Compensating actions
Every step must have a compensating action (undo):
```
Step: charge_payment → Compensate: refund_payment
Step: reserve_inventory → Compensate: release_inventory
Step: create_shipment → Compensate: cancel_shipment
```

### Principles
- **Every forward step has a defined compensation** (if it can't be undone, it goes last)
- **Idempotent steps**: steps may be retried — they must handle duplicates
- **Timeout + compensation**: if a step doesn't respond in time, trigger compensation
- **Persist saga state**: the coordinator/each step tracks where in the flow we are

### Anti-patterns
- Steps without defined compensations (what do you do when step 4 of 5 fails?)
- Non-idempotent steps (retry creates double charges)
- No timeout (saga hangs forever waiting for a response)
- Saga state only in memory (process crashes → saga lost in limbo)

---

## 3. Circuit Breaker

Stop calling a failing service. Fail fast, let it recover.

### States
```
[Closed] → failures exceed threshold → [Open]
[Open] → after timeout → [Half-Open]
[Half-Open] → probe succeeds → [Closed]
[Half-Open] → probe fails → [Open]
```

| State | Behavior |
|---|---|
| **Closed** | Requests pass through normally. Count failures. |
| **Open** | Requests fail immediately (no call to downstream). Return fallback. |
| **Half-Open** | Allow one probe request. If succeeds → close. If fails → reopen. |

### Configuration

| Parameter | What it controls | Typical |
|---|---|---|
| Failure threshold | How many failures before opening | 5-10 failures in 60s |
| Timeout (open duration) | How long to stay open before probing | 30-60 seconds |
| Probe count | How many successful probes before closing | 1-3 |

### Principles
- **Fail fast with a meaningful fallback** (cached response, default value, degraded experience)
- **Monitor circuit state** (alert when circuits open — it means a dependency is down)
- **Per-dependency circuits** (not one global circuit breaker for all external calls)

### Anti-patterns
- No circuit breaker (keep retrying a dead service, cascade failure)
- Circuit breaker with no fallback (fast failure but no useful response to client)
- Threshold too sensitive (opens on one timeout — transient failure triggers circuit)
- No monitoring of open circuits (service degraded silently for hours)

### Tooling
| Tool | Language |
|---|---|
| **resilience4j** | Java |
| **gobreaker** | Go |
| **polly** | .NET |
| **cockatiel** | TypeScript |
| **Service mesh (Istio, Linkerd)** | Any (infrastructure-level) |

---

## 4. Retry & Backoff

Handle transient failures by retrying with increasing delay.

### Pattern
```
Attempt 1: immediate
Attempt 2: wait 100ms + jitter
Attempt 3: wait 400ms + jitter
Attempt 4: wait 1600ms + jitter
Give up after N attempts
```

### Principles
- **Only retry transient errors** (timeout, 503, network error — NOT 400, 401, 404)
- **Exponential backoff** — each retry waits longer (base × 2^attempt)
- **Jitter** — randomize delay to prevent thundering herd
- **Max retries** — always have a limit (3-5 retries, then fail)
- **Idempotent operations only** — don't retry non-idempotent operations without idempotency key

### Anti-patterns
- Retrying everything (retry on 400 Bad Request — will never succeed)
- No backoff (immediate retries hammer an already-struggling service)
- No jitter (all clients retry at exactly the same time)
- Infinite retries (never gives up — resource exhaustion)
- Retrying inside a retry (nested retries = exponential explosion of attempts)

---

## 5. Bulkhead

Isolate failures so they don't cascade across the system.

### The metaphor
Ship hulls have bulkheads — if one compartment floods, others remain sealed. Same for services.

### Patterns

| Pattern | How |
|---|---|
| **Thread pool isolation** | Each dependency gets its own thread pool. If one is exhausted, others unaffected. |
| **Connection pool isolation** | Separate connection pools per downstream service. |
| **Service isolation** | Critical path and non-critical path in separate instances/pods. |
| **Rate limiting per tenant** | One tenant can't exhaust resources for all. |

### Anti-patterns
- One shared thread/connection pool for all external calls (one slow dependency blocks everything)
- No resource limits on non-critical background jobs (backfill job consumes all DB connections)

---

## 6. Content-Based Router

Route a message to different consumers based on its content.

### When
- One input channel, multiple processing paths depending on message type/content
- Order routing by type (digital → fulfillment service A, physical → fulfillment service B)

### Anti-patterns
- Router with business logic (router should ROUTE, not process)
- Router that knows too much about consumers (tight coupling)

---

## 7. Splitter / Aggregator

**Splitter**: break a composite message into individual parts for independent processing.
**Aggregator**: collect related messages and combine into one composite result.

### When
- Batch order with 10 items → split into 10 individual item-processing messages
- 10 enrichment results → aggregate into one complete response

### Principles
- Aggregator must handle: timeout (not all parts arrive), duplicates, out-of-order
- Define correlation ID so aggregator knows which parts belong together
- Define completion condition (all N parts received, OR timeout)

---

## 8. Process Manager (Routing Slip)

Dynamic multi-step processing where the path depends on the content.

### Routing Slip
Message carries its own routing instructions:
```json
{
  "data": {...},
  "routing_slip": ["validate", "enrich", "score", "notify"],
  "current_step": 0
}
```

Each processor handles its step, increments `current_step`, forwards to next.

### Process Manager
A stateful coordinator that decides next steps based on results of previous steps (more flexible than routing slip, similar to orchestrated saga).

---

## 9. Message Translator / Enricher / Filter

**Translator**: convert message from one format to another (between systems with different schemas).

**Enricher**: add data to a message from an external source (look up user details, add geo data).

**Filter**: remove messages that don't match criteria (discard irrelevant events before processing).

### Principles
- Keep transformations stateless and side-effect free where possible
- Enricher adds latency (external lookup) — cache enrichment data when possible
- Filters reduce load downstream — filter as early as possible in the pipeline

---

## 10. Canonical Data Model

One shared data format that all systems translate to/from.

### When
- Multiple systems with different internal schemas need to exchange data
- Enterprise integration (ERP ↔ CRM ↔ Warehouse ↔ Billing)

### Trade-off
- **Pro**: each system only needs one translator (to/from canonical), not N-1 (to/from every other system)
- **Con**: canonical model becomes a bottleneck (changing it requires coordinating all systems)

### Anti-patterns
- Canonical model that mirrors one system's internal model (not truly canonical — biased)
- Canonical model that tries to be everything to everyone (bloated, lowest common denominator)
- No versioning on the canonical model (breaking changes affect all integrators)

---

## 11. Wire Tap

Capture a copy of messages flowing through the system for monitoring, debugging, or auditing — without affecting the primary flow.

### Patterns
- Message broker topic that mirrors production messages (consumers observe without affecting flow)
- Service mesh sidecar that logs all inter-service communication
- Database CDC stream that publishes all changes for observability

### Principles
- Wire tap must not affect the primary flow (async, non-blocking)
- Sensitive data in wire tap needs same protection as in the primary flow (PII, encryption)
- Useful for: debugging production issues, audit trails, feeding analytics

---

## 12. Change Data Capture (CDC)

Capture changes from a database and publish them as events for downstream consumers.

### How
```
Application writes to DB → CDC captures change from DB log → publishes event to broker → consumers react
```

### Tools
| Tool | How it works |
|---|---|
| **Debezium** | Reads DB WAL/binlog, publishes to Kafka |
| **AWS DMS** | Managed CDC for AWS databases |
| **Airbyte** | CDC as part of data integration |

### When to use
- Need to react to data changes without modifying the writing application
- Sync data between operational DB and analytics/search/cache
- Event-driven architecture where the source doesn't publish events natively

### Principles
- CDC reads the DB log — zero impact on application code (no code changes needed)
- Events are at-least-once (deduplication needed downstream)
- Schema changes in source DB affect CDC output (coordinate schema evolution)

### Anti-patterns
- Dual-write (write to DB + publish event in application — inconsistency if one fails). Use outbox or CDC instead.
- CDC without schema registry (downstream consumers break on schema changes)
- CDC on high-write tables without filtering (overwhelms downstream with noise)

---

## 13. Service Mesh & Zero Trust Networking

Service mesh provides zero trust communication between services at the infrastructure level — without changing application code.

### What a service mesh provides
- **mTLS by default**: all service-to-service traffic encrypted and mutually authenticated — automatically
- **Service identity**: each workload gets a cryptographic identity (SPIFFE/x509 certificate)
- **Authorization policies**: define which services can talk to which (not just network rules — identity-based)
- **Observability**: traffic metrics, traces, access logs between services — for free

### How it works
```
Service A (sidecar proxy) ←mTLS→ Service B (sidecar proxy)
    ↑                                    ↑
  Envoy/Linkerd proxy                  Envoy/Linkerd proxy
  handles TLS, auth, metrics           handles TLS, auth, metrics
```

The application code makes a plain HTTP call. The sidecar proxy handles encryption, authentication, and authorization transparently.

### Tools

| Tool | Type |
|---|---|
| **Istio** | Full-featured service mesh (Envoy-based) |
| **Linkerd** | Lightweight service mesh (Rust-based proxy) |
| **Consul Connect** | Service mesh + service discovery |
| **Cilium** | eBPF-based networking + mesh (no sidecar) |

### When to use
- Multiple services that need mutual authentication
- Zero trust requirement for internal traffic
- You want mTLS without changing application code
- You need traffic-level observability between services

### When NOT to use
- 2-3 services (overhead exceeds benefit — use application-level mTLS or JWT)
- Team has no K8s/infra maturity to operate a mesh
- Adding complexity to solve a problem you don't have

### Anti-patterns
- Service mesh deployed but no authorization policies defined (mTLS on but all traffic allowed — encryption without access control)
- Mesh as replacement for application-level auth (mesh authenticates the SERVICE, but who is the USER? Application must still validate the user JWT)
- No policy for mesh failures (if the sidecar is down, does traffic pass or block?)

See `../../zero-trust/networks.md` for the full zero trust network perspective.

---

## 14. Centralized Authorization Service

Authorization as a shared integration component — when authz decisions involve data from multiple services.

### When
- "Can user X edit document Y?" requires checking relationships (ownership, sharing, group membership)
- Multiple services need to answer the same authorization question consistently
- Authorization model is complex enough that each service can't evaluate independently (ReBAC, relationship graphs)

### Architecture
```
Service A → Authz Service (OpenFGA / SpiceDB / OPA) → decision (allow/deny)
Service B → Authz Service → decision
Service C → Authz Service → decision
```

### Considerations
- **Latency**: adds ~1-5ms per authz decision (cache hot paths)
- **Availability**: if authz service is down, services must have a fallback (fail-closed + cached decisions)
- **Consistency**: when permissions change, how fast does it propagate?
- **Ownership**: who maintains the authorization model? Platform team? Each service team?

See `./application-level.md` §8 (Authorization as Architecture) for the in-service perspective.

---

## References

- [Gregor Hohpe & Bobby Woolf — Enterprise Integration Patterns (2003)](https://www.enterpriseintegrationpatterns.com/)
- [Chris Richardson — Saga Pattern](https://microservices.io/patterns/data/saga.html)
- [Martin Fowler — Circuit Breaker](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Debezium Documentation](https://debezium.io/documentation/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [OpenFGA Documentation](https://openfga.dev/docs/)
- [SPIFFE — Secure Production Identity](https://spiffe.io/)
