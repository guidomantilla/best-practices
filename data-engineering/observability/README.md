# Data Engineering Observability

Pipeline monitoring, data quality metrics, freshness tracking, and lineage. For service-level observability (tracing, RED/USE, structured logging), see [`../../backend-engineering/observability/`](../../backend-engineering/observability/README.md).

Data engineering observability answers different questions: not "is the service healthy?" but **"did the data arrive? Is it correct? Is it fresh? Where did it come from?"**

---

## 1. Pipeline Monitoring

### What to monitor

| Metric | What it answers | Alert when |
|---|---|---|
| **Pipeline status** | Did the DAG/job succeed or fail? | Failure (immediate) |
| **Pipeline duration** | How long did it take? | Duration > 2x baseline (unexpected slowness) |
| **Pipeline lag** | How far behind is the pipeline from real-time? | Lag > SLA threshold |
| **Task retries** | How many tasks retried before succeeding? | Retries > N (flaky tasks) |
| **Resource usage** | CPU, memory, Spark executor usage | Over-provisioned (wasting cost) or under-provisioned (OOM) |
| **Schedule adherence** | Did the pipeline run when expected? | Missed scheduled run |

### Principles
- **Alert on failure immediately** — a failed pipeline means downstream consumers get stale data
- **Track duration trends** — a pipeline that was 10 min last week and is 45 min this week is degrading
- **SLAs per pipeline** — "analytics dashboard data is fresh within 1 hour" is a data SLA
- **Differentiate transient vs persistent failures** — a retry that succeeds is different from a retry that keeps failing

### Anti-patterns
- No pipeline monitoring (find out data is stale when a stakeholder complains)
- Only monitoring success/failure, not duration (pipeline takes 8 hours but "it succeeded")
- No SLA definition (nobody knows how fresh data should be)
- Alert fatigue from noisy pipeline alerts (daily flaky failures nobody investigates)

---

## 2. Data Freshness

How recent is the data? The #1 question stakeholders ask.

### Measuring freshness

| Method | How |
|---|---|
| **Timestamp-based** | Compare `max(updated_at)` in the table with current time |
| **Pipeline completion time** | When was the last successful pipeline run? |
| **Ingestion lag** | Time between event occurrence and availability in warehouse |

### SLA examples

| Dataset | Freshness SLA | Why |
|---|---|---|
| Real-time dashboard | < 5 minutes | Operational decisions |
| Daily analytics | < 2 hours after midnight | Morning reports |
| Monthly reports | < 24 hours after month-end | Business review |
| ML feature store | < 1 hour | Model freshness |

