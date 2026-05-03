# Caching Best Practices

Best practices for caching as a **layer** — data duplicated for speed, with another store as the source of truth.

Note: for Redis/Memcached as **primary storage**, see [key-value.md](key-value.md).

---

## 1. Caching Strategies

| Strategy | How it works | Best for |
|---|---|---|
| **Cache-Aside (Lazy Loading)** | App checks cache → miss → query DB → write to cache → return | Most read-heavy workloads. Simple, widely used. |
| **Write-Through** | App writes to cache AND DB simultaneously | Data that must be fresh in cache immediately after write |
| **Write-Behind (Write-Back)** | App writes to cache, async process writes to DB later | High write throughput (risk: data loss if cache crashes before flush) |
| **Read-Through** | Cache itself fetches from DB on miss (transparent to app) | When cache library supports it (e.g., NCache, Hazelcast) |
| **Refresh-Ahead** | Cache proactively refreshes entries before they expire | Predictable access patterns, latency-sensitive hot data |

### Choosing
- **Cache-aside** is the default for most applications (simple, explicit, no magic)
- **Write-through** when you can't afford a cache miss after a write (user updates profile → immediately sees new data)
- **Write-behind** only when you accept the risk of data loss (metrics, analytics, non-critical)

---

## 2. Cache Invalidation

The hardest problem in computer science (after naming things).

### Strategies

| Strategy | How | Trade-off |
|---|---|---|
| **TTL-based** | Entry expires after N seconds | Simple, but stale data until TTL expires |
| **Event-based** | Invalidate on write (publish event, consumer deletes cache key) | Fresh data, but complex (need event system) |
| **Manual** | Explicitly delete/update cache on write | Simple for single-service, but error-prone (forget to invalidate) |
| **Version-based** | Key includes version/timestamp, new version = new key | Never invalidate — old keys expire naturally via TTL |

### Principles
- **Prefer TTL + event-based**: TTL as safety net (data eventually refreshes even if event fails), events for immediacy
- **Invalidate, don't update**: delete the cache entry on write, let next read repopulate (simpler, fewer race conditions)
- **Short TTL for mutable data**: 30s-5min for data that changes. Long TTL only for truly static data.
- **Cache stampede protection**: when a hot key expires, thousands of requests hit the DB simultaneously

### Anti-patterns
- No invalidation strategy (cache serves stale data for hours/days)
- Updating cache directly without updating DB (cache becomes inconsistent source)
- TTL of 24h on data that changes every minute
- No TTL at all (cache grows unbounded, stale data forever)

---

## 3. Cache Stampede (Thundering Herd)

When a hot key expires and hundreds of concurrent requests all miss the cache simultaneously → all hit the DB → DB overloaded.

### Solutions

| Solution | How |
|---|---|
| **Lock/Mutex** | First request to miss acquires a lock, fetches from DB, populates cache. Others wait. |
| **Refresh-ahead** | Repopulate cache BEFORE it expires (background refresh at 80% of TTL) |
| **Stale-while-revalidate** | Serve stale value while one request refreshes in the background |
| **Probabilistic early expiration** | Each request has a small random chance of refreshing early (distributes refresh over time) |

### Anti-patterns
- No protection on hot keys (DB melts on every cache expiration)
- Lock without timeout (lock holder crashes → all requests wait forever)
- Ignoring the problem because "it hasn't happened yet" (it will, at scale)

---

## 4. What to Cache

### Good candidates
- Expensive queries (joins across multiple tables, aggregations)
- Frequently read, rarely written data (product catalog, user profiles, config)
- External API responses (rate-limited third-party calls)
- Computed/derived values (user permissions after complex resolution)

### Bad candidates
- Highly dynamic data (real-time counters — use Redis INCR instead of cache-aside)
- User-specific data with low reuse (caching one user's dashboard that only they see)
- Data that must be strictly consistent (account balance — stale cache = financial errors)
- Small/fast queries (caching something that takes 1ms to query — overhead of cache logic > benefit)

### The heuristic
Cache when: `(query cost × frequency) > (cache memory cost + invalidation complexity)`

---

## 5. Cache Levels

Caching can happen at multiple layers simultaneously:

| Level | Where | Examples | TTL |
|---|---|---|---|
| **Browser/Client** | User's device | HTTP Cache-Control headers, localStorage | Minutes to days |
| **CDN** | Edge network | Cloudflare, CloudFront, Vercel Edge | Seconds to hours |
| **API Gateway** | Request layer | Response caching by URL/params | Seconds to minutes |
| **Application** | In-memory (same process) | Go map, Python dict, Node.js lru-cache | Seconds (process lifetime) |
| **Distributed cache** | Shared across instances | Redis, Memcached | Seconds to hours |
| **Database** | Query result cache | PostgreSQL shared_buffers, MySQL query cache | Automatic |

### Principles
- Cache at the **highest level** possible (closer to client = faster, less load)
- Multiple cache levels compound — but also compound invalidation complexity
- In-memory (process-local) cache doesn't need network round-trip — fastest, but not shared
- Distributed cache (Redis) is shared across instances — slightly slower, but consistent

---

## 6. Hot Keys

A single cache key that receives disproportionate traffic.

### Problems
- One Redis node handles all requests for that key (can't distribute)
- Network saturation to that node
- If it expires → stampede

### Solutions
- **Key replication**: duplicate the key across multiple nodes (`hot_key:1`, `hot_key:2`, random read)
- **Local caching**: cache the hot key in application memory (with short TTL) to reduce Redis calls
- **Read replicas**: route reads to replicas (Redis Cluster, ElastiCache read replicas)

---

## 7. Metrics & Monitoring

### What to measure

| Metric | What it means | Healthy |
|---|---|---|
| **Hit rate** | % of requests served from cache | > 90% for read-heavy workloads |
| **Miss rate** | % of requests that go to DB | < 10% (if higher, cache is ineffective or TTL too short) |
| **Eviction rate** | Keys evicted due to memory pressure | Low (if high, increase memory or reduce TTL) |
| **Latency (p99)** | Cache response time | < 1ms for Redis |
| **Memory usage** | How full is the cache | < 80% (leave headroom for spikes) |

### Anti-patterns
- No cache metrics (no idea if caching is working or just burning memory)
- Hit rate < 50% (cache isn't helping — wrong data cached, TTL too short, or workload isn't cacheable)
- Not alerting on eviction rate (sudden evictions = memory pressure = performance degradation)
