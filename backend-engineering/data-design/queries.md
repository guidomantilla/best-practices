# Query Patterns (Cross-Type)

Best practices for querying data stores — applicable across relational, document, KV, and search.

---

## 1. N+1 Problem

The most common performance issue in data access.

### The problem
```
1 query to get list of orders
N queries to get customer for each order (one per order)
= N+1 total queries
```

### Solutions by context

| Context | Solution |
|---|---|
| **SQL (ORM)** | Eager loading (`JOIN`), or batch loading (`WHERE id IN (...)`) |
| **SQL (raw)** | JOIN in the original query, or separate batch query |
| **GraphQL** | DataLoader (batches resolver calls within one request) |
| **Document DB** | Embed related data, or batch `$in` query |
| **API calls** | Batch endpoint (`GET /users?ids=1,2,3`), or include/expand param |

### Anti-patterns
- Lazy loading in loops (ORM default — each access triggers a query)
- Not monitoring query count per request (N+1 is invisible until you count)
- Fixing with cache only (masks the problem, doesn't solve it)

---

## 2. Pagination

Every list endpoint/query MUST be paginated.

### Strategies

| Strategy | How | Pros | Cons |
|---|---|---|---|
| **Offset** | `LIMIT 20 OFFSET 40` / `?page=3&per_page=20` | Simple, jumpable | Slow on large offsets (DB skips N rows), inconsistent with inserts |
| **Cursor (keyset)** | `WHERE id > last_seen_id LIMIT 20` / `?after=cursor` | Fast regardless of depth, stable | Can't jump to arbitrary page, cursor is opaque |
| **Seek** | `WHERE (created_at, id) > (last_ts, last_id) LIMIT 20` | Fast, composite ordering | More complex, multiple columns |

### When to use which

| Use case | Strategy |
|---|---|
| Admin panel with page numbers | Offset (users tolerate slowness, datasets are moderate) |
| Infinite scroll / feed | Cursor (fast, stable as new items are added) |
| API for large datasets | Cursor (offset becomes unusable beyond page 500) |
| Export / batch processing | Cursor (process in chunks without skipping/duplicating) |

### Anti-patterns
- No pagination (returns all records — DoS vector, memory bomb)
- Offset on millions of rows (`OFFSET 1000000` = DB reads and discards 1M rows)
- No max page size (client requests `per_page=999999`)
- No indication of "has more" (client doesn't know when to stop)

---

## 3. Bulk Operations

Handling large batches efficiently.

### Principles
- **Batch inserts**: insert multiple rows in one statement/call, not one-by-one
- **Batch updates**: use `UPDATE ... WHERE id IN (...)` or upsert, not individual updates in a loop
- **Batch reads**: `WHERE id IN (...)` or `$in`, not individual lookups
- **Chunk large batches**: don't send 1M rows in one statement — chunk into 1000-row batches

### Batch sizes

| Operation | Recommended batch size | Why |
|---|---|---|
| SQL INSERT | 100-1000 rows per statement | Statement size limits, transaction size |
| SQL UPDATE | 100-500 rows per statement | Lock contention, undo log |
| Redis pipeline | 100-1000 commands | Network round-trip savings |
| DynamoDB BatchWrite | 25 items (API limit) | Hard limit |
| Elasticsearch bulk | 5-15 MB per request | Optimal for indexing throughput |

### Anti-patterns
- Inserting rows one at a time in a loop (N round-trips instead of 1)
- One massive transaction for 1M rows (lock held too long, OOM risk)
- No error handling per batch (one bad row fails the entire batch of 10K)
- No progress tracking (3-hour bulk job fails at 95% — no way to resume)

---

## 4. Query Optimization

### Universal principles
- **Explain your queries**: every DB has `EXPLAIN` / query profiler — use it
- **Only fetch what you need**: `SELECT *` fetches 50 columns when you need 3
- **Filter at the DB, not in app**: don't fetch 10K rows to filter in Python — let the DB filter
- **Count is expensive**: `SELECT COUNT(*)` on large tables scans the whole table (consider approximate counts)
- **Avoid work inside loops**: aggregations, joins, subqueries — let the DB handle set operations

### SQL-specific
- Use `EXISTS` instead of `COUNT > 0` (short-circuits on first match)
- Use `LIMIT` when you only need N results (even for existence checks)
- Avoid `SELECT DISTINCT` as a fix for bad joins (fix the join instead)
- Avoid correlated subqueries in WHERE (executes once per outer row)
- Use CTEs for readability, but know they may not optimize the same as inlined subqueries (DB-dependent)

### Document DB-specific
- Use projection (return only fields you need)
- Avoid `$lookup` in hot paths (it's a JOIN — defeats document model)
- Use covered queries (query satisfied entirely by the index)

### Anti-patterns
- Never running EXPLAIN (guessing performance instead of measuring)
- `SELECT *` everywhere (fetches blobs, large text fields you don't need)
- Application-side filtering of large result sets
- Unbounded queries without LIMIT
- Nested loops of queries that could be a single JOIN or batch

---

## 5. Transactions in Queries

### Principles
- **Keep transactions short**: do work, commit. Don't hold open during HTTP calls, user input, or heavy computation.
- **Don't do I/O inside transactions**: no HTTP calls, no file reads, no message publishing inside a DB transaction.
- **Retry on serialization failure**: if using SERIALIZABLE or optimistic locking, handle retries in application code.
- **Read-only queries don't need explicit transactions** (unless you need snapshot consistency across multiple reads).

### Anti-patterns
- HTTP call inside transaction (network timeout = transaction held open = locks held)
- Transaction wrapping a read-only query (unnecessary overhead in most isolation levels)
- No retry logic for deadlock/serialization failures (app crashes instead of retrying)
- Very long transactions for batch processing (hold locks for minutes)
