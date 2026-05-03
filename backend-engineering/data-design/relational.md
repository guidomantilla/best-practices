# Relational Database Design

Best practices for relational databases (PostgreSQL, MySQL, SQLite, SQL Server).

---

## 1. Schema Design

### Normalization

| Normal Form | Rule | When to denormalize |
|---|---|---|
| **1NF** | No repeating groups, atomic values | Almost never violated |
| **2NF** | No partial dependencies (all non-key columns depend on the full primary key) | Rarely violated |
| **3NF** | No transitive dependencies (non-key columns don't depend on other non-key columns) | Denormalize when joins kill read performance |

### Principles
- **Start normalized** — denormalize only when you have measured performance problems
- **Denormalize for reads** — acceptable when reads vastly outnumber writes and joins are the bottleneck
- **Document deviations** — if you denormalize, comment why (it's intentional, not laziness)

### Naming conventions
- Tables: plural, snake_case (`users`, `order_items`, `payment_methods`)
- Columns: snake_case, descriptive (`created_at`, `email`, `total_amount`)
- Primary keys: `id` (or `{table}_id` if consistency across joins matters)
- Foreign keys: `{referenced_table}_id` (`user_id`, `order_id`)
- Booleans: prefix with `is_` or `has_` (`is_active`, `has_verified_email`)
- Timestamps: suffix with `_at` (`created_at`, `updated_at`, `deleted_at`)

### Anti-patterns
- EAV (Entity-Attribute-Value) tables — kills query performance, no type safety
- Storing JSON blobs in relational columns as primary access pattern (use a document DB)
- Single-character or abbreviated column names (`u_nm`, `crt_dt`)
- `type` column with polymorphic behavior and no constraints
- No foreign keys "for performance" (usually premature optimization that causes data corruption)

---

## 2. Migrations

### Principles
- **Versioned**: every migration has a sequential number or timestamp
- **Idempotent**: running a migration twice doesn't break anything (use `IF NOT EXISTS`, `IF EXISTS`)
- **Backward compatible**: new schema must work with currently running code (old code + new schema during rolling deploy)
- **One-way by default**: don't write down migrations unless you have a proven need
- **Small and frequent**: one change per migration, not 50 changes in one file
- **Tested in staging**: never run untested migrations against production

### Expand-Contract Pattern (zero-downtime migrations)

For breaking changes, split into 3 deploys:
```
1. Expand  — add new column/table (old code ignores it)
2. Migrate — backfill data, deploy new code that uses both
3. Contract — remove old column/table (after all code uses the new one)
```

### Anti-patterns
- Renaming columns in one step (breaks old code during deploy)
- Dropping columns without removing code references first
- Running data migrations (backfills) in the same transaction as schema changes
- Manual migrations (SSH → psql → paste SQL)
- No rollback plan for irreversible migrations
- Migrations that lock tables for minutes (large table ALTER without online DDL)

### Large table operations
- Add columns as `NULL` first (instant in PostgreSQL), backfill later, then add constraint
- Create indexes `CONCURRENTLY` (PostgreSQL) — doesn't lock the table
- For MySQL, use `pt-online-schema-change` or `gh-ost` for large ALTERs

---

## 3. Indexing

### When to index
- Columns in `WHERE` clauses (filter conditions)
- Columns in `JOIN` conditions (foreign keys)
- Columns in `ORDER BY` (avoids filesort)
- Columns in `GROUP BY` (avoids temp table)
- Columns with high selectivity (many distinct values relative to row count)

### When NOT to index
- Small tables (full scan is faster than index lookup)
- Columns with low selectivity (boolean with 50/50 distribution)
- Columns rarely used in queries
- Write-heavy tables where index maintenance exceeds read benefit

### Composite indexes
- **Leftmost prefix rule**: index on `(a, b, c)` is used for queries on `(a)`, `(a, b)`, and `(a, b, c)` — NOT for `(b, c)` alone
- Column order: most selective first, or match the most common query pattern
- A composite index can eliminate the need for multiple single-column indexes

### Index types

| Type | What it does | When |
|---|---|---|
| **B-tree** (default) | Ordered, supports range queries, equality | Most cases |
| **Hash** | Equality only, faster for exact match | Pure key lookups (PostgreSQL: limited use) |
| **GIN** | Generalized Inverted Index | Full-text search, JSONB, arrays |
| **GiST** | Generalized Search Tree | Geospatial, range types |
| **Partial** | Index with WHERE condition | Index only active records, not archived |
| **Covering** | Includes all columns needed by query | Avoids table lookup (index-only scan) |

### Anti-patterns
- Indexing every column (write performance tanks)
- No index on foreign keys (joins do full scans)
- Unused indexes (check `pg_stat_user_indexes` — never used = delete)
- Functions on indexed columns without functional index (`WHERE LOWER(email) = ...` won't use index on `email`)
- Over-relying on ORM-generated queries without checking their plans

---

## 4. Transactions & Isolation Levels

### ACID

| Property | What it guarantees |
|---|---|
| **Atomicity** | All or nothing — partial failure rolls back everything |
| **Consistency** | Data moves from one valid state to another |
| **Isolation** | Concurrent transactions don't see each other's uncommitted data |
| **Durability** | Committed data survives crashes |

### Isolation levels

| Level | Dirty reads | Non-repeatable reads | Phantom reads | Performance |
|---|---|---|---|---|
| **Read Uncommitted** | Yes | Yes | Yes | Fastest |
| **Read Committed** | No | Yes | Yes | Default (PostgreSQL) |
| **Repeatable Read** | No | No | Yes | Default (MySQL InnoDB) |
| **Serializable** | No | No | No | Slowest |

### Principles
- Use the **lowest isolation level that's correct** for your use case
- Most CRUD operations are fine with Read Committed
- Financial/inventory operations may need Serializable or explicit locking
- Prefer **optimistic locking** (version column) over pessimistic (SELECT FOR UPDATE) for low-contention scenarios
- Keep transactions **short** — hold locks for the minimum time necessary

### Optimistic vs Pessimistic locking

| | Optimistic | Pessimistic |
|---|---|---|
| **How** | Version column, check at update time | `SELECT ... FOR UPDATE` |
| **When** | Low contention (conflicts are rare) | High contention (conflicts are frequent) |
| **Failure mode** | Retry on version mismatch | Wait/timeout on lock |

### Anti-patterns
- Serializable everywhere "to be safe" (kills concurrency)
- Long-running transactions (hold locks for seconds/minutes, block other operations)
- No locking strategy on concurrent writes (last-write-wins = data loss)
- Transactions that call external services (HTTP call inside a transaction = lock held during network I/O)

---

## 5. Constraints & Data Integrity

### Use constraints — they're free validation

| Constraint | What it enforces |
|---|---|
| `NOT NULL` | Field must have a value |
| `UNIQUE` | No duplicate values (creates an index) |
| `FOREIGN KEY` | Referential integrity (can't reference non-existent row) |
| `CHECK` | Custom validation (`CHECK (age > 0)`, `CHECK (status IN ('active', 'inactive'))`) |
| `DEFAULT` | Sensible defaults reduce NULLs |
| `EXCLUSION` (PostgreSQL) | No overlapping ranges (scheduling, reservations) |

### Principles
- Let the database enforce invariants — don't rely only on application code
- Application code can have bugs. Constraints never let invalid data through.
- Foreign keys prevent orphaned records
- Unique constraints prevent duplicates better than application-level checks (race conditions)

### Anti-patterns
- No foreign keys (orphaned records accumulate silently)
- No constraints (database becomes a dumb blob store, integrity depends entirely on application code)
- Disabling constraints "for performance" on production (data corruption guaranteed)
- Relying only on ORM validation (bypassed by direct queries, migrations, data imports)
