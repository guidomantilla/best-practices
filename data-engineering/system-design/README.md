# Data Engineering System Design

Architecture decisions for data systems. How to move, transform, store, and serve data at scale.

For backend system design (microservices, Clean Architecture, integration patterns), see [`../../backend-engineering/system-design/`](../../backend-engineering/system-design/README.md). For CDC (Change Data Capture), see [`../../backend-engineering/system-design/integration-level.md`](../../backend-engineering/system-design/integration-level.md) §12.

Data engineering system design is fundamentally different: it's **OLAP** (analytical processing), not **OLTP** (transactional processing).

| | OLTP (backend) | OLAP (data engineering) |
|---|---|---|
| **Optimized for** | Individual transactions (read/write one record) | Analytical queries (scan/aggregate millions of records) |
| **Schema** | Normalized (3NF) — minimize redundancy | Denormalized (star schema) — minimize joins |
| **Queries** | Point lookups, small transactions | Full table scans, aggregations, window functions |
| **Data model** | Entity-Relationship | Dimensional (fact + dimension tables) |
| **Examples** | PostgreSQL, MongoDB | Snowflake, BigQuery, Redshift |

---

## 1. Batch vs Streaming

| | Batch | Streaming |
|---|---|---|
| **How** | Process data in scheduled chunks (hourly, daily) | Process data as it arrives (continuous) |
| **Latency** | Minutes to hours | Seconds to minutes |
| **Complexity** | Lower — simpler to build, test, debug | Higher — state management, ordering, exactly-once |
| **Cost** | Usually cheaper (process once, on schedule) | Usually more expensive (always running) |
| **Tools** | Spark, dbt, Airflow, pandas | Kafka Streams, Flink, Spark Structured Streaming |

### When to use which

| Use case | Approach |
|---|---|
| Daily reports, dashboards refreshed hourly | Batch |
| Real-time fraud detection | Streaming |
| User activity analytics (updated every few hours is fine) | Batch |
| Live operational dashboards (current inventory, active orders) | Streaming |
| ML feature store (features need to be fresh for inference) | Depends on latency requirement |

### Hybrid (most common in practice)
```
Real-time events → Kafka → Streaming processor (hot path, low-latency)
                         → Batch landing (cold path, Parquet in lake)
                             → dbt transforms (hourly/daily)
                                 → Warehouse (Snowflake/BigQuery)
```

This is the **Lambda architecture** (batch + speed layers) or **Kappa architecture** (streaming only, replay from log). Most modern systems use a pragmatic hybrid.

### Anti-patterns
- Streaming for everything (over-engineering — 95% of analytics is fine with hourly batch)
- Batch only when business needs real-time (fraud, live pricing, operational alerts)
- No batch fallback for streaming (streaming fails → no data until fixed)
- Streaming without monitoring lag (10 minutes behind and nobody knows)

---

## 2. ELT vs ETL

| | ETL (Extract, Transform, Load) | ELT (Extract, Load, Transform) |
|---|---|---|
| **Transform where** | Before loading (in a staging area or ETL tool) | After loading (in the warehouse) |
| **Tools** | Informatica, Talend, custom scripts | dbt, Spark SQL, warehouse-native SQL |
| **Modern preference** | Legacy (when warehouses were expensive) | **Modern standard** (warehouses are powerful and cheap) |
| **Advantage** | Load only clean data | Raw data preserved, transform is replayable, warehouse handles scale |

### ELT is the modern standard because
- Warehouses (Snowflake, BigQuery) have massive compute — transform there, not in a separate system
- Raw data preserved in raw/landing layer — if transformation logic changes, replay from raw
- dbt makes SQL transformations testable, version-controlled, and documented
- Separation of concerns: ingestion tools (Fivetran, Airbyte) handle extract+load, dbt handles transform

### The modern data stack
```
Sources → Ingestion (Airbyte/Fivetran) → Raw Layer (warehouse) → dbt (transform) → Analytics Layer → BI (Looker/Metabase)
```

