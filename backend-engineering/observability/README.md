# Observability Best Practices

Principles for instrumenting software to understand its behavior in production. Language-agnostic — applicable to any service, regardless of stack.

---

## 1. The Three Pillars

| Pillar | What it answers | When to use |
|---|---|---|
| **Logs** | What happened? (discrete events) | Debugging specific requests, audit trails, error context |
| **Metrics** | How is the system behaving? (aggregated numbers) | Dashboards, alerts, capacity planning, SLO tracking |
| **Traces** | Where did time go? (request flow across services) | Latency diagnosis, dependency mapping, bottleneck identification |

Each pillar answers different questions. They complement each other — don't rely on only one.

---

## 2. Structured Logging

Logs must be machine-parseable. Unstructured text logs are useless at scale.

### Required fields (every log line)
- `timestamp` — ISO 8601 / RFC 3339 with timezone
- `level` — severity (debug, info, warn, error, fatal)
- `service` — which service emitted the log
- `trace_id` — correlation ID to link logs to traces and across services
- `message` — human-readable description of the event

### Recommended fields (when applicable)
- `span_id` — link to specific span within a trace
- `user_id` — who triggered the action (if not PII-sensitive context)
- `request_id` — unique per inbound request
- `duration_ms` — how long the operation took
- `error` — error message or code (on error/warn logs)
- `component` — module/package/handler that emitted the log

### Anti-patterns
- Printf-style unstructured messages: `log.Printf("user %s did %s", id, action)`
- Logging without trace context (impossible to correlate across services)
- Inconsistent field names across services (`userId` vs `user_id` vs `UserID`)
- Multi-line logs (stack traces as separate lines — breaks log aggregation)
- Logging at wrong level (using `error` for expected business cases)

---

## 3. Log Levels

| Level | When to use | Example |
|---|---|---|
| **debug** | Development only. Detailed internal state. Never in production at full volume. | Variable values, branch decisions, cache hits/misses |
| **info** | Normal operations worth recording. The "happy path" breadcrumbs. | Request received, job completed, config loaded |
| **warn** | Something unexpected but recoverable. The system continued but conditions are degraded. | Retry succeeded, fallback used, approaching rate limit |
| **error** | Something failed and the operation could not complete. Requires investigation. | Request failed, dependency timeout, unhandled exception |
| **fatal** | The process cannot continue and will exit. | Cannot bind port, missing required config, corrupt state |

