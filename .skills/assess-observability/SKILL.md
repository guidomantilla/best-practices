---
name: assess-observability
description: Review code for observability gaps — missing instrumentation, poor logging practices, metric anti-patterns, and tracing issues. Use when the user asks to review instrumentation, check logging practices, assess observability coverage, or validate metric/tracing patterns. Triggers on requests like "review observability", "check my logging", "is this well instrumented", "review tracing", or "/assess-observability".
---

# Observability Review

Review code for observability gaps and instrumentation anti-patterns. Produce actionable findings — not generic "add more logging" advice.

## Domain Detection

| Signal | Domain | Context files to read |
|---|---|---|
| Go, Rust, Java, Python with HTTP/gRPC, OTel, Prometheus client | **Backend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/observability/README.md` |
| React, Vue, Angular, Svelte, browser APIs, Sentry, RUM | **Frontend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/frontend-engineering/observability/README.md` |
| dbt, Airflow, Dagster, Spark, pipeline DAGs, data quality | **Data** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/data-engineering/observability/README.md` |
| LLM SDK imports, Langfuse, LangSmith, token tracking, prompt templates | **AI** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/ai-engineering/observability/README.md` (LLM metrics, cost, quality, drift) |

Backend observability (13 areas) is always relevant as base. Frontend and data add domain-specific concerns.

## Review Process

1. **Detect domain and framework**: backend (service observability), frontend (client-side RUM/error tracking), or data (pipeline monitoring/quality).
2. **Identify boundaries**: backend → service entry points. Frontend → user interactions, API calls. Data → pipeline stages, transformation boundaries.
3. **Assess current instrumentation**: what's already instrumented, how, and with what library.
4. **Scan against applicable areas**: backend (13 areas: logging, metrics, tracing, alerting, cost). Frontend (error tracking, RUM, Core Web Vitals, security metrics). Data (pipeline status, freshness, quality metrics, lineage, schema drift).
5. **Report findings**: list each issue with impact, location, and fix.
6. **Recommend tooling**: based on detected domain and stack, suggest applicable tools.
7. **Offer capabilities**: based on findings, offer additional deliverables.

## Review Areas

1. **Structured logging** — JSON format, required fields (timestamp, level, service, trace_id, message)
2. **Log levels** — correct severity usage, no error-level for expected business outcomes
3. **Boundary instrumentation** — inbound requests, outbound calls, background jobs, business events
4. **Sensitive data in logs** — PII, PHI, NPI, secrets, tokens in log output
5. **Metrics coverage** — RED (Rate, Errors, Duration) on service endpoints
6. **Metric types** — correct use of counter/gauge/histogram
7. **Cardinality** — unbounded label values (user_id, full path, request_id as labels)
8. **Distributed tracing** — context propagation, span creation at boundaries, error status on failed spans
9. **Log-trace correlation** — trace_id present in logs, linkable to traces
10. **Alerting readiness** — SLIs defined, meaningful error classification for alert rules
11. **Sampling** — trace sampling strategy appropriate for production scale
12. **Cost awareness** — verbose logging, high-cardinality metrics, over-instrumentation
13. **OpenTelemetry alignment** — vendor-neutral instrumentation, collector usage, auto-instrumentation

These 13 areas are the minimum review scope. Flag additional observability issues beyond these based on the detected architecture, scale, or operational context.

## Impact Assessment

| Impact | Criteria |
|---|---|
| **High** | Blind spot in production: an outage or degradation would be undetectable or un-debuggable |
| **Medium** | Observability exists but is degraded: missing context, wrong level, partial coverage |
| **Low** | Suboptimal but functional: inefficient instrumentation, minor cost waste, style issues |

## Tooling by Language

### Go
| Category | Tool | What it detects/provides | Install |
|---|---|---|---|
| Instrumentation | `otel-go` | OpenTelemetry SDK for Go | `go get go.opentelemetry.io/otel` |
| Metrics | `prometheus/client_golang` | Prometheus metrics client | `go get github.com/prometheus/client_golang` |
| Logging | `slog` (stdlib) | Structured logging (Go 1.21+) | stdlib |
| Logging | `zap` | High-performance structured logging | `go get go.uber.org/zap` |
| Linter | `sloglint` | Validates slog usage patterns | via golangci-lint |

