# Data Engineering Best Practices

Best practices for building data pipelines, transformations, and analytical systems. Backend is the foundation — most principles are shared. This guide references `backend-engineering/` for shared content and adds data-engineering-specific topics.

---

## Shared with Backend (reference directly)

These topics apply identically to data engineering. Read from `backend-engineering/`:

| Topic | Reference |
|---|---|
| **Data Privacy** | [`../backend-engineering/data-privacy/`](../backend-engineering/data-privacy/README.md) — PII handling, anonymization, GDPR/CCPA right to delete, data classification. Critical for data pipelines that process/store PII. |
| **Software Principles** | [`../backend-engineering/software-principles/`](../backend-engineering/software-principles/README.md) — SOLID, DRY, KISS, DI — applies to pipeline code, transformation modules, DAG design |
| **Configuration** | [`../backend-engineering/configuration/`](../backend-engineering/configuration/README.md) — connection strings, secrets, environments, feature flags. Same principles for pipeline config. |
| **CI/CD** | [`../backend-engineering/ci-cd/`](../backend-engineering/ci-cd/README.md) — pipeline design, artifacts, deployment. Backend §9 covers DAG deploy specifically. |
| **IaC** | [`../backend-engineering/iac/`](../backend-engineering/iac/README.md) — infrastructure for data platforms (K8s, networking, IAM, encryption) |
| **Data Design** | [`../backend-engineering/data-design/`](../backend-engineering/data-design/README.md) — relational, document, KV, caching, queries, connections, lifecycle. The operational data layer. |

---

## Data-Engineering-Specific Topics

| Folder | What it covers |
|---|---|
| [secure-coding/](secure-coding/README.md) | Data access controls, PII in pipelines, masking, anonymization at scale |
| [observability/](observability/README.md) | Pipeline monitoring, data freshness, data quality metrics, lineage, schema drift |
| [testing/](testing/README.md) | Data quality tests, schema validation, data contracts, pipeline testing |
| [contract-design/](contract-design/README.md) | Schema contracts between producers and consumers, registry, compatibility, breaking changes |
| [system-design/](system-design/README.md) | Batch vs streaming, ELT/ETL, lakehouse, data mesh, dimensional modeling (star schema, Kimball) |

---

## Partially Applicable (with notes)

### Secure Coding (base)
Backend [`secure-coding/`](../backend-engineering/secure-coding/README.md) covers web vulnerabilities (XSS, CSRF, injection) — most don't apply to data pipelines. What DOES apply: access controls (§5.3), data protection/encryption (§5.4), logging/audit (§5.9), supply chain (§5.6). Data-specific security is in [`secure-coding/`](secure-coding/README.md) above.

### Contract Design (base)
Backend [`contract-design/`](../backend-engineering/contract-design/README.md) covers REST, gRPC, GraphQL, WebSockets, async messaging — data engineering primarily uses async messaging patterns. Data-specific schema contracts are in [`contract-design/`](contract-design/README.md) above.

### System Design (base)
Backend [`system-design/`](../backend-engineering/system-design/README.md) covers microservices, Clean Architecture, integration patterns — some apply (CDC in integration-level.md). Data-specific architecture (OLAP, dimensional modeling, batch vs streaming) is in [`system-design/`](system-design/README.md) above.

---

## Ecosystem

### Languages
- **Python** — primary language for data engineering (pandas, PySpark, Airflow, dbt)
- **SQL** — transformation language (dbt, warehouse queries, analytical queries)
- **Scala** — Spark at scale (JVM performance, type safety)

### Tooling by Category

| Category | Tools |
|---|---|
| **Orchestration** | Airflow, Dagster, Prefect, Mage |
| **Transformation** | dbt, Spark, Flink, Pandas |
| **Storage / Warehouse** | Snowflake, BigQuery, Databricks, Redshift |
| **Table formats** | Delta Lake, Apache Iceberg, Apache Hudi |
| **File formats** | Parquet, Avro, ORC |
| **Streaming** | Kafka, Flink, Spark Streaming |
| **Data quality** | Great Expectations, dbt tests, Soda, Monte Carlo |
| **Schema management** | Confluent Schema Registry, AWS Glue Schema Registry |
| **Catalog / Lineage** | DataHub, OpenMetadata, OpenLineage, Amundsen |
| **CDC / Ingestion** | Debezium, Airbyte, Fivetran, Meltano |
| **BI (consumption)** | Tableau, Looker, Power BI, Metabase |

---

## References

- [Fundamentals of Data Engineering — Joe Reis & Matt Housley (2022)](https://www.oreilly.com/library/view/fundamentals-of-data/9781098108298/)
- [The Data Warehouse Toolkit — Ralph Kimball (2013)](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/books/)
- [dbt Documentation](https://docs.getdbt.com/)
- [Apache Spark Documentation](https://spark.apache.org/docs/latest/)
- [Great Expectations Documentation](https://docs.greatexpectations.io/)
