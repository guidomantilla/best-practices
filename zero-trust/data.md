# Data Pillar

**Dev relevance: HIGH** — developers decide how data is classified, encrypted, accessed, and retained.

---

## What CISA Requires

Protect data through classification, encryption, access control, and monitoring — regardless of where data resides.

### Functions
- Data categorization (classification)
- Data availability (resilience, backups)
- Data access control (who can read/write what)
- Data encryption (at rest, in transit, in use)
- Data inventory and management (know where data lives)

---

## Maturity Levels

### Traditional
- Minimal data classification (or none)
- Encryption only in transit (if at all)
- Broad access to data stores (shared credentials, wide permissions)
- No data inventory (nobody knows where PII lives across all systems)
- Manual compliance checks

### Initial
- Data classification started (at least public vs confidential)
- Encryption in transit (TLS) and at rest (disk-level)
- Basic access controls on data stores (per-service credentials)
- Data inventory in progress
- Some data loss prevention (DLP) on egress

### Advanced
- Granular data classification enforced (public, internal, confidential, restricted)
- Field-level encryption for sensitive data (not just disk-level)
- Column-level / row-level access control in databases
- Automated data discovery and classification
- Data tagging and lineage tracked
- DLP policies enforced at network and application level
- Backup and recovery tested regularly

### Optimal
- Real-time data classification (automated, ML-assisted)
- Encryption everywhere including in-use (where feasible)
- Dynamic data access based on context (user + device + sensitivity + risk)
- Automated data lifecycle enforcement (retention, deletion, anonymization)
- Full data lineage across all systems (know where every piece of PII flows)
- Continuous monitoring of data access patterns (anomaly detection)
- Data sovereignty enforced (data stays in required jurisdiction)

---

## What Developers Own

### Data Classification

| Practice | Traditional | Zero Trust |
|---|---|---|
| No classification | ✅ common | ❌ everything must be classified |
| Manual classification | — | ✅ initial |
| Automated classification at write time | — | ✅ advanced |
| Real-time, ML-assisted classification | — | ✅ optimal |

**Dev actions:**
- Define classification in the data model (which fields are PII, PHI, NPI, public)
- Tag data at creation time (not after the fact)
- Use classification to drive access control, encryption, retention, and logging policies
- See `../backend-engineering/data-design/lifecycle.md` §1 for classification details

### Data Encryption

| Layer | Traditional | Zero Trust |
|---|---|---|
| In transit (TLS) | Sometimes | ✅ always, everywhere — including internal service-to-service |
| At rest (disk/volume) | Sometimes | ✅ always — managed by infra/cloud |
| At rest (field/column level) | Rare | ✅ for sensitive fields (SSN, card number, health data) |
| In use (application memory) | Never | ⚠️ emerging (confidential computing, enclaves) |

**Dev actions:**
- TLS on all connections — no exceptions, including internal services
- Sensitive fields encrypted at application level before storage (not just relying on disk encryption)
- Use KMS/key management — don't manage encryption keys in application code
- See `../backend-engineering/secure-coding/` §5.4 and `../backend-engineering/iac/` §2

### Data Access Control

| Practice | Traditional | Zero Trust |
|---|---|---|
| One DB credential shared by all services | ✅ common | ❌ per-service credentials, least privilege |
| SELECT * on all tables | ✅ common | ❌ per-service schema access |
| No audit of who queries what | ✅ common | ❌ all data access logged |
| Access based on sensitivity + context | — | ✅ advanced/optimal |

**Dev actions:**
- Each service has its own DB credentials with access only to its tables/schemas
- No shared database between services — see `../backend-engineering/system-design/system-level.md` (microservices data ownership)
- Row-level security where applicable (user A can't query user B's data)
- Log all access to sensitive data (who accessed what, when, from where)
- PII access requires explicit justification and audit trail

### Data Inventory

Know where data lives — all of it.

**Dev actions:**
- Document which services store what types of data (PII, PHI, NPI)
- Track data flows: where does PII enter? Where does it get stored? Where does it get sent (third parties, analytics, logs)?
- When a user requests deletion (GDPR/CCPA), you need to delete from ALL locations — see `../backend-engineering/data-design/lifecycle.md` §5
- Don't forget: caches (Redis), logs, backups, third-party services, browser storage

### Data Lifecycle

| Practice | Traditional | Zero Trust |
|---|---|---|
| Keep everything forever | ✅ common | ❌ retention policies per data type |
| Manual deletion on request | — | ✅ initial |
| Automated retention enforcement | — | ✅ advanced |
| Automated anonymization + programmatic deletion | — | ✅ optimal |

**Dev actions:**
- Define retention per data type — see `../backend-engineering/data-design/lifecycle.md` §2
- Automate purge/anonymization (don't rely on humans)
- Handle GDPR right to erasure / CCPA right to delete — see `../backend-engineering/data-privacy/`
- Soft delete does NOT satisfy GDPR — see `../backend-engineering/data-design/lifecycle.md` §3

---

## Anti-patterns

- No data classification (can't protect what you can't categorize)
- Encryption only at disk level ("encrypted at rest" but the app has full access to plaintext)
- One shared DB user for all services (compromise one service = access all data)
- PII in logs, error messages, URLs (data leakage in observability layer)
- No data inventory (user requests deletion, team can't find all copies)
- No retention policy (data accumulates forever — cost, risk, compliance violation)
- Data flows to third parties without tracking (analytics, marketing tools hold PII you forgot about)
- Backups not encrypted (full data exposure if backup is accessed)

---

## References

- [CISA ZTMM — Data Pillar](https://www.cisa.gov/sites/default/files/2023-04/zero_trust_maturity_model_v2_508.pdf)
- [NIST SP 800-53 — Data Protection Controls](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
