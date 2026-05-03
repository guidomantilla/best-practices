# Scalability Patterns

How to handle more load. Cross-level — these patterns apply regardless of whether you have a monolith or microservices.

---

## 1. Scaling Directions

| Direction | How | When |
|---|---|---|
| **Vertical (scale up)** | Bigger machine (more CPU, RAM, disk) | Quick fix, DB that can't shard easily, single-process bottleneck |
| **Horizontal (scale out)** | More instances behind a load balancer | Stateless services, predictable linear scaling |

### Principles
- **Scale horizontally by default** — vertical has a ceiling, horizontal is theoretically unbounded
- **Stateless enables horizontal** — if service stores state in-process, it can't scale out (see 12-Factor §6)
- **Vertical for databases** — until you absolutely must shard (sharding is complex)
- **Know your bottleneck** — CPU-bound? Memory-bound? I/O-bound? Network-bound? Scale the bottleneck, not everything.

### Anti-patterns
- Scaling everything when only one component is the bottleneck (wasted cost)
- Horizontal scaling of a stateful service without solving state (sessions break, data splits)
- "Just throw more instances at it" without understanding why it's slow (masking the real problem)

---

## 2. Load Balancing

Distribute traffic across multiple instances.

### Algorithms

| Algorithm | How | Best for |
|---|---|---|
| **Round-robin** | Rotate through instances sequentially | Equal-capacity instances, stateless |
| **Least connections** | Send to instance with fewest active connections | Varying request durations |
| **Weighted** | Some instances get more traffic (by capacity) | Mixed instance sizes |
| **IP hash** | Same client IP → same instance | Soft session affinity (not recommended for scaling) |
| **Random** | Random selection | Simple, surprisingly effective |

### Levels

| Level | What it balances | Tools |
|---|---|---|
| **DNS** | Traffic across regions/data centers | Route53, Cloudflare, NS1 |
| **L4 (TCP)** | TCP connections to instances | AWS NLB, HAProxy (TCP mode) |
| **L7 (HTTP)** | HTTP requests with path/header routing | AWS ALB, Nginx, Envoy, Traefik |
| **Service mesh** | Inter-service traffic within cluster | Istio, Linkerd |

### Anti-patterns
- No health checks (load balancer sends traffic to dead instances)
- Sticky sessions as primary strategy (one instance failure loses all those sessions)
- Load balancer as single point of failure (no redundancy on the LB itself)

---

## 3. Caching (for scalability)

Reduce load on expensive operations by serving from cache.

Covered in detail in `../data-design/caching.md`. Here: the scalability-specific considerations.

### Where caching helps scalability
- **Database offloading**: cache frequent queries → DB handles less read load
- **Computation offloading**: cache expensive calculations → CPU freed for other work
- **Upstream offloading**: CDN caches responses → origin handles fewer requests
- **Authorization decision caching**: cache authz decisions to avoid calling the policy engine on every request. Short TTL (seconds-minutes) to balance performance and freshness. Invalidate on permission changes.

### Cache hierarchy for scale
```
Client (browser cache) → CDN (edge) → API cache (Redis) → DB
```

Each layer absorbs traffic — only cache misses reach the next layer.

### Anti-patterns
- Caching without measuring (adding cache that has 10% hit rate — not worth the complexity)
- Cache that doesn't reduce the actual bottleneck (caching something that isn't the slow part)

---

## 4. Database Scaling

### Read replicas
- Primary handles writes, replicas handle reads
- Acceptable for read-heavy workloads with tolerance for slight lag
- Simple to implement, no application-level sharding logic

### Sharding (partitioning)
- Split data across multiple database instances by a shard key
- Each shard holds a subset of the data

| Strategy | How | Trade-off |
|---|---|---|
| **Range-based** | Shard by range (users A-M on shard 1, N-Z on shard 2) | Simple, but hot spots if distribution is uneven |
| **Hash-based** | Hash the shard key, modulo N shards | Even distribution, but range queries across shards are expensive |
| **Directory-based** | Lookup table maps key → shard | Flexible, but directory is a single point of failure |

### Principles
- **Avoid sharding as long as possible** — it's the most complex scaling strategy
- **Choose shard key carefully** — must distribute evenly AND align with access patterns
- **Cross-shard queries are expensive** — design so most queries hit one shard
- **Resharding is painful** — plan for growth (consistent hashing helps)