### Anti-patterns
- No freshness tracking (dashboard shows "last updated: 3 days ago" and nobody noticed)
- Same freshness SLA for everything (real-time dashboard and annual report don't need the same freshness)
- Freshness measured by pipeline run time, not by actual data timestamp (pipeline ran but processed zero rows)

---

## 3. Data Quality Metrics

Is the data correct, complete, and consistent?

### Quality dimensions

| Dimension | What it checks | Example test |
|---|---|---|
| **Completeness** | No unexpected NULLs, no missing rows | `NOT NULL` on required columns, row count within expected range |
| **Uniqueness** | No duplicates where there shouldn't be | Primary key uniqueness, no duplicate events |
| **Validity** | Values within expected ranges/formats | Email format valid, age between 0-150, status in allowed values |
| **Consistency** | Related data agrees across tables/systems | Orders total = sum of line items, FK references exist |
| **Accuracy** | Data reflects reality | Harder to test — compare against source systems, spot checks |
| **Timeliness** | Data arrived when expected | See §2 (freshness) |

### Where to test

```
Source → Ingestion → [QUALITY CHECK] → Raw Layer → Transform → [QUALITY CHECK] → Analytics Layer → [QUALITY CHECK] → BI/ML
```

Test at every boundary:
- **After ingestion**: did we get the expected volume? Schema correct?
- **After transformation**: business rules applied correctly? No data loss?
- **Before consumption**: final dataset passes all quality gates?

### Anti-patterns
- Quality checks only in production (bugs found by analysts, not by tests)
- No expected row count ranges ("we got 0 rows and nobody noticed for 3 days")
- Tests that always pass (thresholds too loose — "between 0 and 1 billion rows" is always true)
- No quality checks on third-party/external data (trusting vendor data blindly)

### Tooling

| Tool | What it does |
|---|---|
| **Great Expectations** | Data quality framework — expectations as code, profiling, docs |
| **dbt tests** | Built-in (unique, not_null, accepted_values, relationships) + custom SQL tests |
| **Soda** | Data quality checks via YAML config, integrates with orchestrators |
| **Monte Carlo** | Data observability platform (anomaly detection, lineage, SaaS) |
| **Elementary** | dbt-native data observability (open source) |

---

## 4. Data Lineage

Where did this data come from? How was it transformed? Where does it go?

### Why lineage matters
- **Impact analysis**: "if I change this column, what downstream breaks?"
- **Root cause analysis**: "this dashboard is wrong — where in the pipeline did it go wrong?"
- **Compliance**: "show me everywhere PII flows" (GDPR data inventory requirement)
- **Trust**: "can I trust this number?" — trace it back to the source

### Levels of lineage

| Level | What it tracks | Example |
|---|---|---|
| **Table-level** | Table A → Table B → Table C | "orders_raw feeds into orders_clean feeds into daily_revenue" |
| **Column-level** | Column A.x → transformation → Column B.y | "orders.total_amount → SUM() → daily_revenue.total" |
| **Row-level** | Specific records and their transformations | Rare, expensive — only for compliance-critical data |

### Principles
- **Automate lineage extraction** — don't maintain manually (dbt generates it, query log parsing extracts it)
- **Column-level lineage** for PII tracking — must know which columns carry PII through the entire pipeline
- **Lineage must be queryable** — not just a diagram, but "show me all tables that depend on `users.email`"

### Tooling

| Tool | Type | What it does |
|---|---|---|
| **dbt docs** | Built-in | DAG visualization, auto-generated from models |
| **OpenLineage** | Open standard | Lineage events emitted by Airflow, Spark, dbt |
| **DataHub** | Platform (OSS) | Metadata, lineage, discovery, governance |
| **OpenMetadata** | Platform (OSS) | Similar to DataHub — metadata + lineage + quality |
| **Amundsen** | Platform (OSS, Lyft) | Data discovery + lineage |
| **Monte Carlo** | SaaS | Automated lineage + anomaly detection |

### Anti-patterns
- No lineage (change a source table → 5 dashboards break → nobody knows why)
- Manual lineage documentation (outdated the day after it's written)
- Table-level only (know tables are connected but not which columns — can't track PII)

---

## 5. Schema Drift Detection

Schemas change — sources add/remove columns, types change, formats change. Detect it before it breaks your pipeline.

### What to detect

| Change | Impact | How to detect |
|---|---|---|
| **New column added** | Usually safe — but might need to be included in transformations | Compare schema snapshot |
| **Column removed** | Pipeline breaks if it references the column | Compare schema snapshot |
| **Type changed** | Silent data corruption (string → int truncation) | Compare schema snapshot |
| **Null behavior changed** | Column that was never NULL now has NULLs | Quality test (not_null) |
| **Value distribution changed** | Enum gets new values, ranges shift | Statistical profiling, accepted_values test |

### Principles
- **Snapshot schemas at ingestion** — compare current vs previous, alert on diff
- **Fail-safe on breaking changes** — column removed or type changed → pipeline stops, doesn't silently produce bad data
- **Allow additive changes** — new columns are OK (log them, don't block)
- **Schema contracts between teams** — see [`../contract-design/`](../contract-design/README.md)

### Anti-patterns
- No schema change detection (source team adds a column, your pipeline ignores it or breaks)
- Accepting all changes silently (type change from string to int → silent truncation)
- No communication between source teams and data teams (schema changes are surprises)

---

## References

- [Fundamentals of Data Engineering — Joe Reis & Matt Housley (2022)](https://www.oreilly.com/library/view/fundamentals-of-data/9781098108298/)
- [Great Expectations Documentation](https://docs.greatexpectations.io/)
- [OpenLineage Specification](https://openlineage.io/)
- [Monte Carlo — Data Observability](https://www.montecarlodata.com/)
- [`../../backend-engineering/observability/`](../../backend-engineering/observability/README.md) — service-level observability