### Anti-patterns
- Using `error` for expected business outcomes (user not found, validation failed → `info` or `warn`)
- Using `info` for everything (makes it impossible to filter signal from noise)
- Never using `debug` (forces `info` spam that can't be turned off in production)
- Using `fatal` without actually exiting the process

---

## 4. What to Instrument

Instrument at **boundaries**, not internals.

### Always instrument
- **Inbound requests**: HTTP handlers, gRPC endpoints, queue consumers — entry points to your service
- **Outbound calls**: HTTP clients, DB queries, cache operations, queue publishes, external API calls
- **Background jobs**: start, completion, failure, duration
- **Business events**: user signup, payment processed, order placed — domain-significant events

### Don't instrument
- Internal function calls (creates noise, high overhead)
- Loop iterations
- Every if/else branch
- Getter/setter operations

### The rule
If it crosses a boundary (network, process, service, or significant domain event), instrument it. If it's internal computation, don't.

---

## 5. What NOT to Log

Overlap with secure-coding data-protection rules — from the instrumentation angle:

- **PII**: names, emails, phone numbers, addresses in plaintext
- **PHI**: health data, diagnoses, prescriptions
- **NPI**: account numbers, SSNs, financial data
- **Secrets**: API keys, tokens, passwords, connection strings
- **Request/response bodies** containing sensitive data (log metadata, not payloads)
- **Full SQL queries with parameters** (log the query template, not the values)

### What to do instead
- Log identifiers (user_id, request_id) that can be used to look up details in the source system
- Mask or hash sensitive fields if they must appear in logs
- Use structured logging so sensitive fields can be redacted by policy in the log pipeline

---

## 6. Metrics — RED and USE

Two frameworks for deciding what to measure.

### RED — for services (request-driven)

| Metric | What it measures |
|---|---|
| **Rate** | Requests per second |
| **Errors** | Failed requests per second (or error rate as percentage) |
| **Duration** | Latency distribution (p50, p90, p95, p99) |

Apply RED to every service endpoint. This is the minimum.

### USE — for resources (infrastructure)

| Metric | What it measures |
|---|---|
| **Utilization** | How busy is the resource? (CPU %, memory %, disk I/O %) |
| **Saturation** | How much queued/waiting work? (queue depth, thread pool exhaustion) |
| **Errors** | Resource-level errors (disk failures, network drops, OOM kills) |

Apply USE to every infrastructure component (CPU, memory, disk, network, connection pools, goroutine/thread pools).

### Anti-patterns
- Only measuring happy-path latency (ignoring error latency which is often different)
- Averages without percentiles (p50 hides tail latency problems)
- Measuring only infrastructure, not application behavior (or vice versa)
- No baseline — metrics without knowing what "normal" looks like are useless for alerting

**Source:** Tom Wilkie (RED), Brendan Gregg (USE)

### Security Metrics (Zero Trust)

Beyond RED/USE — metrics that feed zero trust decisions and detect threats:

| Metric | What it detects |
|---|---|
| **Auth failure rate** (per user, per IP) | Brute force, credential stuffing |
| **Authorization denial rate** | Privilege escalation attempts, misconfigured access |
| **Token refresh anomalies** | Same token from different IPs/devices (stolen token) |
| **MFA challenge failure rate** | Phishing, account takeover attempts |
| **Sensitive data access rate** | Unusual patterns (user querying 10K records when they normally query 5) |
| **Service-to-service auth failures** | Compromised service, misconfigured identity |
| **New device/IP per user** | Account compromise indicator |

These metrics feed into User and Entity Behavior Analytics (UEBA) — establishing baselines of "normal" behavior and alerting on deviations.

See `../../zero-trust/cross-cutting.md` §1 (Visibility & Analytics) for the full zero trust perspective.

---

## 7. Metric Types

| Type | What it is | When to use | Example |
|---|---|---|---|
| **Counter** | Monotonically increasing value. Only goes up (resets on restart). | Counting events: requests, errors, bytes processed | `http_requests_total` |
| **Gauge** | Value that goes up and down. Point-in-time snapshot. | Current state: temperature, queue depth, active connections | `goroutines_active` |
| **Histogram** | Distribution of values. Buckets + sum + count. | Latency, request sizes, response sizes | `http_request_duration_seconds` |

### Anti-patterns
- Using a gauge for something that should be a counter (losing events between scrapes)
- Using a counter for something that can decrease (connection count is a gauge, not a counter)
- Histogram with wrong buckets (default buckets rarely match your actual latency distribution)
- Too many buckets (increases cardinality and storage cost)

---

## 8. Distributed Tracing

Understand request flow across services.

### Core concepts
- **Trace**: the full journey of a request across all services
- **Span**: a single operation within a trace (an HTTP call, a DB query, a function)
- **Context propagation**: passing trace_id and span_id across service boundaries (HTTP headers, message metadata)

### What to capture per span
- Operation name (e.g., `GET /users/{id}`, `postgres.query`, `redis.get`)
- Start time and duration
- Status (ok, error)
- Attributes: relevant metadata (http.status_code, db.statement template, peer.service)
- Events: significant points within the span (retry, cache miss, fallback)

### Anti-patterns
- Not propagating context (traces break at service boundaries — you see fragments, not the full picture)
- Tracing internal functions (creates massive traces with no value)
- Missing error status on failed spans (trace looks "green" but the request failed)
- Not linking logs to traces (trace_id not in log output — can't jump from trace to logs)

### Context propagation standard
- HTTP: `traceparent` header (W3C Trace Context)
- gRPC: metadata
- Queues: message attributes/headers

---

## 9. Alerting

Alerts must be **actionable**. If no one needs to do anything, it's not an alert — it's a dashboard.

### SLOs, SLIs, SLAs

| Concept | What it is | Example |
|---|---|---|
| **SLI** (Service Level Indicator) | The metric you measure | p99 latency, error rate, availability |
| **SLO** (Service Level Objective) | The target for that metric | p99 < 200ms, error rate < 0.1%, availability > 99.9% |
| **SLA** (Service Level Agreement) | The contractual promise (with consequences) | 99.9% uptime or credits issued |

### Alert on SLO burn rate, not thresholds
- Don't alert on "latency > 500ms" — alert on "at this rate, we'll burn through our error budget in 2 hours"
- Burn rate alerting reduces noise and catches real degradation, not transient spikes

### Anti-patterns
- **Alert fatigue**: too many alerts, team ignores them all
- **Non-actionable alerts**: "disk at 70%" — so what? What do I do?
- **Missing runbook**: alert fires but no one knows what to do
- **Alerting on symptoms AND causes**: creates duplicate noise (alert on the symptom the user sees, investigate the cause)
- **No severity levels**: treating "database is down" the same as "one pod restarted"

### Every alert must have
- **What**: clear description of what's wrong
- **Impact**: who/what is affected
- **Runbook link**: what to do when it fires
- **Severity**: page (wake someone up) vs ticket (handle next business day)

---

## 10. Cardinality

The number of unique time series a metric produces. High cardinality = expensive and slow.

### Cardinality = label combinations
```
http_requests_total{method="GET", path="/users", status="200"}  → 1 series
http_requests_total{method="GET", path="/users/123", status="200"}  → 1 series per user ID = millions
```

### Rules
- **Never use unbounded values as labels**: user_id, email, request_id, IP address, full URL path
- **Use bounded categories**: method (GET/POST/PUT/DELETE), status_class (2xx/4xx/5xx), service_name
- **Parameterize paths**: `/users/{id}` not `/users/12345`
- **Move high-cardinality data to logs/traces** — metrics are for aggregates, not per-request detail

### Anti-patterns
- `user_id` as a metric label (millions of unique series)
- Full URL path as label (each unique URL = new series)
- Error message as label (unbounded unique strings)
- `request_id` as label (one series per request = insanity)

### Cost impact
- 1M unique series × 15-second scrape interval × 30 days retention = massive storage and query cost
- Most observability cost overruns come from cardinality explosions

---

## 11. Sampling

At scale, you can't trace every request. Sampling decides which requests to capture.

### Strategies

| Strategy | How it works | Trade-off |
|---|---|---|
| **Head-based** | Decide at the start of the request (random %) | Simple, but may miss interesting traces |
| **Tail-based** | Decide after the request completes (based on outcome) | Captures errors and slow requests, requires buffering |
| **Priority/rule-based** | Always trace certain paths (e.g., /payments always, /health never) | Targeted, but requires maintenance |

### Guidelines
- Start with 100% in dev/staging, sample in production
- Always trace errors and slow requests (tail-based or priority rules)
- Never sample health checks, readiness probes, or synthetic monitoring
- Typical production rates: 1-10% head-based + tail-based for anomalies

### Anti-patterns
- 100% sampling in production (cost explosion, no added insight beyond what 10% gives)
- Sampling without tail-based or priority rules (missing the interesting traces)
- Different sampling rates per service without coordination (broken traces)

---

## 12. Cost Management

Observability is not free. Vendors (Datadog, New Relic, Splunk, etc.) charge per GB ingested, per custom metric, per host, and per retained span. Costs grow silently until someone gets the bill.

### The three cost drivers

| Driver | What causes it | How to control |
|---|---|---|
| **Log volume** | Verbose logging, debug in production, logging request/response bodies, logging per-item in batch operations | Log levels, sampling, drop unneeded fields in pipeline |
| **Metric cardinality** | High-cardinality labels, too many custom metrics, wrong metric types | Label discipline, aggregation, recording rules |
| **Trace retention** | 100% sampling, long retention, large spans with full payloads | Sampling strategies, span limits, tiered retention |

### Common cost traps

- **Request/response body logging**: logging full payloads on every request. A 4KB body × 10K req/s = 3.4 TB/day of logs
- **Debug level in production**: left on after troubleshooting, never turned off
- **ORM/query logging**: every SQL query logged with full parameters by default (e.g., Hibernate, SQLAlchemy debug mode)
- **Auto-instrumentation without filtering**: OTel auto-instrumentation traces EVERYTHING including health checks, readiness probes, and internal calls
- **Logging inside loops**: `for item in batch: log.info("processing", item=item)` on a 10K-item batch = 10K log lines per request
- **Framework verbose defaults**: some frameworks log every middleware step, every route match, every header — turn them off in production
- **Unused metrics**: metrics defined years ago that nobody dashboards or alerts on — still being collected and stored
- **Large span attributes**: attaching full request bodies, SQL results, or stack traces to every span

### Estimating cost before deployment

```
Daily log cost = (avg log line size) × (log lines per request) × (requests per day) × (price per GB)
```

Example: 500 bytes/line × 5 lines/req × 1M req/day = 2.5 GB/day. At $0.10/GB (Loki) that's $7.5/month. At $1.70/GB (Datadog) that's $127/month. Same logs, 17x price difference.

### When the bill already exploded — triage process

1. **Identify top contributors**: most vendors show ingestion breakdown by source/service/tag. Find the top 3 emitters.
2. **Classify each log line**: is it actionable? Would someone look at this during an incident? If no → drop it.
3. **Reduce at the source first**: remove unnecessary log statements from code (cheaper than pipeline filters).
4. **Filter at the pipeline**: OTel Collector or vendor-side exclusion filters for what you can't remove from code immediately.
5. **Downsample, don't delete**: for logs you might need occasionally, reduce volume (sample 10%) rather than dropping 100%.
6. **Move to cheaper tiers**: most vendors offer archive/cold tiers. Route low-value logs there.
7. **Set log level per environment**: debug in dev, info in staging, warn+error in production (with dynamic level override for troubleshooting).

### Principles
- **Instrument for insight, not for completeness** — you don't need to observe everything
- **Set retention by value**: error traces retained 30 days, success traces 7 days, debug logs 3 days
- **Filter early**: drop noise in the pipeline (collector level), not at query time
- **Review regularly**: unused dashboards, metrics nobody queries, alerts nobody acts on — delete them
- **Budget observability like infrastructure**: set a monthly budget, track it, alert when approaching the limit
- **Every log line has a cost** — ask: "would I pay $X/month to keep this log?" If not, remove it

---

## 13. OpenTelemetry

The industry standard for instrumentation. Vendor-neutral, supports all three pillars.

### Why OpenTelemetry
- Single SDK for logs, metrics, and traces
- Vendor-agnostic: switch backends without re-instrumenting
- Auto-instrumentation available for most frameworks (HTTP, gRPC, DB clients)
- W3C Trace Context for context propagation

### Architecture
```
Application (SDK) → OTel Collector → Backend (Prometheus, Jaeger, Loki, Datadog, etc.)
```

The Collector is the control point: sampling, filtering, enrichment, routing — all without changing application code.

### Anti-patterns
- Vendor-specific SDKs locked into one backend (migrating = re-instrumenting everything)
- No collector (sending directly from app to backend — no control point for sampling/filtering)
- Ignoring auto-instrumentation (manually instrumenting what the SDK already covers)

---

## Tooling

| Category | Tool | What it does |
|---|---|---|
| **Instrumentation** | OpenTelemetry SDK | Vendor-neutral logs, metrics, traces instrumentation |
| **Collector** | OpenTelemetry Collector | Receives, processes, exports telemetry data |
| **Metrics** | Prometheus | Time-series database, pull-based metrics collection |
| **Metrics visualization** | Grafana | Dashboards for metrics, logs, and traces |
| **Traces** | Jaeger / Tempo | Distributed trace storage and visualization |
| **Logs** | Loki / ELK / Datadog | Log aggregation, search, alerting |
| **All-in-one** | Datadog / New Relic / Honeycomb | Full observability platform (SaaS) |
| **Synthetic monitoring** | Grafana k6 / Pingdom | Proactive uptime and latency checks |

---

## References

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Google SRE Book — Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Brendan Gregg — USE Method](https://www.brendangregg.com/usemethod.html)
- [Tom Wilkie — RED Method](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/)
- [Charity Majors — Observability Engineering](https://www.oreilly.com/library/view/observability-engineering/9781492076438/)
- [Google SRE Book — Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [W3C Trace Context Specification](https://www.w3.org/TR/trace-context/)

For the well-architected perspective on operational excellence, see [`../../well-architected/operational-excellence.md`](../../well-architected/operational-excellence.md). For performance monitoring, see [`../../well-architected/performance.md`](../../well-architected/performance.md). For reliability (SLOs/error budgets), see [`../../well-architected/reliability.md`](../../well-architected/reliability.md).