### Anti-patterns
- Sharding too early (vertical scaling + read replicas handles most workloads until millions of users)
- Wrong shard key (one shard gets 90% of traffic — hot shard)
- Cross-shard transactions (essentially impossible to do correctly — redesign the access pattern)
- No plan for resharding (stuck when a shard gets too big)

---

## 5. Asynchronous Processing

Move work out of the request path.

### Patterns

| Pattern | How | Use case |
|---|---|---|
| **Job queue** | Enqueue work, worker processes it later | Email sending, report generation, image processing |
| **Event streaming** | Publish event, multiple consumers process independently | Notifications, analytics, cross-service reactions |
| **Batch processing** | Accumulate work, process in bulk on schedule | Daily reports, data exports, reconciliation |

### Principles
- **If the user doesn't need the result immediately, do it async** — return 202 Accepted, process in background
- **Idempotent workers** — messages may be delivered more than once
- **Backpressure** — if workers can't keep up, slow down producers (don't let queues grow unbounded)
- **Monitor queue depth** — growing queue = workers can't keep up = need more workers or optimization

### Anti-patterns
- Synchronous processing of work that doesn't need immediate result (user waits for email to send)
- No backpressure (queue grows to millions, memory exhausted)
- No monitoring of queue lag (producer is 3 hours ahead of consumer — nobody notices)

---

## 6. Rate Limiting & Throttling

Protect your system from being overwhelmed.

### Algorithms

| Algorithm | How | Use case |
|---|---|---|
| **Fixed window** | N requests per time window (e.g., 100/minute) | Simple, but burst at window boundary |
| **Sliding window** | Rolling window (smoother than fixed) | Most APIs |
| **Token bucket** | Tokens added at fixed rate, consumed per request. Allows bursts up to bucket size. | APIs that need burst tolerance |
| **Leaky bucket** | Requests processed at constant rate, excess queued/dropped | Smoothing traffic |

### Where to rate limit

| Level | What it protects |
|---|---|
| **API Gateway** | External clients (per API key, per IP) |
| **Per service** | Internal abuse, cascading load |
| **Per user/tenant** | Fair usage, prevent one tenant from starving others |
| **Per operation** | Expensive operations limited more than cheap ones |

### Anti-patterns
- No rate limiting on public APIs (one client can DoS your entire system)
- Same limits for all operations (login attempt limited same as GET /health)
- Rate limiting without communicating limits to clients (no 429, no Retry-After, no headers)
- Rate limiting only at the edge (internal services can still overwhelm each other)

---

## 7. Auto-Scaling

Automatically adjust capacity based on demand.

### Metrics to scale on

| Metric | When to use |
|---|---|
| **CPU utilization** | CPU-bound workloads (computation, rendering) |
| **Memory utilization** | Memory-bound workloads (caching, in-memory processing) |
| **Request queue depth** | When requests are queuing (workers can't keep up) |
| **Custom metrics** | Business metrics (orders/min, active WebSocket connections) |

### Principles
- **Scale out fast, scale in slow** — add capacity quickly (prevent degradation), remove slowly (prevent flapping)
- **Cool-down period** — don't scale again within N seconds of last scale event (avoid oscillation)
- **Pre-warm for known events** — if you know traffic spikes at 9am, scale up before 9am
- **Test scaling** — verify your system actually handles new instances joining (health checks, warm-up time)

### Anti-patterns
- Scaling on wrong metric (scaling on CPU when bottleneck is DB connections)
- No max limit (runaway scaling = runaway cost)
- Scale-in too aggressive (scale down, demand returns, scale up — flapping)
- Cold instances serving traffic immediately (no warm-up — first requests are slow)

---

## References

- [Martin Kleppmann — Designing Data-Intensive Applications, Ch. 6: Partitioning (2017)](https://dataintensive.net/)
- [Google SRE Book — Load Balancing](https://sre.google/sre-book/load-balancing-frontend/)
- [AWS Well-Architected — Performance Efficiency](https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/)

For the well-architected perspective on performance, see [`../../well-architected/performance.md`](../../well-architected/performance.md). For cost implications of scaling decisions, see [`../../well-architected/cost-optimization.md`](../../well-architected/cost-optimization.md).
