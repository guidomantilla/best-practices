---
name: assess-data-design
description: Review data layer code for schema issues, query anti-patterns, connection mismanagement, caching problems, and data lifecycle gaps. Use when the user asks to review database code, check query performance, assess schema design, review caching strategy, or validate data access patterns. Triggers on requests like "review my database code", "check my queries", "is my schema well designed", "review caching", or "/assess-data-design".
category: hybrid
---

# Data Design Review

Review data layer code for schema issues, query anti-patterns, connection problems, and lifecycle gaps. Produce actionable findings — not generic "add an index" advice.

## Invocation modes

How to interpret the user's prompt and adapt behavior. These rules apply BEFORE running Domain Detection.

### Scope hint (positional path)

If the first non-flag argument after the slash command looks like a path or glob (e.g., `/assess-data-design src/auth/` or `/assess-data-design terraform/`), restrict the autoexplore to that path. Treat everything else in the prompt as additional context.

If no path is provided AND intake is not triggered, after the first short response include a one-liner reminder: *"I'm reviewing the entire codebase. You can scope a future run with `/assess-data-design <path>`."*

### Intake mode

Trigger if the prompt contains either:

- The flag `--ask` (anywhere in the invocation), or
- A natural-language equivalent: *"preguntame"*, *"ask me first"*, *"ask me before"*, *"necesito que me preguntes"*, *"intake first"*, or any phrase clearly requesting questions before the review.

When triggered, BEFORE reading any files, ask these questions in a single message and wait for answers:

**General context (always ask):**

   1. ¿En qué etapa está el proyecto? (early-MVP, growth, production, maintenance)
   2. ¿Cuál es el foco o preocupación principal hoy?
   3. ¿Hay áreas que prefieras que ignore o que ya sabes que no aplican?
   4. ¿Hay algún constraint inmediato? (deadline, regulación, costos, scaling)

**Specific to this skill:**

   5. ¿Stores en uso? (Postgres / MongoDB / Redis / S3 / etc.)
   6. Volumetría aproximada (rows/día, GB total)

After receiving answers, run the autoexplore scoped/biased by the answers. If the user already provided a path (scope hint), do not re-ask about scope — only ask the questions whose answers aren't already implied by the prompt.

### Progress reporting

During execution, announce progress at two levels so the user can see the skill is alive and roughly where it is. Keep messages short — one line each, no decoration.

**Stage announcements** (3 top-level, in this order):

1. *"Exploring codebase..."*
2. *"Cross-referencing knowledge base..."*
3. *"Compiling findings..."*

**Area announcements** (within each stage, only when the area is non-trivial):

- *"  - Reading auth handlers (3 files)..."*
- *"  - Loading backend-engineering/secure-coding/..."*
- *"  - Aggregating findings by severity..."*

Don't announce every individual file. Group by area and emit one line per area as you enter it.

## Context Files

Before reviewing, read the relevant reference documents:

- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/README.md` — index, choosing data store, cross-cutting principles
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/relational.md` — if SQL/relational detected
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/document.md` — if MongoDB/Firestore detected
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/key-value.md` — if Redis/DynamoDB as primary store
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/caching.md` — if caching layer detected
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/search.md` — if Elasticsearch/search detected
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/time-series.md` — if TSDB detected
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/queries.md` — query patterns (always relevant)
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/connections.md` — connection management (always relevant)
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-design/lifecycle.md` — data lifecycle (always relevant)

Only read files relevant to the detected data store(s).

## Review Process

1. **Detect data store(s)**: identify from imports, config, connection strings, ORM usage (PostgreSQL, MongoDB, Redis, Elasticsearch, etc.).
2. **Detect access patterns**: CRUD, read-heavy, write-heavy, time-series, search, caching.
3. **Identify the data model**: schema/models/structs that represent stored data.
4. **Scan against applicable areas**: review against cross-cutting + store-specific rules.
5. **Report findings**: list each issue with impact, location, and fix.
6. **Recommend tooling**: based on detected store, suggest applicable tools.
7. **Offer capabilities**: based on findings, offer additional deliverables.

## Review Areas

### Cross-cutting (all data stores)
1. **N+1 queries** — loops of individual queries that could be batched or joined
2. **Pagination** — unbounded list queries, offset on large datasets
3. **Connection management** — pool configured? Timeouts set? Retry logic?
4. **Query optimization** — EXPLAIN used? Fetching only needed fields? Filtering at DB level?
5. **Transactions** — appropriate isolation? Short duration? No I/O inside transactions?
6. **Data lifecycle** — retention defined? Soft vs hard delete? GDPR compliance?

### Relational-specific
7. **Schema design** — normalization level, naming conventions, constraints, foreign keys
8. **Indexing** — queries without indexes, unused indexes, composite index order
9. **Migrations** — backward compatible? Expand-contract? No-downtime?
10. **Locking** — optimistic vs pessimistic appropriate? Long-held locks?

### Document-specific
7. **Embed vs reference** — appropriate choice for the access pattern?
8. **Unbounded arrays** — documents growing without limit?
9. **Schema evolution** — version field? Handling missing fields?

### Key-value-specific
7. **Key design** — namespaced? Predictable? Debuggable?
8. **Data structures** — using the right Redis type for the pattern?
9. **TTL** — set on temporal data? Memory growth controlled?

### Caching-specific
7. **Invalidation strategy** — TTL? Event-based? Both?
8. **Cache stampede** — protection on hot keys?
9. **Cache-DB consistency** — what happens on write?

These areas are the minimum review scope. Flag additional data issues beyond these based on the detected store, scale, or access patterns.

## Impact Assessment

