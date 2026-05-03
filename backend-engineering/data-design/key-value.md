# Key-Value Store Design

Best practices for key-value stores as primary storage (Redis, DynamoDB, Memcached).

Note: for Redis/Memcached as a **caching layer**, see [caching.md](caching.md). This file covers KV stores as the **source of truth**.

---

## 1. Key Design

The key is your access pattern. Design it well.

### Principles
- Keys should be **predictable** — you can construct the key from known information without querying
- Keys should be **namespaced** — prefix with service/entity to avoid collisions
- Keys should be **human-readable** for debugging
- Keep keys **short but descriptive** (memory cost per key in Redis)

### Patterns
```
# Namespace:entity:id
user:session:abc-123
order:status:order-456
rate_limit:api_key:key-789
leaderboard:weekly:2026-W18

# Composite keys for DynamoDB
PK: USER#user-123
SK: ORDER#2026-05-01#order-456
```

### Anti-patterns
- No namespace (all keys in one flat space — collisions, impossible to debug)
- Sequential numeric IDs as keys (predictable, enumerable — security risk)
- Very long keys (wasted memory × millions of keys)
- Encoded/hashed keys that aren't debuggable (`a1b2c3d4` — what is this?)
- Business data in the key that changes (key becomes invalid when data updates)

---

## 2. Data Structures (Redis)

Redis is not just GET/SET. Use the right data structure for the access pattern.

| Structure | What it is | Use case |
|---|---|---|
| **String** | Simple key → value | Sessions, tokens, simple counters, cached JSON |
| **Hash** | Key → field:value map | User profiles, object storage (partial reads/writes) |
| **List** | Ordered sequence (linked list) | Activity feeds, recent items, queues (LPUSH/RPOP) |
| **Set** | Unordered unique collection | Tags, relationships, membership checks |
| **Sorted Set (ZSet)** | Unique items with a score, sorted by score | Leaderboards, rate limiting windows, priority queues |
| **Stream** | Append-only log with consumer groups | Event streaming, message queues (Kafka-lite) |
| **HyperLogLog** | Probabilistic cardinality counting | Unique visitor counts (approximate, tiny memory) |

### Principles
- Use Hashes for objects (read/write individual fields without fetching the whole object)
- Use Sorted Sets for anything ranked or time-ordered
- Use Sets for membership checks (`SISMEMBER` is O(1))
- Use Streams for durable messaging within Redis (consumer groups, acknowledgment)

### Anti-patterns
- Storing serialized JSON in a String when a Hash would allow partial updates
- Using Lists for membership checks (O(N) scan vs O(1) Set)
- Using Strings with counter patterns when INCR/DECR on a dedicated key is simpler
- Not setting memory limits (Redis grows until OOM kill)

---

## 3. TTL & Expiration

### Principles
- **Set TTL on everything that's temporal** — sessions, tokens, rate limit windows, temporary locks
- **No TTL = data lives forever** — only for truly permanent data (and even then, consider lifecycle)
- **TTL at write time** — don't rely on a background cleanup job
- **Refresh TTL on access** for session-like data (sliding expiration)

### Patterns

| Pattern | TTL behavior |
|---|---|
| **Fixed expiration** | Set once, expires at absolute time (OTP codes, invite links) |
| **Sliding window** | Reset TTL on every access (sessions, activity tracking) |
| **Lazy expiration** | Don't expire, but check freshness at read time (soft TTL) |

### Anti-patterns
- No TTL on temporary data (memory grows indefinitely)
- TTL too short (data expires before it's useful — cache thrashing)
- TTL too long (stale data served for hours)
- Relying on `KEYS *` + DEL for cleanup (blocks Redis, O(N))

---

## 4. DynamoDB Patterns

DynamoDB is a key-value/document hybrid with its own design philosophy.

### Single Table Design
- One table for multiple entity types (users, orders, products — all in one table)
- Access patterns drive the schema (model for queries, not for entities)
- Partition Key (PK) + Sort Key (SK) enable flexible access

### Access patterns

```
# Get user
PK: USER#user-123, SK: PROFILE

# Get user's orders
PK: USER#user-123, SK: begins_with("ORDER#")

# Get order details
PK: ORDER#order-456, SK: DETAIL

# Get order items
PK: ORDER#order-456, SK: begins_with("ITEM#")
```

### GSI (Global Secondary Index)
- Inverted index: swap PK and SK for different access patterns
- Sparse index: only items with a specific attribute are indexed
- Overloaded index: GSI PK/SK contain different entity data

### Principles
- Model for access patterns FIRST, not entity relationships
- Partition key determines data distribution — avoid hot partitions
- Use Sort Key for range queries within a partition
- Use GSIs sparingly (cost, eventual consistency)

### Anti-patterns
- One table per entity type (relational thinking in DynamoDB — leads to "joins" via multiple queries)
- Hot partition key (one PK gets all traffic — throttling)
- Scan operations in production (full table scan = expensive, slow)
- Not using Sort Key (forces one item per partition — wastes DynamoDB's power)
- GSI on every field "just in case" (cost, write amplification)

---

## 5. Atomic Operations

### Redis
- `INCR` / `DECR` — atomic counter
- `SETNX` (SET if Not eXists) — distributed locks
- `WATCH` + `MULTI` + `EXEC` — optimistic transactions
- Lua scripts — atomic multi-step operations (execute on server, not round-trips)

### DynamoDB
- Condition expressions — write only if condition is true (`attribute_not_exists(pk)` for create-if-not-exists)
- Atomic counters — `UpdateExpression: SET counter = counter + :val`
- Transactions — `TransactWriteItems` for multi-item atomic writes (up to 100 items)

### Principles
- Use atomic operations for counters, rate limiters, distributed locks
- Prefer server-side atomics (Redis Lua, DynamoDB conditions) over read-modify-write from client
- Distributed locks (Redlock) have caveats — use only when necessary, with short TTL and fencing tokens

### Anti-patterns
- Read → modify in application → write back (race condition without locking)
- Distributed locks without TTL (lock holder crashes → deadlock forever)
- Using Redis transactions (`MULTI/EXEC`) when a Lua script is simpler and faster
