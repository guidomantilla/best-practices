---
name: assess-contract-design
description: Review API and communication contracts for design issues, anti-patterns, and consistency. Use when the user asks to review REST API design, gRPC protos, GraphQL schemas, WebSocket message formats, event schemas, or webhook implementations. Triggers on requests like "review my API", "check my proto", "is my GraphQL schema well designed", "review my event schema", or "/assess-contract-design".
---

# Contract Design Review

Review communication contracts for design issues, consistency, and evolution safety. Produce actionable findings — not generic "follow REST conventions" advice.

## Domain Detection

| Signal | Domain | Context files to read |
|---|---|---|
| OpenAPI, .proto, GraphQL SDL, HTTP handlers, gRPC services, queue producers | **Backend (API designer)** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/contract-design/` (README + protocol-specific file) |
| React/Vue/Angular consuming APIs, fetch/axios, TanStack Query, Apollo Client | **Frontend (API consumer)** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/frontend-engineering/contract-consumption/README.md` |
| Avro schemas, Schema Registry, dbt contracts, data producer/consumer patterns | **Data (schema contracts)** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/data-engineering/contract-design/README.md` |
| LLM API endpoints, streaming responses, tool_use/function calling, structured outputs | **AI (AI API design)** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/ai-engineering/contract-design/README.md` |

Backend contract-design files by protocol (read only what's relevant):
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/contract-design/rest.md` — REST
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/contract-design/grpc.md` — gRPC
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/contract-design/graphql.md` — GraphQL
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/contract-design/websockets.md` — WebSockets
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/contract-design/async-messaging.md` — Async messaging, events, webhooks

## Review Process

1. **Detect domain and protocol(s)**: backend designing APIs? Frontend consuming APIs? Data producing/consuming schemas?
2. **Identify consumers**: who uses this contract? Internal services, external clients, mobile, browser, data pipelines?
3. **Assess evolution safety**: can this contract evolve without breaking existing consumers?
4. **Scan against applicable rules**: backend (contract-first, backward compat, idempotency, protocol-specific rules). Frontend (client generation, error handling, optimistic updates, zero trust assumptions). Data (schema formats, registry, compatibility modes, data contracts as code).
5. **Report findings**: list each issue with impact, location, and fix.
6. **Recommend tooling**: based on detected domain and protocol, suggest applicable tools.
7. **Offer capabilities**: based on findings, offer additional deliverables.

## Review Areas

### Cross-cutting (all protocols)
1. **Contract-first** — is the contract defined as spec (OpenAPI, proto, SDL, AsyncAPI) or just emergent from code?
2. **Backward compatibility** — can existing consumers still work after recent/proposed changes?
3. **Versioning strategy** — is there a clear versioning approach? Is it applied consistently?
4. **Idempotency** — are mutating operations safe to retry?
5. **Error handling** — consistent error format? Proper status/error codes?
6. **Documentation** — is the contract self-documenting (spec file) or implicit (requires reading code)?

### REST-specific
7. **Resource design** — proper nouns, HTTP methods, nesting
8. **Status codes** — correct usage, no 200-with-error-body
9. **Pagination** — present, appropriate strategy
10. **Naming consistency** — URL style, field naming, conventions

### gRPC-specific
7. **Proto structure** — versioned packages, one service per file, proper field naming
8. **Message design** — unique request/response per RPC, no field number reuse, reserved fields
9. **Streaming** — appropriate use (not over-engineered)
10. **Error codes** — proper gRPC status codes, rich error details

### GraphQL-specific
7. **Schema design** — domain types (not DB tables), proper nullability
8. **N+1 prevention** — DataLoader usage, resolver efficiency
9. **Mutations** — input/payload pattern, domain verbs
10. **Query protection** — depth/complexity limits, rate limiting

### WebSocket-specific
7. **Message format** — typed envelope, correlation IDs, timestamps
8. **Connection lifecycle** — auth, heartbeat, reconnection, idle timeout
9. **Scaling** — pub/sub backbone, state management

### Async messaging-specific
7. **Message envelope** — id, type, source, timestamp, correlation_id, version
8. **Delivery guarantees** — at-least-once + idempotent consumers, DLQ configured
9. **Ordering** — partition key strategy where ordering matters
10. **Schema evolution** — versioned, backward compatible, registry

## Impact Assessment

| Impact | Criteria |
|---|---|
| **High** | Breaking change deployed without versioning, no idempotency on critical mutations, no error format, messages without IDs (can't deduplicate) |
| **Medium** | Inconsistent naming, missing pagination, no schema spec (implicit contract), no DLQ |
| **Low** | Minor naming inconsistencies, suboptimal pagination strategy, missing optional metadata |

## Output Format

### Findings

For each finding:

```
### [IMPACT] — Short description
- **File**: openapi.yaml:42 / user.proto:15 / schema.graphql:30 / handler.go:80
- **Area**: which review area (cross-cutting or protocol-specific)
- **Issue**: what's wrong
- **Fix**: specific action to take (with schema/code snippet if applicable)
- **Tool**: which tool would catch this automatically
```

### Summary

```
## Summary
- High: N
- Medium: N
- Low: N
- Protocol(s): [REST | gRPC | GraphQL | WebSocket | Async messaging]
- Contract spec present: [OpenAPI | proto | SDL | AsyncAPI | none (implicit)]
- Versioning: [URL path | header | package | none]
- Backward compatible: [yes | no | unclear]
- Consumers: [internal | external | both | unknown]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable:

```
## What I Can Generate

Based on this review, I can also:
- [ ] Generate an OpenAPI/AsyncAPI/proto spec from the existing code
- [ ] Detect breaking changes between two versions of the contract
- [ ] Propose a versioning and deprecation strategy
- [ ] Design error response format for this API
- [ ] Generate client SDK scaffolds from the contract
- [ ] Create a pagination implementation for detected list endpoints
- [ ] Design the message envelope for async communication
- [ ] Propose topic/queue naming conventions

Select which ones you'd like me to generate.
```

Only list capabilities that are relevant to the findings and context.

## What NOT to Do

- Don't prescribe REST to a team using gRPC (or vice versa) — review the chosen protocol on its merits
- Don't flag style preferences as errors (camelCase vs snake_case — just flag inconsistency)
- Don't recommend GraphQL complexity limits for an internal-only API with 2 consumers
- Don't flag missing pagination on endpoints that return bounded data (e.g., enum-like lists)
- Don't assume the wrong protocol — check what's actually used before reviewing
- Don't recommend switching message brokers (Kafka vs RabbitMQ) — that's an infrastructure decision
- Don't flag code you haven't read
- Don't recommend AsyncAPI/OpenAPI if the team has 1 service and 1 consumer (overhead may not be worth it)
