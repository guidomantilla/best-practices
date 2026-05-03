# gRPC Contract Design

Best practices for designing gRPC services and Protocol Buffer schemas.

---

## 1. Proto File Design

### Principles
- One `.proto` file per service (or per bounded context)
- Package naming follows reverse domain: `package mycompany.myservice.v1;`
- Version in the package name — not in the file name
- Use `proto3` syntax (proto2 is legacy)

### File structure
```protobuf
syntax = "proto3";

package mycompany.orders.v1;

option go_package = "github.com/mycompany/orders/v1";
option java_package = "com.mycompany.orders.v1";

import "google/protobuf/timestamp.proto";

service OrderService {
  rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse);
  rpc GetOrder(GetOrderRequest) returns (Order);
  rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse);
}
```

### Anti-patterns
- No package versioning (can't evolve without breaking consumers)
- Multiple services in one proto file (hard to navigate, generates bloated code)
- Missing `option go_package` / `option java_package` (breaks code generation)

---

## 2. Message Design

### Principles
- Each RPC gets its own `Request` and `Response` message (even if they seem similar now — they'll diverge)
- Field numbers are forever — never reuse a deleted field number
- Use wrapper types for optional primitives (`google.protobuf.StringValue` or proto3 `optional`)
- Use `google.protobuf.Timestamp` for dates, not strings or int64

### Field naming
- `snake_case` for field names (protobuf convention, transcoded to `camelCase` in JSON)
- Descriptive names: `created_at` not `ts`, `user_id` not `uid`

### Anti-patterns
- Reusing field numbers after deletion (wire format collision)
- One giant "God message" used by multiple RPCs (couples everything)
- Primitive types for IDs (`int64 user_id`) when you should use `string` (allows UUID migration)
- `google.protobuf.Struct` / `Any` for everything (loses type safety)

---

## 3. Backward Compatibility

### Safe changes (non-breaking)
- Add new fields (with new field numbers)
- Add new RPC methods
- Add new enum values
- Rename fields (wire format uses numbers, not names)

### Breaking changes (require new version)
- Remove or reuse field numbers
- Change field types
- Change field semantics (same name, different meaning)
- Remove RPC methods
- Rename packages or services

### How to evolve
```protobuf
// v1 — original
message Order {
  string id = 1;
  string customer_id = 2;
  // field 3 was removed — NEVER reuse it
  reserved 3;
  reserved "old_field_name";
  string status = 4;
  string tracking_number = 5; // added later — safe
}
```

Use `reserved` for deleted fields to prevent accidental reuse.

---

## 4. Error Handling

### gRPC status codes

| Code | When |
|---|---|
| `OK` | Success |
| `INVALID_ARGUMENT` | Validation failure (bad request) |
| `NOT_FOUND` | Resource doesn't exist |
| `ALREADY_EXISTS` | Duplicate creation attempt |
| `PERMISSION_DENIED` | Authenticated but not authorized |
| `UNAUTHENTICATED` | No valid credentials |
| `RESOURCE_EXHAUSTED` | Rate limit exceeded |
| `FAILED_PRECONDITION` | State-based rejection (e.g., can't delete an active order) |
| `INTERNAL` | Unexpected server error |
| `UNAVAILABLE` | Service temporarily unavailable (client should retry) |
| `DEADLINE_EXCEEDED` | Timeout |

### Rich error details
Use `google.rpc.Status` with detail messages for structured errors:
```protobuf
import "google/rpc/error_details.proto";

// Attach field-level validation errors via BadRequest detail
```

### Anti-patterns
- Using `INTERNAL` for everything (clients can't distinguish errors)
- Using `UNKNOWN` when a more specific code exists
- Error messages exposing internal details (stack traces, SQL)
- Not using `UNAVAILABLE` for transient errors (clients won't know to retry)

---

## 5. Streaming

### Types

| Pattern | Use case |
|---|---|
| **Unary** | Simple request/response (most RPCs) |
| **Server streaming** | Server sends multiple messages to client (log tailing, real-time updates) |
| **Client streaming** | Client sends multiple messages (file upload, batch operations) |
| **Bidirectional** | Both sides send freely (chat, collaborative editing) |

### Principles
- Use unary by default — streaming adds complexity
- Server streaming for: live updates, large result sets, event feeds
- Set deadlines on all calls (including streams) — no infinite waits
- Handle stream cancellation gracefully (client disconnects)

### Anti-patterns
- Using streaming for simple request/response (over-engineering)
- No deadline/timeout on streams (resource leak if client disappears)
- Sending massive messages instead of streaming smaller chunks
- No backpressure handling (producer overwhelms consumer)

---

## 6. Pagination (List RPCs)

### Pattern
```protobuf
message ListOrdersRequest {
  int32 page_size = 1;
  string page_token = 2; // cursor, opaque to client
  string filter = 3;     // optional filtering
  string order_by = 4;   // optional sorting
}

message ListOrdersResponse {
  repeated Order orders = 1;
  string next_page_token = 2; // empty = no more pages
  int32 total_size = 3;       // optional total count
}
```

### Principles
- Cursor-based (`page_token`), not offset-based
- Token is opaque to the client (server encodes/decodes it)
- Empty `next_page_token` signals the last page
- Default `page_size` if client doesn't specify (capped to a max)

---

## 7. API Linting & Code Generation

### Tooling
| Tool | What it does |
|---|---|
| **buf** | Lint proto files, detect breaking changes, format, generate code |
| **protoc** | Official protobuf compiler (code generation) |
| **grpc-gateway** | Generate REST API from gRPC proto (HTTP transcoding) |
| **Evans** | gRPC CLI client for testing (like Postman for gRPC) |
| **grpcurl** | CLI tool for interacting with gRPC servers |
| **Buf Schema Registry** | Centralized proto management and dependency resolution |

### buf lint rules (recommended)
- `PACKAGE_VERSION_SUFFIX` — enforce version in package name
- `RPC_REQUEST_RESPONSE_UNIQUE` — each RPC has its own request/response
- `FIELD_LOWER_SNAKE_CASE` — consistent naming
- `ENUM_VALUE_PREFIX` — enum values prefixed with enum name
- `SERVICE_SUFFIX` — services end with `Service`
