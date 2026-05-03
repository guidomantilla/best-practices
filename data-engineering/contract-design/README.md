# Data Schema Contracts

How data producers and consumers agree on the shape, format, and evolution of data. For API contracts (REST, gRPC, GraphQL, messaging), see [`../../backend-engineering/contract-design/`](../../backend-engineering/contract-design/README.md).

Data contracts are different from API contracts: the "consumer" is often a pipeline or warehouse, not a person clicking a button. Changes propagate silently and break things downstream hours/days later.

---

## 1. What is a Schema Contract

An agreement between the producer (who writes data) and the consumer (who reads data):

- **Schema**: column names, types, nullability, ordering
- **Semantics**: what each field means (not just the name — `revenue` = gross or net?)
- **Quality guarantees**: freshness, completeness, uniqueness, valid ranges
- **Evolution rules**: how changes are communicated and handled
- **Ownership**: who is responsible for the contract

### Without contracts
```
Source team renames a column → your pipeline breaks 3 days later → you find out from a stakeholder
```

### With contracts
```
Source team's PR runs contract validation → fails → source team knows before merging
```

---

## 2. Schema Formats

| Format | Type system | Evolution support | Best for |
|---|---|---|---|
| **Avro** | Rich (primitives, records, arrays, maps, enums, unions) | Strong (schema resolution rules, reader/writer compatibility) | Event streaming (Kafka), Hadoop ecosystem |
| **Protobuf** | Strong (messages, fields, enums, oneof) | Strong (field numbers for backward compat) | gRPC, high-performance streaming |
| **JSON Schema** | Flexible (validates JSON structure) | Manual (no built-in compatibility checker) | REST APIs, config validation, lightweight contracts |
| **Parquet metadata** | Embedded schema in file | Per-file (no registry — schema in the data itself) | File-based data lakes |
| **dbt schema.yml** | YAML-based column docs + tests | Manual (version in git) | Warehouse tables/models |

### Choosing
- **Event streams (Kafka)** → Avro or Protobuf with Schema Registry
- **Warehouse tables** → dbt schema.yml + documentation + tests
- **File-based exchange** → Parquet (self-describing) + schema documentation
- **Cross-team data sharing** → JSON Schema or Protobuf (language-agnostic)

---

## 3. Schema Registry

Centralized store for schemas with compatibility enforcement.

### How it works
```
Producer registers schema v1 → Schema Registry stores it
Producer wants to register schema v2 → Registry checks compatibility → allows or rejects
Consumer reads data → uses registry to deserialize with correct schema
```

### Compatibility modes

| Mode | What it allows | Use when |
|---|---|---|
| **BACKWARD** | New schema can read old data (new consumer, old producer) | Most common — consumers upgrade first |
| **FORWARD** | Old schema can read new data (old consumer, new producer) | Producers upgrade first |
| **FULL** | Both backward AND forward compatible | Safest — both sides can upgrade independently |
| **NONE** | Any change allowed | Development only — never in production |

### Safe schema changes (backward compatible)
- Add optional field (with default)
- Add new enum value (if consumer handles unknown values)
- Widen a type (int → long)

### Breaking schema changes (require versioning)
- Remove a field
- Rename a field
- Change a field type (incompatible)
- Make an optional field required
- Change field semantics (same name, different meaning)

### Anti-patterns
- No schema registry (contract is "whatever the last deploy produces")
- Compatibility mode = NONE in production (any change goes through — breaks consumers silently)
- Schema version not in the message/file (consumer can't detect which version it's reading)
- One schema for all event types (mega-schema that grows forever)

### Tooling

| Tool | What it does |
|---|---|
| **Confluent Schema Registry** | Avro, Protobuf, JSON Schema. Compatibility enforcement. Kafka-native. |
| **AWS Glue Schema Registry** | Similar, AWS-native. Integrates with Kinesis, MSK. |
| **Apicurio Registry** | Open source, multi-format. |
| **buf** | Protobuf registry + linting + breaking change detection |

---

## 4. Data Contracts as Code

Contracts should be version-controlled, testable, and enforced in CI — not documentation that nobody reads.

### Patterns

**Producer-side enforcement:**
```yaml
# Producer's CI validates output schema
# dbt schema.yml (for warehouse tables)
models:
  - name: orders_daily
    config:
      contract:
        enforced: true
    columns:
      - name: order_date
        data_type: date
        constraints:
          - type: not_null
      - name: total_revenue
        data_type: numeric
        constraints:
          - type: not_null
          - type: check
            expression: "total_revenue >= 0"
```

**Consumer-side validation:**
```python
# Consumer validates schema before processing
from great_expectations import DataContext

context = DataContext()
results = context.run_checkpoint(checkpoint_name="validate_orders_input")
if not results.success:
    raise ValueError("Input data does not match expected contract")
```

**Event stream enforcement:**
```
Producer → Schema Registry (validates compatibility) → Kafka → Consumer (deserializes with registered schema)
```

### Principles
- **Contract lives in git** — versioned, reviewable, alongside the code
- **CI enforces the contract** — producer's PR fails if output schema changes incompatibly
- **Both sides test** — producer tests output matches contract, consumer tests input matches expected
- **Breaking changes require communication** — not just a schema change, but a conversation + migration plan
- **dbt contract enforcement** (`contract.enforced: true`) for warehouse models — dbt fails if model output doesn't match declared schema

---

## 5. Contract Lifecycle

### How contracts evolve

```
1. Producer and consumer agree on schema v1
2. Contract documented (schema.yml, .avsc, .proto, JSON Schema)
3. Both sides implement tests against the contract
4. Producer needs to change:
   a. Compatible change → update schema, registry validates, deploy
   b. Breaking change → new version (v2), migration period, deprecate v1
5. Consumer migrates to v2 during deprecation period
6. v1 removed after all consumers migrated
```

### Anti-patterns
- "We'll just Slack them when the schema changes" (no enforcement, forgotten, breaks silently)
- Breaking changes without migration period (consumers have zero time to adapt)
- No deprecation — old schema removed while consumers still use it
- Contracts defined once, never updated (schema has evolved, contract is fiction)

---

## References

- [Data Contracts — Andrew Jones](https://datacontract.com/)
- [Confluent Schema Registry Documentation](https://docs.confluent.io/platform/current/schema-registry/)
- [dbt Contracts Documentation](https://docs.getdbt.com/docs/collaborate/govern/model-contracts)
- [buf — Protobuf tooling](https://buf.build/)
- [`../../backend-engineering/contract-design/async-messaging.md`](../../backend-engineering/contract-design/async-messaging.md) — message design, delivery guarantees, schema evolution for events
