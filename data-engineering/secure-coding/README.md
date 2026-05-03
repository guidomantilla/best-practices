# Data Engineering Secure Coding

Security considerations specific to data pipelines. For the full security reference (12 areas, SDLC, tooling), see [`../../backend-engineering/secure-coding/`](../../backend-engineering/secure-coding/README.md). For zero trust, see [`../../zero-trust/`](../../zero-trust/README.md).

This file covers what's **different** for data engineering: security is about **data access, PII protection in transformations, and pipeline integrity** — not web vulnerabilities.

---

## 1. Data Access Controls

### Principles
- **Least privilege per pipeline**: each pipeline/job accesses only the tables/datasets it needs — not the entire warehouse
- **Separate credentials per environment**: dev pipeline can't read production data
- **Service accounts scoped per pipeline**: not one shared service account for all ETL jobs
- **Row-level / column-level security**: sensitive columns (PII) accessible only to pipelines that need them
- **No personal credentials in pipelines**: service accounts only — personal credentials aren't auditable and expire when the person leaves

### Anti-patterns
- One service account with admin access to the entire warehouse ("it's easier")
- Dev/staging pipelines reading from production database directly
- Analyst credentials hardcoded in a DAG file
- No column-level security — every pipeline sees every column including PII

---

## 2. PII in Pipelines

Data pipelines are the #1 place where PII spreads uncontrollably.

### The problem
```
Source DB (PII) → Ingestion → Raw layer (PII) → Transform → Analytics layer (PII still there)
  → BI dashboard (PII visible to 50 analysts)
  → ML training data (PII in model)
  → Exported CSV (PII on someone's laptop)
```

### Principles
- **Identify PII at ingestion**: tag/classify sensitive columns when data enters the pipeline, not after
- **Mask/anonymize as early as possible**: don't carry PII through the entire pipeline if downstream doesn't need it
- **PII should not reach analytics/BI layers in plaintext**: mask, hash, or aggregate before exposure
- **Audit who accesses PII**: log every query on PII columns (warehouse audit logs)
- **GDPR/CCPA deletion must propagate**: user requests deletion → must delete from raw, transformed, aggregated, AND downstream copies

### Masking patterns

| Pattern | How | When |
|---|---|---|
| **Hashing** | `SHA256(email)` — deterministic, irreversible | Join key that doesn't need to be readable |
| **Tokenization** | Replace with random token, mapping stored separately | Need to reverse for specific use cases |
| **Redaction** | Replace with `[REDACTED]` or `***` | Display/reporting where original value is never needed |
| **Generalization** | `age: 34` → `age_range: 30-40`, full address → city only | Analytics that needs patterns, not individuals |
| **Differential privacy** | Add statistical noise to aggregated results | ML training data, public datasets |

### Anti-patterns
- PII carried through every layer because "we might need it later"
- Masking only in the BI layer (raw and transformed layers still have plaintext PII)
- No PII inventory (don't know which columns in which tables have PII)
- GDPR deletion from source DB only (copies in warehouse, cache, exports remain)

---

## 3. Pipeline Integrity

Prevent unauthorized or corrupted data from entering your systems.

### Principles
- **Validate data at ingestion boundary**: schema validation, type checks, null checks before writing to raw layer
- **Immutable raw layer**: raw data is append-only, never modified — transformations create new tables, don't overwrite source
- **Checksums / row counts at each stage**: verify data wasn't lost or corrupted during transformation
- **Signed/verified source data**: when ingesting from external sources, verify authenticity (API signatures, checksum files)
- **Version control for transformations**: all SQL/Python/dbt transformations in git — auditable, reviewable, rollbackable

### Anti-patterns
- No validation at ingestion (corrupt data propagates to analytics, decisions made on bad data)
- Mutable raw layer (someone "fixes" raw data directly — audit trail lost)
- No row count reconciliation between stages (10% of data silently dropped in transformation)
- Transformations applied ad-hoc via SQL editor, not version-controlled

---

## 4. Secrets in Data Pipelines

### Principles
- Connection strings, API keys, database passwords in **secret manager** (Vault, AWS Secrets Manager, GCP Secret Manager)
- Airflow/Dagster connections store credentials in their secrets backend — never in DAG code or environment variables in plaintext
- dbt profiles.yml should reference environment variables or secret manager — never hardcoded passwords
- Credentials for external sources (APIs, SFTP, partner feeds) rotated on schedule

### Anti-patterns
- Database password in `dbt/profiles.yml` committed to git
- Airflow connection strings in DAG Python files
- Shared credentials for external data sources (one API key used by all pipelines — can't revoke per pipeline)
- `.env` file with production warehouse credentials on developer laptops

---

## Tooling

| Tool | What it does |
|---|---|
| **Column-level security** | Snowflake masking policies, BigQuery column-level ACLs, Databricks column masking |
| **Row-level security** | Snowflake row access policies, BigQuery row-level security |
| **Data masking** | Presidio (Microsoft, OSS — PII detection + anonymization), Faker (synthetic data) |
| **PII detection** | Presidio, Google DLP API, AWS Macie |
| **Audit logging** | Snowflake Access History, BigQuery Audit Logs, Databricks Unity Catalog |
| **Secrets** | Vault, AWS Secrets Manager + Airflow Secrets Backend |

---

## References

- [OWASP — Data Security](https://owasp.org/www-project-data-security/)
- [Presidio — Data Protection and PII Anonymization](https://microsoft.github.io/presidio/)
- [`../../backend-engineering/data-privacy/`](../../backend-engineering/data-privacy/README.md) — regulatory requirements (GDPR, HIPAA, CCPA)
- [`../../zero-trust/data.md`](../../zero-trust/data.md) — zero trust data pillar
