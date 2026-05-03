# Data Engineering Testing

Testing for data pipelines. For general testing practices (test pyramid, unit, integration, E2E, flaky tests), see [`../../backend-engineering/testing/`](../../backend-engineering/testing/README.md).

Data testing answers different questions: not "does the code work?" but **"is the data correct, complete, and consistent?"**

---

## 1. The Data Testing Pyramid

```
         /  Pipeline E2E  \          Few — full pipeline run, slow, expensive
        /------------------\
       / Data Quality Tests \        Many — validate data at each stage
      /----------------------\
     /   Unit Tests (logic)   \      Many — pure transformation functions
    /--------------------------\
```

| Level | What it tests | Speed | When |
|---|---|---|---|
| **Unit** | Pure transformation functions (Python/SQL logic in isolation) | ms | Every PR |
| **Data Quality** | Data correctness, completeness, uniqueness, validity at each pipeline stage | seconds-minutes | Every pipeline run |
| **Pipeline E2E** | Full pipeline: source → ingestion → transform → output. Correct result? | minutes-hours | Per release, scheduled |

---

## 2. Unit Tests (Transformation Logic)

Test the logic, not the data.

### What to unit test
- Python transformation functions (pure functions that take data in, return data out)
- SQL logic via dbt unit tests (v1.8+) or sqlmesh
- Custom validators, parsers, cleaners
- Edge cases: NULLs, empty strings, boundary dates, unicode, timezone handling

### How
```python
# Python — test transformation function
def test_calculate_revenue():
    orders = [{"qty": 2, "price": 10.0}, {"qty": 1, "price": 5.0}]
    assert calculate_revenue(orders) == 25.0

def test_calculate_revenue_empty():
    assert calculate_revenue([]) == 0.0

def test_calculate_revenue_null_price():
    orders = [{"qty": 2, "price": None}]
    assert calculate_revenue(orders) == 0.0  # or raises, depending on business rule
```

```sql
-- dbt unit test (v1.8+)
unit_tests:
  - name: test_revenue_calculation
    model: orders_enriched
    given:
      - input: ref('stg_orders')
        rows:
          - { order_id: 1, qty: 2, price: 10.0 }
    expect:
      rows:
        - { order_id: 1, revenue: 20.0 }
```

### Anti-patterns
- No unit tests on transformation logic ("it's just SQL")
- Testing with production data in unit tests (slow, brittle, PII risk)
- Only testing happy path (NULLs, empty datasets, and edge cases are where bugs live)

---

## 3. Data Quality Tests

Validate the DATA, not the code. Run after each pipeline stage.

### Test types

| Type | What it validates | Tools |
|---|---|---|
| **Schema tests** | Columns exist, correct types, not null where required | dbt tests (not_null, unique), Great Expectations (expect_column_to_exist) |
| **Uniqueness tests** | No duplicate primary keys, no duplicate events | dbt (unique), GE (expect_column_values_to_be_unique) |
| **Referential integrity** | Foreign keys reference existing records | dbt (relationships), custom SQL |
| **Range/validity tests** | Values within expected bounds | dbt (accepted_values), GE (expect_column_values_to_be_between) |
| **Volume tests** | Row count within expected range | GE (expect_table_row_count_to_be_between), custom |
| **Freshness tests** | Data is recent enough | dbt (source freshness), custom timestamp checks |
| **Distribution tests** | Statistical distribution hasn't shifted dramatically | GE (expect_column_mean_to_be_between), Monte Carlo anomaly detection |
| **Custom business rules** | Domain-specific invariants | dbt custom SQL tests, GE custom expectations |

### dbt tests example
```yaml
# schema.yml
models:
  - name: orders_clean
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: status
        tests:
          - accepted_values:
              values: ['pending', 'paid', 'shipped', 'cancelled']
      - name: total_amount
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 0"

sources:
  - name: raw
    tables:
      - name: orders
        loaded_at_field: _loaded_at
        freshness:
          warn_after: { count: 12, period: hour }
          error_after: { count: 24, period: hour }
```