| Impact | Criteria |
|---|---|
| **High** | N+1 on hot paths, no connection pool, no pagination on large tables, data corruption risk (no constraints, no locking), GDPR non-compliance |
| **Medium** | Missing indexes on common queries, suboptimal cache strategy, no TTL on temporal data, no retry on transient failures |
| **Low** | Naming inconsistencies, unused indexes, minor schema issues, over-fetching on low-traffic endpoints |

## Detection Patterns

### N+1 in ORM
```python
# BAD — N+1 (lazy loading in loop)
orders = Order.objects.all()
for order in orders:
    print(order.customer.name)  # ← 1 query per order

# GOOD — eager loading
orders = Order.objects.select_related('customer').all()
```

### No connection pool
```go
// BAD — new connection per request
func handler(w http.ResponseWriter, r *http.Request) {
    db, _ := sql.Open("postgres", connStr)  // ← opens new connection every time
    defer db.Close()
}

// GOOD — shared pool (opened once at startup)
var db *sql.DB  // package-level, initialized in main()
```

### Unbounded query
```javascript
// BAD — returns all users (could be millions)
const users = await db.collection('users').find({}).toArray();

// GOOD — paginated
const users = await db.collection('users').find({}).limit(20).skip(offset).toArray();
```

### Cache without invalidation
```python
# BAD — cache set but never invalidated on write
def get_user(user_id):
    cached = redis.get(f"user:{user_id}")
    if cached: return cached
    user = db.query(User, id=user_id)
    redis.set(f"user:{user_id}", user)  # ← no TTL, no invalidation on update
    return user

def update_user(user_id, data):
    db.update(User, id=user_id, **data)
    # ← forgot to invalidate cache! Stale data served until restart
```

## Tooling

### Query Analysis
| Tool | What it does | For |
|---|---|---|
| `EXPLAIN ANALYZE` | Query execution plan | PostgreSQL, MySQL |
| `pg_stat_statements` | Most time-consuming queries | PostgreSQL |
| `mongosh .explain()` | Query plan | MongoDB |
| **Datadog APM / query insights** | Query performance tracking | Any |

### Schema & Migrations
| Tool | What it does | For |
|---|---|---|
| **Flyway / Liquibase** | Versioned migrations | Java, multi-language |
| **golang-migrate** | Migration tool for Go | Go |
| **Alembic** | SQLAlchemy migrations | Python |
| **Prisma Migrate** | TypeScript ORM migrations | TypeScript |
| **Atlas** | Declarative schema management | Multi-language |

### Connection Pooling
| Tool | What it does | For |
|---|---|---|
| **PgBouncer** | External connection pooler | PostgreSQL |
| **ProxySQL** | Connection pooler + routing | MySQL |
| **RDS Proxy** | Managed pooler | AWS |

### Monitoring
| Tool | What it does |
|---|---|
| **pg_stat_user_indexes** | Detect unused indexes (PostgreSQL) |
| **Redis INFO** | Memory, connected clients, hit rate |
| **slow_query_log** | Queries exceeding threshold |

## Output Format

### Findings

For each finding:

```
### [IMPACT] — Short description
- **File**: models/user.go:42 / queries/orders.sql:15 / cache/redis.py:30
- **Area**: which review area
- **Issue**: what's wrong
- **Fix**: specific action to take (with query/code snippet if applicable)
- **Tool**: which tool helps diagnose or prevent this
```

### Summary

```
## Summary
- High: N
- Medium: N
- Low: N
- Data store(s): [PostgreSQL | MongoDB | Redis | Elasticsearch | DynamoDB | ...]
- ORM/client: [detected]
- Connection pool: [configured | missing | misconfigured]
- N+1 detected: [yes (count) | no]
- Pagination: [present | partial | absent]
- Cache layer: [present | absent]
- Data lifecycle: [defined | partial | undefined]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable:

```
## What I Can Generate

Based on this review, I can also:

### For reproducibility (deterministic, CI-ready)
- [ ] **Generate a CI workflow** for SQL/schema linting and slow-query detection (EXPLAIN regression checks against the recommended index plan). Deterministic counterpart to the structural review.

### For deeper exploration (LLM, non-deterministic)
- [ ] Optimize detected slow queries (with EXPLAIN analysis)
- [ ] Design indexes for the detected query patterns
- [ ] Generate a connection pool configuration for this stack
- [ ] Design a caching strategy for the detected read patterns
- [ ] Create a data retention policy for the detected data types
- [ ] Propose schema migrations for identified issues (expand-contract)
- [ ] Generate a Redis key design document
- [ ] Design pagination for detected list endpoints

Select which ones you'd like me to generate.

## What NOT to Do

- Don't recommend changing data stores unless fundamentally wrong (don't say "switch to MongoDB" on a working PostgreSQL schema)
- Don't flag every query without EXPLAIN evidence (measure before optimizing)
- Don't recommend indexes without knowing the write volume (indexes aren't free)
- Don't prescribe a specific ORM or client library
- Don't flag schema issues without understanding the access pattern (denormalization may be intentional)
- Don't recommend caching for everything (some queries are fast enough without it)
- Don't flag code you haven't read
- Don't assume scale — a 1000-row table doesn't need pagination optimization

## Invocation examples

These cover the most useful patterns for this skill. The full list (7 patterns + bonus on context formats) is in the [Invocation patterns section of the README](../../README.md#invocation-patterns).

- **Scoped** — `/assess-data-design migrations/ models/`
- **Narrative** — `/assess-data-design Postgres + Redis + S3, foco performance y data lifecycle`
- **Deterministic** — `/assess-data-design y dame un script para validar que las queries respeten los índices`
