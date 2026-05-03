# Connection Management (Cross-Type)

Best practices for managing database connections — applicable to relational, document, KV, and search.

---

## 1. Connection Pools

Every database client should use a connection pool. Never open/close connections per request.

### How pools work
```
Application starts → pool opens N connections
Request arrives → borrows connection from pool
Request completes → returns connection to pool
(connection stays open, reused by next request)
```

### Pool sizing

| Parameter | What it controls | Guideline |
|---|---|---|
| **Min connections** | Connections kept open even when idle | 2-5 (avoid cold-start latency) |
| **Max connections** | Maximum concurrent connections | See formula below |
| **Idle timeout** | Close idle connections after N seconds | 30-300s (balance between reuse and resource waste) |
| **Max lifetime** | Close connection after N time regardless (prevents stale connections) | 30-60 minutes |
| **Connection timeout** | How long to wait for a connection from pool | 5-30 seconds (fail fast) |

### Pool size formula (PostgreSQL guideline)
```
Optimal pool size = (2 × CPU cores) + number of disks

Example: 4-core server with SSD = (2 × 4) + 1 = 9 connections
```

For most services: **5-20 connections per service instance** is a reasonable starting point. Measure and adjust.

### Total connections math
```
Max DB connections = pool_size × number_of_service_instances

Example: 10 pool × 5 instances = 50 connections
PostgreSQL default max_connections = 100

If you have 3 services × 5 instances × 10 pool = 150 → exceeds max → use PgBouncer
```

### Anti-patterns
- No pool (open/close per request — connection overhead dominates latency)
- Pool too large (DB overwhelmed — too many connections = context switching, memory waste)
- Pool too small (requests queue waiting for a connection — artificial bottleneck)
- No max lifetime (connections go stale after DB restart/failover — silent errors)
- No connection timeout (requests wait forever for a connection when pool is exhausted)

---

## 2. Connection Failures & Retry

### Principles
- **Connections will fail** — network blips, DB restarts, failovers. Your code must handle this.
- **Retry with backoff**: exponential backoff with jitter (not immediate retry, not fixed interval)
- **Validate on borrow**: pool checks if connection is alive before handing it to application (`testOnBorrow`, `ping`)
- **Distinguish transient vs permanent failures**: retry transient (network timeout), don't retry permanent (auth failure, DB doesn't exist)

### Retry pattern
```
attempt 1: immediate
attempt 2: wait 100ms + jitter
attempt 3: wait 400ms + jitter
attempt 4: wait 1600ms + jitter
give up after N attempts → return error
```

### Anti-patterns
- No retry (one transient failure = request fails permanently)
- Infinite retry without backoff (hammers the DB when it's already struggling)
- Retrying on permanent errors (wrong password retried 100 times)
- No jitter (all instances retry at exactly the same time after a DB blip — thundering herd)
- Retrying inside a transaction (transaction is already aborted — retry must start a new one)

---

## 3. Timeouts

### Types

| Timeout | What it controls | Guideline |
|---|---|---|
| **Connection timeout** | How long to establish a new connection | 3-10s (fail fast if DB is unreachable) |
| **Query/Statement timeout** | Max execution time per query | 5-30s for web requests, longer for batch |
| **Idle connection timeout** | How long an idle connection lives in pool | 30-300s |
| **Transaction timeout** | Max time a transaction can be open | 30-60s (prevent long-held locks) |

### Principles
- **Every database call must have a timeout** — no unbounded waits
- **Query timeout prevents runaway queries** — a missing WHERE clause on a 100M row table shouldn't block for 10 minutes
- **Set timeouts at the pool/client level** — not per query (default protection for all queries)
- **Shorter for user-facing, longer for batch** — web request timeout: 5-15s, batch job: 5-30 minutes

### Anti-patterns
- No query timeout (runaway query consumes all connections, blocks everything)
- Timeout too short for legitimate queries (complex reports fail every time)
- No connection timeout (application hangs when DB is unreachable — no error, just wait)
- Timeout without error handling (timeout fires but application doesn't handle it gracefully)

---

## 4. Health Checks

### Principles
- **Liveness**: can we connect to the DB at all? (TCP connection succeeds)
- **Readiness**: can we execute queries? (simple `SELECT 1` succeeds within timeout)
- **Don't use expensive queries for health checks** — `SELECT 1` or `PING`, not a real query

### Integration with orchestrators
- K8s readiness probe → checks DB connectivity → pod removed from service if DB is down
- K8s liveness probe → checks process health (not DB) → restart pod only if process is broken
- Don't fail liveness on DB connection failure (or K8s restarts your pod in a loop during DB maintenance)

### Anti-patterns
- No health check (service accepts traffic but can't reach DB — returns 500 on every request)
- Health check that runs a real query (adds load, may be slow, may timeout)
- Liveness check tied to DB (DB maintenance = all pods restart = cascade failure)
- Health check that doesn't have its own timeout (hangs, orchestrator marks it as failed)

---

## 5. Connection Poolers (External)

When service instances × pool size > DB max connections, use an external pooler.

| Tool | For | How it helps |
|---|---|---|
| **PgBouncer** | PostgreSQL | Multiplexes thousands of app connections into fewer DB connections |
| **ProxySQL** | MySQL | Connection pooling + query routing + failover |
| **Odyssey** | PostgreSQL | Multi-threaded alternative to PgBouncer |
| **RDS Proxy** | AWS RDS (PostgreSQL/MySQL) | Managed pooler with IAM auth + failover handling |

### Pooling modes (PgBouncer)

| Mode | What it does | When |
|---|---|---|
| **Transaction** | Connection returned to pool after each transaction | Most applications (default recommendation) |
| **Session** | Connection held for entire client session | When using session-level features (prepared statements, temp tables) |
| **Statement** | Connection returned after each statement | Multi-statement transactions won't work (rarely used) |

### When to use an external pooler
- Serverless/Lambda functions (hundreds of concurrent invocations, each needs a connection)
- Many service instances with their own pools exceeding DB limits
- Connection failover handling (pooler handles reconnection, app doesn't need to)

---

## 6. Multi-Database & Replicas

### Read replicas
- Route read queries to replicas, writes to primary
- Accept eventual consistency on reads (replicas may lag by ms/seconds)
- Use for: heavy reporting queries, read-heavy APIs, geographic distribution

### Principles
- **Separate connection pools** for primary and replica(s)
- **Application logic decides** which pool to use (write → primary, read → replica)
- **Handle replication lag**: after a write, read from primary for that user (read-your-writes consistency)
- **Failover**: if primary fails and replica is promoted, application must reconnect to new primary

### Anti-patterns
- All queries to primary (replica exists but unused — wasted resources)
- Reads from replica immediately after write (stale data — user doesn't see their own change)
- No monitoring of replication lag (replica falls behind, reads return stale data silently)
- Single connection string for both reads and writes (can't split traffic)
