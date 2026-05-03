# Search Engine Design

Best practices for search engines (Elasticsearch, OpenSearch, Meilisearch, Typesense).

---

## 1. When to Use a Search Engine

### Good fit
- Full-text search (natural language queries across text fields)
- Fuzzy matching, typo tolerance, autocomplete
- Faceted filtering (filter by category, price range, color — with counts)
- Relevance-ranked results (not just match/no-match)
- Log/event search (ELK stack)

### Not a good fit
- Primary data storage (use as secondary index, not source of truth)
- Exact-match key lookups (use KV store — faster, cheaper)
- Transactional operations (no ACID)
- Real-time strong consistency (search indexes are eventually consistent)
- Simple LIKE queries on small datasets (PostgreSQL full-text or `ILIKE` is enough)

---

## 2. Index Design

### Principles
- Index per use case, not per table (an index may combine data from multiple sources)
- Define mappings explicitly — don't rely on auto-detection (wrong field types are expensive to fix)
- Separate search index from primary storage — search engine is a read-optimized copy, not the source of truth

### Mapping (schema)
```json
{
  "mappings": {
    "properties": {
      "title": { "type": "text", "analyzer": "standard" },
      "title_exact": { "type": "keyword" },
      "price": { "type": "float" },
      "category": { "type": "keyword" },
      "created_at": { "type": "date" },
      "description": { "type": "text", "analyzer": "english" }
    }
  }
}
```

### Field types

| Type | Use | Searchable | Sortable/Filterable |
|---|---|---|---|
| **text** | Full-text search (tokenized, analyzed) | Yes (fuzzy, partial) | No |
| **keyword** | Exact match, filtering, aggregations | Exact only | Yes |
| **numeric** (float, int, long) | Range filters, sorting | Range | Yes |
| **date** | Time-based filtering and sorting | Range | Yes |
| **boolean** | Binary filters | Exact | Yes |

### Anti-patterns
- No explicit mapping (auto-detection assigns wrong types — `"123"` becomes text, not number)
- One giant index for everything (different retention, different schemas — separate them)
- Using `text` type for fields you need to filter/sort on (use `keyword` or multi-field)
- Mapping explosion (thousands of dynamic fields — kills cluster performance)

---

## 3. Analyzers & Tokenization

### How text search works
```
Input: "The quick brown FOX jumped"
Analyzer: standard
Tokens: ["the", "quick", "brown", "fox", "jumped"]
```

Query "fox" matches because the token exists in the index.

### Built-in analyzers

| Analyzer | What it does | When |
|---|---|---|
| **standard** | Lowercase + tokenize on whitespace/punctuation | Default, most Western languages |
| **english** (language) | Standard + stemming (`running` → `run`) + stop words | English text content |
| **keyword** | No analysis — entire value as one token | Exact match fields |
| **whitespace** | Tokenize on whitespace only (no lowercase) | Case-sensitive, space-separated |

### Custom analyzers
For specific needs: synonym handling, n-grams (autocomplete), phonetic matching, language-specific.

### Anti-patterns
- Using `keyword` analyzer on text you want to search (no tokenization = only exact match)
- No language-specific analyzer for non-English content
- Over-analyzing (too many n-gram variations = bloated index)

---

## 4. Query Patterns

### Types

| Query type | What it does | When |
|---|---|---|
| **Match** | Full-text search on analyzed fields | User search box |
| **Term** | Exact match on keyword fields | Filtering by status, category |
| **Range** | Numeric/date range | Price $10-$50, date last 7 days |
| **Bool (must/should/filter)** | Combine multiple conditions | Complex search with filters |
| **Multi-match** | Search across multiple fields | Query matches title OR description |
| **Prefix / Wildcard** | Starts-with, pattern matching | Autocomplete |
| **Fuzzy** | Tolerates typos (Levenshtein distance) | Typo-tolerant search |

### Principles
- Use `filter` context for exact conditions (cached, faster — no relevance scoring)
- Use `must`/`should` for relevance-scored full-text (affects ranking)
- Combine: full-text in `must`, structured filters in `filter`
- Limit result size (don't fetch 10,000 results — paginate)

### Anti-patterns
- `match_all` with client-side filtering (defeats the purpose of a search engine)
- Deep pagination with `from/size` beyond 10,000 (use `search_after` or scroll)
- Wildcard queries with leading wildcards (`*fox` — can't use index, full scan)
- Not using filter context for non-scoring conditions (wastes CPU on scoring)

---

## 5. Relevance & Ranking

### How scoring works (simplified)
- **TF** (Term Frequency): how often the term appears in the document
- **IDF** (Inverse Document Frequency): how rare the term is across all documents
- **Field length**: shorter fields with the term score higher (title match > body match)

### Tuning relevance
- **Boost fields**: `title^3` (title matches score 3x more than body)
- **Function score**: custom scoring functions (newer = higher, more popular = higher)
- **Synonyms**: expand queries (`laptop` also matches `notebook`)
- **Stopwords**: ignore common words (`the`, `is`, `and`) that don't add signal

### Anti-patterns
- Default scoring with no tuning (title match and body match weighted equally)
- Boosting everything (if everything is boosted, nothing is)
- Ignoring user feedback (click data can improve relevance — track what users actually select)

---

## 6. Operational Concerns

### Syncing from primary store
- Search index is a **secondary copy** — sync from the source of truth
- Sync via: events (preferred), CDC, or periodic bulk reindex
- Expect eventual consistency (seconds of delay between write and searchable)

### Index lifecycle
- **Aliases**: point queries to an alias, reindex behind the scenes, swap alias when ready (zero downtime reindex)
- **Time-based indices**: for logs/events, one index per day/week — delete old indices for retention
- **Reindexing**: needed when mappings change (can't change field types in place)

### Anti-patterns
- Search engine as source of truth (if it goes down, data is lost)
- No reindex strategy (mapping change = stuck with bad schema forever)
- Manual sync (human triggers reindex — data drifts silently between syncs)
- No index aliases (reindex requires downtime or client changes)

---

## Tooling

| Tool | What it does |
|---|---|
| **Elasticsearch / OpenSearch** | Full-featured distributed search (most common) |
| **Meilisearch** | Simple, fast, typo-tolerant (good for product search, autocomplete) |
| **Typesense** | Similar to Meilisearch, developer-friendly |
| **PostgreSQL FTS** | Built-in full-text search (good enough for simple cases) |
| **Algolia** | Search-as-a-service (SaaS, instant, expensive at scale) |
