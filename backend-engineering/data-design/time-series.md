# Time-Series Database Design

Best practices for time-series databases (TimescaleDB, InfluxDB, Prometheus, VictoriaMetrics, QuestDB).

---

## 1. When to Use a Time-Series DB

### Good fit
- Metrics (CPU, memory, request latency, business KPIs)
- IoT sensor data (temperature, pressure, location over time)
- Financial data (stock prices, exchange rates, transactions per minute)
- Event logs with time-based aggregation (requests per minute, errors per hour)
- Monitoring and alerting systems

### Not a good fit
- General-purpose CRUD (use relational)
- Data without a time dimension (use relational/document)
- Complex relationships/joins (use relational)
- Full-text search (use search engine)
- Data that's frequently updated in place (TSDB is append-optimized, not update-optimized)

---

## 2. Data Model

### Core concepts

| Concept | What it is | Example |
|---|---|---|
| **Metric/Measurement** | What you're measuring | `http_request_duration`, `cpu_usage`, `temperature` |
| **Timestamp** | When the measurement was taken | `2026-05-01T10:30:00Z` |
| **Value/Field** | The measurement value (numeric) | `0.234` (seconds), `78.5` (degrees) |
| **Tags/Labels** | Metadata for filtering and grouping (indexed) | `service=api`, `region=us-east`, `method=GET` |

### Tags vs Fields

| | Tags (labels) | Fields (values) |
|---|---|---|
| **Purpose** | Identify and filter time series | Store the actual measurements |
| **Indexed** | Yes (fast filtering, grouping) | No (stored, aggregated) |
| **Cardinality** | Keep low (bounded set of values) | Can be high (any numeric value) |
| **Examples** | `host`, `service`, `region`, `status_code` | `latency_ms`, `cpu_percent`, `request_count` |

### Anti-patterns
- Using high-cardinality values as tags (`user_id`, `request_id`, `IP address`) — index explosion
- Storing non-numeric data as fields (TSDB optimized for numbers)
- No tags (can't filter or group — everything is one big series)
- Too many tags (each unique combination = a new time series — cardinality explosion)

---

## 3. Write Patterns

### Principles
- **Append-only**: time-series data is written once, never updated (immutable events)
- **Batch writes**: write multiple points at once (reduces network overhead, better compression)
- **Timestamps are important**: use precise, consistent timestamps (NTP sync across sources)
- **Write in time order**: out-of-order writes are expensive in most TSDBs (buffered, sorted later)

### Anti-patterns
- Writing one point at a time (network overhead per point — batch instead)
- Frequent updates to historical data (TSDBs aren't optimized for random writes)
- Timestamps with inconsistent precision (mixing seconds and milliseconds)
- Backfilling large time ranges without throttling (overwhelms compaction)

---

## 4. Retention & Downsampling

### Retention policies
- Raw data: keep for days/weeks (high resolution, expensive storage)
- Downsampled: keep for months/years (lower resolution, cheap storage)
- Define per metric based on business need (not one policy for all)

### Downsampling
```
Raw (every 10s) → 1-minute averages → 1-hour averages → 1-day averages
Keep 7 days       Keep 30 days        Keep 1 year       Keep 5 years
```

### Aggregation functions for downsampling
- `avg` — most common (smooths spikes)
- `max` — preserve peak values (useful for capacity planning)
- `min` — preserve minimums (useful for SLO tracking)
- `sum` — for counters (total requests per hour)
- `count` — event frequency

### Anti-patterns
- Keep everything at full resolution forever (storage cost grows linearly, queries slow down)
- No downsampling (querying 1-year range at 10-second resolution = millions of points)
- Downsampling without preserving max/min (lose visibility into spikes)
- Deleting raw data without downsampled backup (lose historical visibility entirely)

---

## 5. Query Patterns

### Common operations
- **Range queries**: get data between two timestamps (`WHERE time > now() - 1h`)
- **Aggregations**: average, sum, count, percentiles over time windows
- **Group by**: split by tag (`GROUP BY service, region`)
- **Rate**: calculate per-second rate from a counter (`rate(http_requests_total[5m])`)
- **Moving averages**: smooth data over a window

### Principles
- Always specify a time range (unbounded queries are expensive)
- Use appropriate time buckets for the display resolution (1-minute buckets for 1-hour view, 1-hour for 1-week)
- Pre-aggregate at write time for known dashboards (recording rules in Prometheus)
- Use tags for filtering, not regex on metric names

### Anti-patterns
- Querying without time bounds (scans entire history)
- Too-fine granularity for long time ranges (1-second buckets over 1 year = impossible to render)
- Regex on metric/tag values in hot paths (expensive)
- Client-side aggregation of raw points (let the TSDB aggregate server-side)

---

## 6. Cardinality Management

The #1 operational issue in time-series databases. Same concept as in `../observability/README.md` §10 — from the data store angle.

### Cardinality = unique combinations of metric name + tag values

```
http_requests{method="GET", service="api", status="200"}  → 1 series
http_requests{method="GET", service="api", status="201"}  → another series
× all possible combinations = total cardinality
```

### Rules
- Keep tag values **bounded** (method: 5 values, status_class: 3 values — not user_id: millions)
- Monitor total active series count (alert when approaching limits)
- Each unique series has memory and storage cost

### Anti-patterns
- `user_id` as a tag → millions of series per metric
- Full URL path as tag → unbounded (use parameterized: `/users/{id}` not `/users/12345`)
- Error message as tag → every unique error = new series
- Ephemeral container IDs as tags (series created per container restart, never cleaned up)

---

## Tooling

| Tool | Type | Best for |
|---|---|---|
| **Prometheus** | Pull-based, in-memory + disk | Kubernetes monitoring, alerting |
| **VictoriaMetrics** | Prometheus-compatible, better storage | Long-term storage, high cardinality tolerance |
| **TimescaleDB** | PostgreSQL extension | SQL queries on time-series, familiar tooling |
| **InfluxDB** | Purpose-built TSDB | IoT, custom metrics, Flux query language |
| **QuestDB** | High-performance, SQL-compatible | High ingestion rate, financial data |
| **Grafana** | Visualization | Dashboards for any TSDB backend |