### Rust
| Category | Tool | What it detects/provides | Install |
|---|---|---|---|
| Instrumentation | `opentelemetry-rust` | OpenTelemetry SDK for Rust | `cargo add opentelemetry` |
| Logging | `tracing` | Structured diagnostics with spans | `cargo add tracing` |
| Metrics | `metrics` | Prometheus-compatible metrics | `cargo add metrics` |

### Java
| Category | Tool | What it detects/provides | Install |
|---|---|---|---|
| Instrumentation | `opentelemetry-java` | OpenTelemetry SDK + auto-instrumentation agent | Maven/Gradle dependency |
| Logging | `SLF4J` + `Logback` / `Log4j2` | Structured logging with MDC for trace context | Maven/Gradle dependency |
| Metrics | `micrometer` | Vendor-neutral metrics facade | Maven/Gradle dependency |

### Python
| Category | Tool | What it detects/provides | Install |
|---|---|---|---|
| Instrumentation | `opentelemetry-python` | OpenTelemetry SDK + auto-instrumentation | `pip install opentelemetry-sdk` |
| Logging | `structlog` | Structured logging | `pip install structlog` |
| Logging | `python-json-logger` | JSON formatter for stdlib logging | `pip install python-json-logger` |
| Metrics | `prometheus_client` | Prometheus metrics client | `pip install prometheus_client` |

### TypeScript / JavaScript
| Category | Tool | What it detects/provides | Install |
|---|---|---|---|
| Instrumentation | `@opentelemetry/sdk-node` | OpenTelemetry SDK + auto-instrumentation | `npm install @opentelemetry/sdk-node` |
| Logging | `pino` | Fast structured logging | `npm install pino` |
| Logging | `winston` | Flexible structured logging | `npm install winston` |
| Metrics | `prom-client` | Prometheus metrics client | `npm install prom-client` |

### Infrastructure
| Category | Tool | What it does | Install |
|---|---|---|---|
| Collector | `otel-collector` | Receives, processes, exports telemetry | Docker / binary |
| Metrics | `prometheus` | Time-series DB, scraping, alerting rules | Docker / Helm |
| Dashboards | `grafana` | Visualization for metrics, logs, traces | Docker / Helm |
| Traces | `jaeger` / `tempo` | Trace storage and visualization | Docker / Helm |
| Logs | `loki` | Log aggregation (label-indexed) | Docker / Helm |

## Output Format

### Findings

For each finding:

```
### [IMPACT] — Short description
- **File**: path/to/file.go:42
- **Area**: which of the 13 observability areas
- **Issue**: what's wrong or missing
- **Fix**: specific action to take (with code sketch if applicable)
- **Tool**: which tool from the toolbox helps here
```

### Summary

```
## Summary
- High: N
- Medium: N
- Low: N
- Language(s): [detected]
- Instrumentation library: [detected or missing]
- Pillars covered: [Logs | Metrics | Traces — which are present]
- Pillars missing: [which are absent]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable:

```
## What I Can Generate

Based on this review, I can also:
- [ ] Generate an instrumentation scaffold (OTel setup + middleware) for this service
- [ ] Create a structured logging standard (field names, levels, format) for this project
- [ ] Define RED metrics for each detected endpoint
- [ ] Propose SLIs/SLOs based on the service's endpoints and dependencies
- [ ] Generate a Grafana dashboard JSON for the detected metrics
- [ ] Create alerting rules (Prometheus/Alertmanager) for the defined SLOs
- [ ] Design a sampling strategy for production tracing
- [ ] Estimate observability cost and suggest optimizations

Select which ones you'd like me to generate.
```

Only list capabilities that are relevant to the findings and context.

## What NOT to Do

- Don't recommend "add logging everywhere" — instrument boundaries, not internals
- Don't flag missing instrumentation on internal helper functions
- Don't suggest tools for languages not present in the project
- Don't recommend switching logging libraries unless the current one is fundamentally broken
- Don't prescribe specific backends (Datadog vs Grafana stack) — that's an infrastructure decision, not a code review
- Don't flag code you haven't read
- Don't assume scale — a hobby project doesn't need sampling strategies
- Don't recommend OpenTelemetry migration if the current instrumentation is working and well-structured

## Invocation examples

These cover the most useful patterns for this skill. The full list (7 patterns + bonus on context formats) is in the [Invocation patterns section of the README](../../README.md#invocation-patterns).

- **Blind** — `/assess-observability`
- **Narrative** — `/assess-observability servicio en producción con SLOs, foco logs y tracing distribuido`
- **Deterministic** — `/assess-observability generame un script que valide que los handlers tengan tracing`
