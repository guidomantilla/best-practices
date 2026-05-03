# Contract Design Best Practices

Principles for designing communication contracts between components — how services, clients, and systems talk to each other. Covers synchronous and asynchronous protocols.

This is the **index**. Each protocol/type has its own file with specific patterns and anti-patterns.

---

## Scope

| File | What it covers |
|---|---|
| [rest.md](rest.md) | HTTP REST APIs — resource design, versioning, pagination, error formats, HATEOAS |
| [grpc.md](grpc.md) | gRPC — proto design, streaming, error codes, backward compatibility |
| [graphql.md](graphql.md) | GraphQL — schema design, resolvers, N+1, pagination, auth |
| [websockets.md](websockets.md) | WebSockets — connection lifecycle, heartbeats, reconnection, message design |
| [async-messaging.md](async-messaging.md) | Async messaging — MOMs (Kafka, RabbitMQ, SQS, NATS), events, webhooks, delivery guarantees |

---

## Cross-Cutting Principles

These apply regardless of protocol.

### 1. Contract-First Design

Design the contract before writing implementation.

- Define the interface (schema, endpoints, message format) first
- Implementation follows the contract, not the other way around
- Contract is the source of truth — both producer and consumer agree on it
- Generate code from contract where possible (OpenAPI → client SDKs, proto → stubs)

### 2. Backward Compatibility

Changes to a contract must not break existing consumers.

- **Additive changes are safe**: new fields, new endpoints, new message types
- **Breaking changes require versioning**: removing fields, renaming fields, changing types, changing semantics
- **Never assume all consumers update simultaneously** — old consumers will call your new API

### 3. Explicit Over Implicit

The contract should be self-describing.

- Error responses have a consistent, documented shape
- Pagination strategy is explicit (not "it just returns 100 by default")
- Auth requirements are documented per endpoint/operation
- Rate limits are communicated (headers, docs)
- Deprecation is communicated before removal

### 4. Idempotency

Operations that can be retried without side effects.

- Clients will retry. Networks fail. Messages get delivered twice.
- Mutating operations should be idempotent where possible (use idempotency keys)
- Design for "at-least-once" delivery — your system handles duplicates gracefully

### 5. Schema Validation

Validate at the boundary, trust internally.

- Validate incoming data at the entry point (request handler, message consumer)
- Reject invalid data with clear error messages
- Don't validate again deep inside business logic — trust the boundary
- Schema validation should be automated (middleware, framework-level)

### 6. Versioning Strategy

How to evolve contracts without breaking consumers.

| Strategy | How | When to use |
|---|---|---|
| **URL path** | `/v1/users`, `/v2/users` | REST APIs with major breaking changes |
| **Header** | `Accept: application/vnd.myapp.v2+json` | REST APIs that want cleaner URLs |
| **Package** | `package myservice.v1;` | gRPC / protobuf |
| **Field deprecation** | Mark fields as deprecated, add new ones | Additive evolution (preferred) |
| **No versioning** | Evolve additively, never break | When you control all consumers |

### 7. Documentation as Contract

The documentation IS the contract — not a supplement to it.

- OpenAPI/Swagger for REST
- `.proto` files for gRPC
- GraphQL schema (SDL) for GraphQL
- AsyncAPI for event-driven / messaging
- These are machine-readable — generate clients, validate requests, run tests

---

## Choosing the Right Protocol

| Protocol | Best for | Not ideal for |
|---|---|---|
| **REST** | CRUD operations, public APIs, broad compatibility, stateless request/response | Real-time streams, high-throughput internal services |
| **gRPC** | Internal service-to-service, high throughput, streaming, strongly typed | Browser clients (without proxy), public APIs (tooling ecosystem) |
| **GraphQL** | Client-driven data fetching, multiple client types (web, mobile), reducing over-fetching | Simple CRUD, server-to-server, real-time events |
| **WebSockets** | Real-time bidirectional (chat, live updates, collaborative editing) | Request/response patterns, stateless operations |
| **Async messaging** | Decoupled services, event-driven, fire-and-forget, guaranteed delivery | Synchronous request/response, low-latency queries |

### Decision framework

1. **Who is the consumer?** Browser → REST or GraphQL. Internal service → gRPC or async. Real-time → WebSocket or SSE.
2. **Is it synchronous?** Needs immediate response → REST/gRPC/GraphQL. Can be eventual → async messaging.
3. **Who controls the consumers?** You control all → gRPC/async (can evolve freely). External/public → REST (broadest compatibility).
4. **Volume and latency?** High throughput + low latency → gRPC. Moderate → REST. Decoupled → async.

---

## Tooling (Cross-Protocol)

| Category | Tool | What it does |
|---|---|---|
| **REST spec** | OpenAPI / Swagger | Machine-readable REST contract definition |
| **Async spec** | AsyncAPI | Machine-readable async/event contract definition |
| **gRPC spec** | `.proto` files | Protocol Buffers schema definition |
| **GraphQL spec** | SDL (Schema Definition Language) | GraphQL schema |
| **Contract testing** | Pact | Verify consumers and providers agree |
| **Schema registry** | Confluent Schema Registry, AWS Glue | Centralized schema storage + compatibility checks |
| **Linting** | Spectral (OpenAPI), buf (proto), graphql-eslint | Validate contract quality |
| **Code generation** | openapi-generator, protoc, graphql-codegen | Generate clients/servers from contract |

---

## References

- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)
- [AsyncAPI Specification](https://www.asyncapi.com/docs/reference/specification/latest)
- [Protocol Buffers Language Guide](https://protobuf.dev/programming-guides/proto3/)
- [GraphQL Specification](https://spec.graphql.org/)
- [Martin Fowler — Richardson Maturity Model](https://martinfowler.com/articles/richardsonMaturityModel.html)
- [Microsoft — API Design Best Practices](https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design)
