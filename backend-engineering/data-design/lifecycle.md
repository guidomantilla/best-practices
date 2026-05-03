# Data Lifecycle Management

Best practices for retention, archival, deletion, and classification of data.

---

## 1. Data Classification

Know what data you have before deciding how to manage it.

| Classification | Examples | Retention | Access | Encryption |
|---|---|---|---|---|
| **Public** | Marketing content, public docs | Indefinite | Open | Optional |
| **Internal** | Employee directories, internal reports | Defined by policy | Authenticated | Recommended |
| **Confidential** | Business plans, contracts, financials | Defined by policy | RBAC, need-to-know | Required |
| **Restricted** | PII, PHI, NPI, payment data, credentials | Minimum necessary (regulatory) | Strict RBAC, audit logged | Required, at rest + in transit |

### Principles
- Classify at creation time (not after the fact)
- Classification drives retention, access controls, encryption requirements, and deletion policy
- If you don't know what classification data has, treat it as restricted (safe default)

### Overlap
Data classification from the compliance/legal angle is covered in `../data-privacy/README.md`. This section covers the operational/engineering implementation.

---

## 2. Retention Policies

How long to keep data before it must be deleted or archived.

### Principles
- **Every data type must have a defined retention period** — "keep forever" is not a policy, it's neglect
- **Retention is driven by**: business need, legal/regulatory requirement, or cost
- **Shorter is better** — less data = less risk, less cost, less GDPR exposure
- **Automate enforcement** — don't rely on humans remembering to delete data

### Common retention periods

| Data type | Typical retention | Driver |
|---|---|---|
| Application logs | 7-30 days | Debugging (rarely needed beyond 2 weeks) |
| Audit logs | 1-7 years | Compliance (HIPAA: 6 years, SOX: 7 years, PCI: 1 year) |
| User PII | Until deletion request or account closure | GDPR/CCPA right to erasure |
| Backups | 30-90 days | Recovery (diminishing value over time) |
| Analytics/metrics | Raw: 30 days, downsampled: 1-5 years | Cost vs historical visibility |
| Financial records | 7 years | Tax/legal requirements |
| Session data | Hours to days | Functional (no value after session ends) |

### Implementation patterns
- Scheduled jobs that purge expired data (cron, K8s CronJob, cloud scheduler)
- Database partitioning by time (drop old partitions instead of DELETE)
- TTL on records (DynamoDB TTL, Redis EXPIRE, MongoDB TTL index)
- Object storage lifecycle policies (S3: transition to Glacier after 30 days, delete after 1 year)

### Anti-patterns
- No retention policy (data accumulates forever — cost grows, risk grows)
- Retention policy defined but not automated (documents says "30 days" but nothing enforces it)
- Same retention for all data types (PII kept as long as logs)
- Deleting data without considering regulatory minimums (must keep audit logs for 6 years, deleted after 30 days)

---

## 3. Soft Delete vs Hard Delete

### Soft delete
```sql
UPDATE users SET deleted_at = NOW() WHERE id = 123;
-- Add to all queries: WHERE deleted_at IS NULL
```

### Hard delete
```sql
DELETE FROM users WHERE id = 123;
-- Gone forever (unless backups)
```

### When to use which

| | Soft delete | Hard delete |
|---|---|---|
| **Use when** | Need to recover accidentally deleted data, audit trail, referential integrity | GDPR/CCPA right to erasure, data must truly be gone, storage cost |
| **Pros** | Recoverable, maintains references, audit history | Truly gone, saves storage, simpler queries |
| **Cons** | Queries need filter, storage keeps growing, GDPR risk (data still exists) | Unrecoverable, breaks foreign keys if not handled |

### GDPR and soft delete
- **Soft delete does NOT satisfy GDPR right to erasure** — the data still exists in your DB
- For GDPR deletion: hard delete PII, or anonymize (replace with `[DELETED]`, null out PII fields)
- You can keep non-PII data (order totals, anonymized analytics) after user deletion

### Principles
- Choose ONE approach per entity and be consistent
- If soft deleting, add `deleted_at IS NULL` to ALL queries (or use a view/default scope)
- Set a retention period on soft-deleted records (purge after 30-90 days)
- For GDPR: anonymize or hard delete PII within the required timeframe

### Anti-patterns
- Soft delete everything but never purging (DB grows, deleted data is a liability)
- Forgetting `deleted_at IS NULL` in some queries (deleted data appears to users)
- Soft delete for GDPR compliance (not compliant — data still exists)
- Hard delete without cascade/cleanup (orphaned records in related tables)

---

## 4. Archival

Moving old data to cheaper storage while maintaining access.

### Strategies

| Strategy | How | Access pattern |
|---|---|---|
| **Cold storage** | Move to S3/GCS/Azure Blob cold tier | Rarely accessed, batch read |
| **Separate database** | Move to a read-only archive database | Queryable but slower |
| **Table partitioning** | Partition by date, detach old partitions | Transparent to queries if needed, or exclude old partitions |
| **Data warehouse** | Move to analytical store (BigQuery, Snowflake) | Analytical queries, not operational |

### Principles
- Archive based on access pattern (data accessed < 1%/month → archive)
- Maintain queryability where needed (compliance may require access to historical data)
- Compress archived data (Parquet, gzip — reduce storage cost)
- Document what's archived and how to access it (don't create data graveyards)

### Anti-patterns
- Never archiving (production DB has 5 years of data, queries slow down)
- Archiving without an access path (data exists but nobody can query it if needed)
- No index on archived data (finding one record in 5TB of archives = full scan)
- Archiving PII without applying GDPR deletion when requested

---

## 5. Data Deletion Patterns

### Cascade deletion
When a parent is deleted, children are deleted too.
- Use database `ON DELETE CASCADE` for referential integrity
- Or application-level cascade (more control, can handle async deletion)

### Anonymization (GDPR-compliant alternative to deletion)
```sql
UPDATE users
SET name = '[DELETED]',
    email = '[DELETED]',
    phone = NULL,
    address = NULL,
    anonymized_at = NOW()
WHERE id = 123;
-- Keep: id, created_at, account type (non-PII for analytics)
```

### Deletion checklist
When a user requests deletion (GDPR/CCPA):
1. Identify ALL locations where PII exists (DB, cache, logs, backups, third-party services)
2. Delete/anonymize in primary database
3. Invalidate cache entries
4. Request deletion from third-party processors
5. Note: backups will contain the data until they rotate out (acceptable under GDPR if documented)
6. Confirm deletion to user within required timeframe

### Anti-patterns
- Only deleting from one table (PII scattered across 10 tables, only users table cleaned)
- Not checking cache (deleted user still served from Redis for hours)
- Not tracking third-party data sharing (PII sent to analytics/marketing tools, never deleted there)
- No documentation of where PII lives (can't comply with deletion requests completely)

---

## Tooling

| Tool | What it does |
|---|---|
| **pg_partman** (PostgreSQL) | Automated table partitioning by time |
| **MongoDB TTL indexes** | Automatic document expiration |
| **DynamoDB TTL** | Automatic item expiration |
| **S3 Lifecycle policies** | Automated transition/deletion by age |
| **AWS Data Lifecycle Manager** | EBS snapshot retention |
| **Data inventory tools** | OneTrust, BigID, DataGrail — discover where PII lives |

For the well-architected perspective on cost optimization (storage tiering, retention as cost control), see [`../../well-architected/cost-optimization.md`](../../well-architected/cost-optimization.md).
