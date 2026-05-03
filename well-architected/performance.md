# Performance Efficiency

How to use resources efficiently to meet system requirements, and maintain efficiency as demand changes.

---

## Principles

- **Evaluate build vs managed vs self-hosted**: managed services reduce ops burden at small scale, but self-hosted can be significantly cheaper at large scale. Calculate total cost of ownership, not just sticker price. Cloud vendor frameworks recommend managed — consider the source.
- **Go global in minutes**: deploy closer to users (CDN, edge, multi-region)
- **Use serverless where it fits**: eliminate idle capacity for sporadic workloads
- **Experiment more often**: benchmark, measure, compare — don't guess
- **Mechanical sympathy**: understand how the underlying technology works to use it efficiently

---

## Design Principles (Converged AWS/Azure/GCP)

### 1. Right Compute

| Question | Action |
|---|---|
| CPU-bound? | More/faster CPUs, horizontal scaling |
| Memory-bound? | Larger instances, optimize data structures |
| I/O-bound? | Faster storage (SSD/NVMe), async I/O, connection pooling |
| Network-bound? | Compress payloads, reduce round-trips, move compute closer to data |
| Idle most of the time? | Serverless / scale-to-zero |

### 2. Caching

Reduce repeated computation and I/O:

| Layer | What to cache | Tool examples |
|---|---|---|
| **Client/Browser** | Static assets, API responses | Cache-Control headers, service worker |
| **CDN** | Static assets, dynamic content (with short TTL) | CloudFront, Cloudflare |
| **API/Application** | Query results, computed values, sessions | Redis, Memcached |
| **Database** | Query plans, buffer pool | Built-in (shared_buffers, query cache) |

Caching pitfalls: invalidation complexity, stale data, stampede on hot key expiry, cache-DB inconsistency.

### 3. Database Performance

- **Index what you query** — but not everything (indexes cost writes)
- **Query optimization**: EXPLAIN before optimizing, avoid N+1, use pagination
- **Connection pooling**: always — connections are expensive to create
- **Read replicas**: offload read-heavy traffic from primary
- **Denormalize for reads**: when JOIN performance is the bottleneck (trade write complexity for read speed)
- **Right database for the access pattern**: don't force SQL on key-value workloads or vice versa

### 4. Network Performance

- **Reduce round-trips**: batch requests, GraphQL (one request instead of N), connection reuse (HTTP/2, keep-alive)
- **Compress payloads**: gzip/brotli for HTTP, protobuf instead of JSON for high-throughput service-to-service
- **Move compute closer to data**: don't fetch 1M rows across the network to process 10 — filter at the source
- **CDN for static assets**: serve from edge, not from origin on every request
- **DNS optimization**: pre-resolve, cache DNS, use low-TTL for failover

### 5. Application Performance

- **Async where possible**: don't make the user wait for email sending, report generation, image processing
- **Lazy loading**: load data only when needed (pagination, lazy UI components, on-demand imports)
- **Efficient algorithms**: O(n) vs O(n²) matters at scale — profile before optimizing
- **Resource limits**: bound memory, connections, threads, goroutines — prevent resource exhaustion
- **Profile, don't guess**: use profilers (pprof, py-spy, Chrome DevTools) to find actual bottlenecks

### 6. Monitoring Performance

| What to measure | Why |
|---|---|
| **Latency** (p50, p90, p99) | Averages lie — tail latency is what users feel |
| **Throughput** (RPS) | Capacity ceiling |
| **Saturation** | How full are resources (CPU, memory, connections, queue depth) |
| **Error rate under load** | System stability at scale |
| **Performance over time** | Detect regressions early (deploy X increased p99 by 50ms) |

Set performance budgets and alert on violations — not just at deploy time, continuously.

---

## Checklist

```
[ ] Performance baselines established (latency, throughput, resource usage)
[ ] Caching implemented where reads significantly outnumber writes
[ ] Database queries optimized (EXPLAIN run on slow queries, indexes verified)
[ ] Connection pooling configured on all database connections
[ ] Async processing for non-user-blocking work
[ ] CDN for static assets and cacheable responses
[ ] Payload compression enabled (gzip/brotli)
[ ] Performance testing automated (load tests on schedule or per release)
[ ] Performance budgets defined and monitored (p99 latency, bundle size)
[ ] Profiling done before optimizing (don't guess bottlenecks)
[ ] Right compute type for workload (CPU/memory/IO bound matched to instance type)
[ ] Auto-scaling configured based on actual demand signals
```

---

## Anti-patterns

- Optimizing without measuring ("I think this query is slow" — run EXPLAIN first)
- Caching everything (some data is cheap to compute and not worth cache complexity)
- Premature optimization (the system serves 10 users — don't shard the database yet)
- Averages instead of percentiles (p50 is 50ms but p99 is 5 seconds — users feel the p99)
- No performance tests (discover performance issues in production from user complaints)
- Vertical scaling as the only strategy (bigger machine has a ceiling — horizontal scales further)
- Over-provisioned "just in case" (paying for 10x capacity you'll never use — see cost-optimization.md)
- Same instance type for every workload (CPU-optimized for a memory-bound workload = waste)
- N+1 queries ignored because "it works fine in dev" (10 users vs 10,000 users)

---

## References

- [AWS — Performance Efficiency Pillar](https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/)
- [Azure — Performance Efficiency](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/)
- [Google — Performance Optimization](https://cloud.google.com/architecture/framework/performance-optimization)
- [Brendan Gregg — Systems Performance (2020)](https://www.brendangregg.com/systems-performance-2nd-edition-book.html)