### Anti-patterns
- Transforming before loading (data lost if transformation is wrong — can't replay from raw)
- Complex Python transformations when SQL in dbt would suffice (SQL scales better in warehouse)
- No raw layer (transformed data is the only copy — audit trail lost)

---

## 3. Data Lake / Lakehouse Architecture

### Data Lake
Store everything raw in object storage (S3, GCS, Azure Blob) in open formats (Parquet, Avro).

- **Pro**: cheap storage, schema-on-read, any data format
- **Con**: no ACID transactions, no schema enforcement, query performance varies

### Data Warehouse
Structured storage optimized for analytical queries (Snowflake, BigQuery, Redshift).

- **Pro**: fast queries, ACID, schema enforcement, SQL interface
- **Con**: expensive at scale, structured data only, vendor lock-in

### Lakehouse (modern hybrid)
Combine lake storage with warehouse features using table formats.

```
Object Storage (S3/GCS) + Table Format (Iceberg/Delta Lake) = Lakehouse
  → ACID transactions on data lake
  → Schema enforcement + evolution
  → Time travel (query data as of yesterday)
  → Open format (no vendor lock-in)
```

| Table format | Created by | Key feature |
|---|---|---|
| **Delta Lake** | Databricks | ACID, time travel, Z-ordering, tight Spark integration |
| **Apache Iceberg** | Netflix | Vendor-neutral, hidden partitioning, schema evolution, growing adoption |
| **Apache Hudi** | Uber | Upsert/delete on data lake, incremental processing |

### Choosing

| Situation | Recommendation |
|---|---|
| Small/medium, SQL-first team | Warehouse (Snowflake/BigQuery) — simplest |
| Large scale, multi-engine (Spark + SQL + ML) | Lakehouse (Iceberg or Delta Lake on S3/GCS) |
| Already on Databricks | Delta Lake (native integration) |
| Want vendor neutrality | Iceberg (open, growing ecosystem) |

### Anti-patterns
- Data lake with no catalog (millions of files, nobody knows what's where — "data swamp")
- Data warehouse for everything (storing raw logs in Snowflake = expensive)
- No table format on data lake (no ACID, no schema enforcement, corrupt data possible)

---

## 4. Dimensional Modeling

How to organize data for analytical queries. The Kimball methodology — still the standard.

### Star Schema

```
                    ┌──────────────┐
                    │ dim_customers│
                    └──────┬───────┘
                           │
┌──────────────┐    ┌──────┴───────┐    ┌──────────────┐
│  dim_products│────│ fact_orders  │────│   dim_dates  │
└──────────────┘    └──────┬───────┘    └──────────────┘
                           │
                    ┌──────┴───────┐
                    │ dim_stores   │
                    └──────────────┘
```

### Concepts

| Concept | What it is | Example |
|---|---|---|
| **Fact table** | Events/transactions — what happened. Numeric measures. | `fact_orders` (order_id, customer_key, product_key, date_key, quantity, revenue) |
| **Dimension table** | Context/attributes — who, what, where, when. Descriptive. | `dim_customers` (customer_key, name, email, segment, country) |
| **Surrogate key** | Synthetic integer PK in dimension (not the business key) | `customer_key` (auto-increment) vs `customer_id` (business ID) |
| **Slowly Changing Dimension (SCD)** | How to handle dimension changes over time | Type 1 (overwrite), Type 2 (new row + history), Type 3 (add column) |
| **Grain** | The level of detail of the fact table | One row per order? Per order item? Per daily aggregate? |

### SCD Types

| Type | How it handles change | When |
|---|---|---|
| **Type 1** | Overwrite the old value | History doesn't matter (customer name correction) |
| **Type 2** | Add new row with effective dates, flag current row | History matters (customer changed address — queries by date need old address) |
| **Type 3** | Add column for previous value | Only need current + previous (not full history) |

### Principles
- **Define the grain first** — everything else follows from "what does one row in the fact table represent?"
- **Fact tables are narrow and deep** (few columns, many rows) — dimension tables are wide and shallow (many columns, fewer rows)
- **Surrogate keys in dimensions** — business keys change, surrogate keys don't
- **Conformed dimensions** — shared dimensions (dim_date, dim_customer) used by multiple fact tables for consistent reporting
- **Denormalize dimensions** — flatten hierarchies into the dimension table (don't normalize dimensions into sub-dimensions)

### Kimball vs Inmon

| | Kimball (bottom-up) | Inmon (top-down) |
|---|---|---|
| **Approach** | Build dimensional models (star schemas) per business process, integrate later | Build enterprise data model (3NF) first, derive dimensional models |
| **Speed** | Faster time to value (one star schema at a time) | Slower (design the whole before building) |
| **Modern relevance** | **Most common** — dbt projects are essentially Kimball | Enterprise-scale, heavily governed environments |
| **When** | Most teams | Large enterprises with centralized data governance |

### Anti-patterns
- No defined grain (fact table mixes different levels — some rows are daily, some hourly)
- Business keys as dimension PKs (business key changes → joins break)
- Normalized dimensions (star schema becomes snowflake schema — more joins, slower queries)
- One mega fact table for everything (different grains mixed — impossible to aggregate correctly)
- No SCD strategy (customer changes address → all historical orders "move" to new address)

---

## 5. Data Mesh

Decentralized data ownership — each domain team owns its data as a product.

### Core principles (Zhamak Dehghani)
1. **Domain ownership**: the team that produces the data owns its quality, schema, and SLAs (not a central data team)
2. **Data as a product**: treat data like a product — documented, tested, versioned, discoverable, with SLAs
3. **Self-serve data platform**: platform team provides tools (infrastructure, pipelines-as-a-service), domain teams use them
4. **Federated computational governance**: global standards (naming, quality, security) enforced across domains, but not centralized execution

### When data mesh makes sense
- Large organization (many teams producing data independently)
- Central data team is a bottleneck (every data request goes through them)
- Domain teams have engineering maturity to own their data

### When it doesn't
- Small team (one data team handles everything — mesh is overhead)
- Domain teams have no data engineering skills (they can't own what they can't build)
- Just starting with data (get the basics right first — warehouse, dbt, quality)

### Anti-patterns
- "Data mesh" as justification for no governance (decentralized ≠ ungoverned)
- Every team builds its own stack (no platform, no standards — chaos)
- Central team renamed to "platform" but still does everything (mesh in name only)
- No data contracts between domains (same integration problems, just distributed)

---

## 6. Data Layers / Medallion Architecture

### Bronze / Silver / Gold (Databricks naming) or Raw / Staging / Mart

| Layer | What it contains | Quality | Who accesses |
|---|---|---|---|
| **Raw/Bronze** | Exact copy from source, append-only, no transformations | As-is from source | Data engineers only |
| **Staging/Silver** | Cleaned, deduplicated, typed, validated. Business rules applied. | Tested, quality-checked | Data engineers, some analysts |
| **Mart/Gold** | Aggregated, business-ready. Star schema. Ready for BI/ML. | High — tested, documented, SLAs | Analysts, BI tools, ML pipelines |

### Principles
- **Raw is immutable** — never modify raw data. Transformations create new tables.
- **Each layer has clear quality expectations** — raw = "trust the source", gold = "trust completely"
- **Data flows forward** — raw → staging → mart. Never backward.
- **Each layer is independently queryable** — if an analyst needs raw data for investigation, they can access it (with proper access controls)

### Anti-patterns
- No raw layer (transformed data is the only copy — can't replay if logic was wrong)
- BI tools querying raw data (unclean, untyped, inconsistent)
- Mart layer is just a view on staging (no actual transformation or business logic)
- Too many layers (raw → staging → clean → enriched → aggregated → mart — 6 layers of confusion)

---

## References

- [Kimball Group — The Data Warehouse Toolkit (2013)](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/books/)
- [Zhamak Dehghani — Data Mesh (2022)](https://www.oreilly.com/library/view/data-mesh/9781492092384/)
- [Joe Reis & Matt Housley — Fundamentals of Data Engineering (2022)](https://www.oreilly.com/library/view/fundamentals-of-data/9781098108298/)
- [Databricks — Medallion Architecture](https://www.databricks.com/glossary/medallion-architecture)
- [Apache Iceberg Documentation](https://iceberg.apache.org/docs/latest/)
- [dbt Documentation](https://docs.getdbt.com/)