### Principles
- **Test at every boundary** (after ingestion, after each transformation, before serving)
- **Tests are part of the pipeline** — not a separate process. Data quality failure = pipeline failure.
- **Start with the basics**: not_null, unique, accepted_values, row count range. Add more as you find issues.
- **Alert, don't just log**: a data quality failure should page someone, not rot in a log file.

### Anti-patterns
- Data quality tests only in production (bad data found by analysts, not by tests)
- Tests that always pass (thresholds too loose)
- Tests run separately from the pipeline (quality failure doesn't stop the pipeline)
- No freshness tests (data is 3 days stale, nobody knows)

---

## 4. Data Contracts

Agreement between data producer and consumer about the shape, semantics, and quality of data. See also [`../contract-design/`](../contract-design/README.md) for schema-level contracts.

### What a data contract specifies
- **Schema**: columns, types, nullability
- **Semantics**: what each column means (not just the name — "revenue" means gross or net?)
- **Quality SLAs**: freshness (< 1 hour), completeness (< 0.1% NULLs on required fields), uniqueness
- **Volume expectations**: expected row count range per day/hour
- **Breaking change policy**: how changes are communicated and handled

### How to enforce
- **dbt tests** as contract validation (both producer and consumer define expectations)
- **Schema registry** for event streams (Avro/Protobuf schemas with compatibility enforcement)
- **Contract tests in CI** — producer's PR fails if it breaks the contract

### Anti-patterns
- No data contracts (upstream changes break downstream silently)
- Contract is a wiki page (not enforced, not versioned, not tested)
- Only schema contracts (shape is correct but semantics changed — "revenue" now includes tax)
- One-way contract (producer defines, consumer has no say)

---

## 5. Pipeline Integration Tests

Test the full pipeline or a significant portion of it with realistic data.

### Patterns

| Pattern | How | When |
|---|---|---|
| **Fixture-based** | Small, curated test dataset → run pipeline → assert output | Every PR (if fast enough) |
| **Snapshot-based** | Run pipeline, compare output to approved snapshot | Detect unexpected changes in output |
| **Shadow pipeline** | Run new pipeline in parallel with old, compare results | Major refactors, migration validation |
| **Staging environment** | Full pipeline run against staging warehouse with production-like data | Pre-release validation |

### Principles
- **Use small, representative test data** — don't test with production-scale data in CI (too slow, PII risk)
- **Test the pipeline, not the framework** — you don't need to test that Spark works. Test YOUR transformations.
- **Anonymize test data** — if derived from production, strip PII first
- **Idempotent pipelines** — running the pipeline twice produces the same result (crucial for testing and for retry)

### Anti-patterns
- No integration tests (only unit tests on individual functions — pipeline assembly is untested)
- Using full production data for tests (slow, PII risk, non-reproducible)
- Pipeline tests that depend on external state (external API available, specific data in source)
- Non-idempotent pipelines (re-run creates duplicates — can't test reliably)

---

## Tooling

| Category | Tool | What it does |
|---|---|---|
| **Quality framework** | Great Expectations | Expectations as code, profiling, data docs |
| **dbt testing** | dbt tests | Built-in + custom SQL tests, source freshness |
| **Quality monitoring** | Soda | YAML-based quality checks, integrates with orchestrators |
| **Quality monitoring** | Monte Carlo | Anomaly detection, lineage, freshness (SaaS) |
| **Quality monitoring** | Elementary | dbt-native observability (OSS) |
| **Unit testing** | pytest | Python transformation logic |
| **Unit testing** | dbt unit tests | SQL transformation logic (v1.8+) |
| **Contract testing** | Schema Registry | Avro/Protobuf compatibility enforcement |

---

## References

- [Great Expectations Documentation](https://docs.greatexpectations.io/)
- [dbt Tests Documentation](https://docs.getdbt.com/docs/build/data-tests)
- [Soda Documentation](https://docs.soda.io/)
- [`../../backend-engineering/testing/`](../../backend-engineering/testing/README.md) — general testing practices
