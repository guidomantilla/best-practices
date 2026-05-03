# Async Messaging Contract Design

Best practices for designing asynchronous communication: message queues (MOMs), events, and webhooks.

---

## 1. When to Use Async Messaging

### Good fit
- Decoupling producer from consumer (producer doesn't wait for result)
- Workload that can be processed later (email sending, report generation, image processing)
- Event-driven architectures (something happened, multiple systems react)
- Guaranteed delivery required (even if consumer is temporarily down)
- Fan-out (one event, multiple consumers)

### Not a good fit
- Client needs immediate response (use REST/gRPC)
- Simple request/response (async adds complexity for no benefit)
- Real-time user interaction (use WebSocket/SSE)

---

## 2. Message Design

### Envelope
```json
{
  "id": "msg-uuid-123",
  "type": "order.created",
  "source": "order-service",
  "timestamp": "2026-05-01T10:30:00Z",
  "correlation_id": "req-abc-456",
  "data": {
    "order_id": "order-789",
    "customer_id": "cust-012",
    "total": 99.99
  },
  "metadata": {
    "version": "1.0",
    "content_type": "application/json"
  }
}
```

### Required fields
- `id` — unique message identifier (for deduplication)
- `type` — what happened (consumers route based on this)
- `source` — who produced it (debugging, filtering)
- `timestamp` — when it was produced (ordering, debugging)
- `data` — the payload

### Recommended fields
- `correlation_id` — trace the original request across services
- `version` — schema version for evolution
- `content_type` — how to deserialize the payload

### Anti-patterns
- No message ID (can't deduplicate, can't track)
- No type (consumer has to inspect payload to determine what it is)
- Timestamp in non-standard format (use ISO 8601 / RFC 3339)
- Payload without schema version (can't evolve safely)
- Embedding the entire entity state when only the event matters

---

## 3. Queue Topologies

How messages flow from producers to consumers.

### Patterns

| Pattern | How it works | Use case | Example tools |
|---|---|---|---|
| **Point-to-point (Queue)** | One producer, one consumer. Message consumed once. | Task processing, job queues | SQS, RabbitMQ (queue) |
| **Work queue (Competing consumers)** | One producer, multiple consumers. Each message processed by exactly one consumer. | Parallel processing, load distribution | SQS, RabbitMQ (queue + multiple workers) |
| **Pub/Sub (Fan-out)** | One producer, multiple subscribers. Each subscriber gets a copy. | Event notification, decoupled reactions | SNS, Kafka (consumer groups), RabbitMQ (fanout exchange), Google Pub/Sub |
| **Topic-based routing** | Producer publishes to a topic, consumers subscribe to patterns. | Selective consumption by event type | RabbitMQ (topic exchange), NATS subjects, Kafka topics |
| **Request/Reply** | Producer sends and waits for a reply on a response queue. | Async request/response, RPC over messaging | RabbitMQ (reply-to), NATS request/reply |

### Queue configuration options

| Option | What it does | When to use |
|---|---|---|
| **TTL (Time-to-Live)** | Message expires after N seconds if not consumed | Time-sensitive tasks (OTP codes, session events) |
| **Delay queue** | Message not visible until N seconds after publish | Scheduled tasks, retry after delay |
| **Priority queue** | Higher priority messages consumed first | Paid users before free, critical before routine |
| **FIFO** | Strict ordering guaranteed | State machines, financial transactions |
| **Max length** | Queue drops/rejects messages beyond N | Backpressure, prevent unbounded growth |
| **Dead Letter (DLQ)** | Failed messages routed to a separate queue | Error handling (see §5) |

### Choosing the right pattern
- Need one consumer to process each message? → **Work queue**
- Need multiple systems to react to the same event? → **Pub/Sub**
- Need selective routing by event type? → **Topic-based**
- Need strict ordering per entity? → **FIFO with partition/group key**
- Need scheduled/delayed processing? → **Delay queue**

### Anti-patterns
- Using pub/sub when only one consumer exists (unnecessary complexity)
- Using point-to-point when multiple systems need the event (future consumers blocked)
- No max length or TTL (queue grows unbounded during consumer downtime)
- FIFO for everything (kills throughput when ordering isn't needed)
- Priority queue with 10 priority levels (effectively no prioritization)

---

## 4. Delivery Guarantees

| Guarantee | What it means | Risk |
|---|---|---|
| **At-most-once** | Message delivered 0 or 1 times. May be lost. | Data loss possible |
| **At-least-once** | Message delivered 1 or more times. May be duplicated. | Duplicates possible |
| **Exactly-once** | Message delivered exactly 1 time. | Hardest to achieve (usually at-least-once + idempotency) |

### Principles
- **Design for at-least-once** — it's the practical default for most systems (Kafka, SQS, RabbitMQ)
- **Make consumers idempotent** — processing the same message twice produces the same result
- **Use idempotency keys** — the message `id` or a business key to detect duplicates
- **Acknowledge after processing** — not before (otherwise a crash loses the message)

### Idempotency patterns
- Store processed message IDs (deduplication table)
- Use database constraints (unique key on business ID)
- Design operations to be naturally idempotent (upsert instead of insert)

### Anti-patterns
- Acknowledging before processing (crash = message lost forever)
- No deduplication logic (at-least-once + non-idempotent consumer = corrupted data)
- Assuming exactly-once without building for it (most brokers don't guarantee it end-to-end)

### Transactional Outbox

Guarantees that a database write and a message publish happen atomically — even though DB and broker are separate systems.

```
1. Write to DB (business data + outbox table) in one transaction
2. Separate process reads outbox table, publishes to broker
3. Mark outbox row as published
```

Why: without this, you either lose messages (publish fails after DB commit) or publish messages for failed transactions (publish succeeds, DB rolls back).

| Implementation | How |
|---|---|
| **Polling publisher** | Background job polls outbox table, publishes pending messages |
| **Change Data Capture (CDC)** | Debezium/similar captures DB changes, publishes automatically |
| **Transaction log tailing** | Read the DB WAL/binlog directly |

### Consumption Patterns

| Pattern | How | When |
|---|---|---|
| **Push (Event-Driven)** | Broker pushes messages to consumer as they arrive | Low-latency, most common (Kafka consumer, SQS with Lambda trigger) |
| **Pull (Polling)** | Consumer polls the broker at intervals | Batch processing, rate-controlled consumption |

Principles:
- Push for real-time consumers (services that need to react immediately)
- Pull for batch consumers (aggregate N messages, process together)
- Pull with long-polling is a hybrid (SQS long poll — waits up to 20s for a message, avoids empty polls)

---

## 5. Ordering

### Principles
- **Global ordering is expensive** — only require it when semantically necessary
- **Partition-key ordering** — messages with the same key are ordered (Kafka partitions, SQS FIFO group ID)
- **Design for out-of-order** where possible — use timestamps and version numbers to handle reordering

### When ordering matters
- State-machine transitions (created → paid → shipped — out of order = broken state)
- Aggregate events (all events for one entity must be in order)

### When ordering doesn't matter
- Independent events about different entities
- Notifications (email, push) — a few ms difference is irrelevant
- Analytics/logging — can be reordered at query time

### Anti-patterns
- Requiring global ordering on a high-throughput topic (kills parallelism)
- No partition key (messages for the same entity spread across partitions — order lost)
- Assuming ordering without configuring it (default SQS is unordered)

---

## 6. Dead Letter Queues (DLQ)

Messages that can't be processed after N retries.

### Principles
- Every queue/subscription should have a DLQ configured
- Define max retry count before DLQ (e.g., 3-5 retries)
- DLQ messages need monitoring and alerting (not just dumped and forgotten)
- DLQ messages should be replayable (re-send to the original queue after fixing)
- Include failure reason with the dead-lettered message

### Anti-patterns
- No DLQ (poisoned messages retry forever, blocking the queue)
- DLQ without alerting (messages rot there for months unnoticed)
- No replay mechanism (have to manually re-create messages)
- DLQ retention too short (messages expire before anyone looks)

---

## 7. Schema Evolution

### Principles
- Schema changes must be backward compatible (old consumers can read new messages)
- Forward compatible is ideal too (new consumers can read old messages)
- Version in the message envelope (`"version": "1.2"`)
- Schema registry for enforcement (Confluent Schema Registry, AWS Glue)

### Safe changes
- Add new optional fields
- Add new event types
- Add new enum values (if consumers handle unknown values gracefully)

### Breaking changes (require new version or new topic)
- Remove fields
- Change field types
- Change field semantics
- Change topic/queue name

### Anti-patterns
- No schema version in messages (can't detect which format a message uses)
- Breaking changes deployed without migration (old consumers crash)
- No schema registry (contract is "whatever the last deploy produces")

---

## 8. Events vs Commands

| | Event | Command |
|---|---|---|
| **Intent** | "This happened" | "Do this" |
| **Naming** | Past tense: `order.created`, `payment.completed` | Imperative: `process_payment`, `send_email` |
| **Producer knows consumer?** | No — fire and forget | Yes — directed at specific consumer |
| **Coupling** | Loose (producer doesn't care who listens) | Tighter (producer expects a specific action) |
| **Fan-out** | Natural (multiple subscribers) | Typically one consumer |

### Principles
- **Events for decoupling**: producer publishes what happened, consumers decide what to do
- **Commands for orchestration**: explicitly telling a service to do something
- Don't mix in the same topic/queue — separate concerns

### Anti-patterns
- Events named as commands (`send_email_event` — that's a command)
- Commands broadcast to multiple consumers (confusing — who's responsible?)
- One giant "event bus" with events and commands mixed together

---

## 9. Webhooks

Outbound notifications to external systems over HTTP.

### Design principles
- `POST` to the subscriber's URL with the event payload
- Include signature for verification (`X-Webhook-Signature`: HMAC of payload)
- Retry on failure (exponential backoff: 1s, 5s, 30s, 5min, 1h)
- Idempotent delivery (include event ID, consumer deduplicates)
- Allow subscribers to configure which events they receive

### Payload
```json
{
  "id": "evt-123",
  "type": "invoice.paid",
  "created_at": "2026-05-01T10:30:00Z",
  "data": {
    "invoice_id": "inv-456",
    "amount": 99.99,
    "currency": "USD"
  }
}
```

### Security
- Sign payloads (HMAC-SHA256 with shared secret)
- Verify signature on the receiving end before processing
- Use HTTPS only
- Allow IP allowlisting (publish your webhook source IPs)
- Implement webhook secret rotation

### Anti-patterns
- No signature (receiver can't verify authenticity — spoofable)
- No retry on failure (one failed delivery = event lost)
- Infinite retries without backoff (DDoS the subscriber)
- Sending sensitive data without encryption
- No way for subscriber to verify events (no verification endpoint)

---

## 10. Topic/Queue Naming

### Conventions
```
# By domain + event
orders.created
orders.updated
payments.completed
users.signed_up

# By team/service + domain + event
checkout.orders.created
billing.invoices.paid
```

### Principles
- Consistent pattern across all topics/queues
- Dot-separated hierarchy (allows wildcard subscriptions: `orders.*`)
- Include the domain/bounded context
- Event-type as suffix

### Anti-patterns
- Generic names (`events`, `messages`, `queue1`)
- Inconsistent naming (`OrderCreated` vs `order-created` vs `order.create`)
- One topic for all events from a service (can't subscribe selectively)

---

## Tooling

| Tool | What it does |
|---|---|
| **AsyncAPI** | Define async/event contracts as spec (like OpenAPI for messaging) |
| **Confluent Schema Registry** | Schema storage, compatibility validation (Avro, Protobuf, JSON Schema) |
| **AWS Glue Schema Registry** | Same for AWS ecosystem |
| **Kafka** | Distributed event streaming (partitioned, ordered, durable) |
| **RabbitMQ** | Traditional message broker (routing, exchanges, queues) |
| **NATS** | Lightweight, high-performance messaging |
| **SQS / SNS** | AWS managed queues and pub/sub |
| **Google Pub/Sub** | GCP managed pub/sub |
| **Svix** | Webhook delivery as a service (retries, monitoring, management) |
