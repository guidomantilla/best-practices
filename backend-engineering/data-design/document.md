# Document Store Design

Best practices for document databases (MongoDB, Firestore, CouchDB, DynamoDB in document mode).

---

## 1. Data Modeling

### The fundamental decision: embed vs reference

| Strategy | When | Trade-off |
|---|---|---|
| **Embed** (nested document) | Data is always read together, 1:1 or 1:few relationship, data doesn't change independently | Reads are fast (single query), writes update the whole document |
| **Reference** (ID pointer) | Data is shared across documents, 1:many or many:many, data changes independently | Reads require multiple queries (or $lookup), writes are independent |

### Guidelines
- **Embed** when: the child data belongs to the parent and is never queried independently (address in user, items in order)
- **Reference** when: the child data is shared (author referenced by many books), frequently updated independently, or unbounded (comments that grow indefinitely)
- **Hybrid**: embed a summary (denormalized), reference for full detail

### Anti-patterns
- Embedding unbounded arrays (document grows without limit → hits size limits, performance degrades)
- Referencing everything like a relational DB (defeats the purpose of a document store — you get N+1 queries)
- One giant collection with mixed document shapes (no schema cohesion)
- Treating document DB as relational (forcing JOINs via $lookup on every read)

---

## 2. Schema Evolution

"Schemaless" doesn't mean "no schema" — it means the schema is implicit and in your application code.

### Principles
- **Define the expected schema** even without DB enforcement (use application-level validation: Mongoose schemas, Pydantic, Zod)
- **Version your documents**: add a `schema_version` field. Migrate on read or via batch job.
- **Additive changes are safe**: adding new fields doesn't break existing documents
- **Handle missing fields gracefully**: old documents won't have new fields — code must handle `null`/`undefined`

### Migration strategies

| Strategy | How | When |
|---|---|---|
| **Lazy migration** | Update document to new schema when it's next read/written | Low urgency, gradual |
| **Batch migration** | Script that updates all documents | Need consistency across all docs immediately |
| **Dual-read** | Application handles both old and new format | During transition period |

### Anti-patterns
- No schema_version (impossible to know which format a document is in)
- Breaking changes without migration (removing fields that old code expects)
- "Just redeploy and it'll work" without handling existing documents
- Schema drift across environments (dev has v3, production still has v1 documents)

---

## 3. Query Patterns

### Principles
- **Model for your queries** — in document stores, the read pattern drives the schema (unlike relational where you normalize first)
- **Denormalize for read performance** — duplicate data is acceptable if it eliminates expensive joins
- **Accept write complexity** — denormalization means updates touch multiple documents (trade-off)

### Indexing
- Index fields you filter on, sort by, or use in aggregations
- Compound indexes follow the ESR rule: **Equality → Sort → Range**
- Sparse/partial indexes for fields that only exist on some documents
- Text indexes for search (but consider a dedicated search engine for serious full-text)

### Anti-patterns
- $lookup (JOIN) in hot paths — if you need JOINs frequently, reconsider your model (or use relational)
- Querying without indexes (collection scan on millions of documents)
- Unbounded aggregation pipelines without limits
- Reading entire documents when you only need 2 fields (use projection)

---

## 4. Consistency & Transactions

### MongoDB (as representative)
- **Single document operations are atomic** by default
- **Multi-document transactions** available since MongoDB 4.0 (but expensive — use sparingly)
- **Read concerns**: `local`, `majority`, `linearizable` — choose based on consistency need
- **Write concerns**: `w:1` (fast, risk of data loss), `w:majority` (safe, slower)

### Principles
- Design so that related data lives in ONE document where possible (atomic by default, no transaction needed)
- Use transactions only when you MUST update multiple documents atomically (rare in well-modeled document stores)
- For eventual consistency between collections, consider event-driven patterns (outbox + async sync)

### Anti-patterns
- Wrapping every operation in a transaction (performance overhead, unnecessary)
- `w:1` on financial/critical data (data loss if primary fails before replication)
- Ignoring read concerns (reading stale data from secondaries in consistency-sensitive operations)

---

## 5. Document Size & Growth

### Principles
- Document size limits exist (MongoDB: 16MB, Firestore: 1MB)
- Design so documents don't grow unbounded
- Arrays within documents should have a known upper bound (not thousands of elements)

### Patterns for unbounded data
- **Bucket pattern**: group related items into buckets of fixed size (e.g., 100 comments per bucket document)
- **Overflow**: when array reaches N items, create a new document and link
- **Separate collection**: if it grows without bound, it's not embedded — it's its own collection with a reference

### Anti-patterns
- Pushing to arrays indefinitely (document size grows until it hits the limit)
- Storing file content in documents (use object storage, store reference)
- One document per user with ALL their history embedded (millions of events in one doc)
