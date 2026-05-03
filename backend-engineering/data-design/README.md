# Data Design Best Practices

Principles for choosing, designing, and operating data stores. How to store, retrieve, and manage data correctly. Language-agnostic — applicable to any backend service.

This is the **index**. Each topic has its own file with specific patterns and anti-patterns.

---

## Scope

| File | What it covers |
|---|---|
| [relational.md](relational.md) | Relational databases — normalization, schema, migrations, indexing, transactions, isolation levels |
| [document.md](document.md) | Document stores — embedding vs referencing, schema evolution, denormalization |
| [key-value.md](key-value.md) | Key-value stores as primary storage — key design, TTL, data structures, Redis/DynamoDB |
| [caching.md](caching.md) | Caching as a layer — invalidation, cache-aside, write-through, stampede, hot keys |
| [search.md](search.md) | Search engines — indexing, mapping, relevance, analyzers |
| [time-series.md](time-series.md) | Time-series databases — retention, downsampling, tags vs fields |
| [queries.md](queries.md) | Query patterns (cross-type) — N+1, pagination, bulk ops, optimization |
| [connections.md](connections.md) | Connection management (cross-type) — pools, timeouts, retry, health checks |
| [lifecycle.md](lifecycle.md) | Data lifecycle — retention, archival, soft/hard delete, GDPR, classification |

---

## Choosing the Right Data Store

No single database fits all use cases. Choose based on access pattern, not familiarity.

| Data store type | Best for | Not ideal for |
|---|---|---|
| **Relational (PostgreSQL, MySQL)** | Structured data, relationships, transactions, complex queries, ACID guarantees | Unstructured data, horizontal scaling beyond limits, high-write time-series |
| **Document (MongoDB, Firestore)** | Semi-structured data, flexible schema, hierarchical data, rapid iteration | Complex joins, strict consistency across documents, transactions across collections |
| **Key-Value (Redis, DynamoDB)** | Fast lookups by key, sessions, counters, rate limiting, simple access patterns | Complex queries, relationships, aggregations, ad-hoc reporting |
| **Search (Elasticsearch, Meilisearch)** | Full-text search, faceted filtering, fuzzy matching, autocomplete | Primary storage, transactions, strong consistency |
| **Time-Series (TimescaleDB, InfluxDB)** | Metrics, IoT, logs, events with timestamps, time-based aggregations | Non-temporal data, complex relationships, transactional workloads |
| **Graph (Neo4j, Neptune)** | Relationships ARE the data — social networks, recommendations, fraud detection | Simple CRUD, tabular data, time-series |

### Decision framework

1. **What's the primary access pattern?** Lookup by key → KV. Complex queries with joins → Relational. Full-text search → Search engine. Time-based aggregation → Time-series.
2. **What consistency do you need?** Strong (financial) → Relational. Eventual (social feed) → Document/KV.
3. **What's the write pattern?** High-volume append → Time-series/KV. Transactional → Relational.
4. **What's the query pattern?** Known key → KV. Ad-hoc → Relational. Text → Search. Graph traversal → Graph.
5. **Will it grow beyond one machine?** If yes from day 1 → consider DynamoDB, Cassandra, or sharded solutions.

### Polyglot persistence

Most production systems use multiple data stores — each for what it does best:
```
PostgreSQL (primary, transactions) + Redis (cache, sessions) + Elasticsearch (search) + S3 (files)
```

This is fine. The anti-pattern is using one store for everything when it clearly doesn't fit.

---

## Cross-Cutting Principles

These apply regardless of data store type.

### 1. Schema is a Contract

Your schema is a contract with every service that reads or writes to it.

- Schema changes should be as careful as API changes (they can break consumers)
- Migrations should be backward compatible (old code must work with new schema during deploy)
- Document your schema — even in "schemaless" databases, there's an implicit schema

### 2. Data Modeling Drives Performance

How you model data determines what's fast and what's slow.

- Model for your **read patterns**, not for normalization purity
- Denormalize when reads vastly outnumber writes and joins are killing performance
- Don't optimize prematurely — start normalized (relational) or embedded (document), measure, then optimize

### 3. Indexes Are Not Free

Every index speeds up reads and slows down writes.

- Index what you query. Don't index what you don't.
- Composite indexes: column order matters (leftmost prefix rule)
- Monitor unused indexes — they cost write performance and storage for nothing
- Too many indexes = slow writes. Too few = slow reads. Measure.

### 4. Connections Are a Shared Resource

Database connections are finite and expensive.

- Always use connection pools
- Set appropriate pool sizes (not too large, not too small)
- Handle connection failures gracefully (retry with backoff)
- Close/return connections promptly (don't hold during long operations)

### 5. Consistency vs Availability

The CAP theorem trade-off — you can't have both during a partition.

| Choice | What you get | When |
|---|---|---|
| **CP (Consistency + Partition tolerance)** | Every read returns the latest write, even during failures | Financial data, inventory, auth |
| **AP (Availability + Partition tolerance)** | System always responds, but may return stale data | Social feeds, analytics, recommendations |

In practice, most systems need different consistency levels for different operations within the same application.

---

## Tooling (Cross-Type)

| Category | Tool | What it does |
|---|---|---|
| **Migration** | Flyway, Liquibase, golang-migrate, Alembic, Prisma Migrate | Versioned schema migrations |
| **ORM / Query builder** | SQLAlchemy, Prisma, GORM, Diesel, Exposed | Type-safe data access |
| **Monitoring** | pg_stat_statements, slow query log, MongoDB Profiler | Query performance visibility |
| **Connection pooling** | PgBouncer, ProxySQL | External connection pooling |
| **Backup** | pg_dump, mongodump, cloud-native snapshots | Data backup and recovery |

---

## References

- [Martin Kleppmann — *Designing Data-Intensive Applications* (2017)](https://dataintensive.net/)
- [Use The Index, Luke — SQL Indexing Guide](https://use-the-index-luke.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation — Data Types](https://redis.io/docs/data-types/)
- [MongoDB Schema Design Best Practices](https://www.mongodb.com/docs/manual/data-modeling/)
