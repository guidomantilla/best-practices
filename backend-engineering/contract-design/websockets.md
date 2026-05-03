# WebSocket Contract Design

Best practices for designing WebSocket-based real-time communication.

---

## 1. When to Use WebSockets

### Good fit
- Real-time bidirectional communication (chat, collaborative editing)
- Server-pushed updates (live dashboards, notifications, stock prices)
- High-frequency updates where HTTP polling is wasteful
- Gaming, real-time collaboration

### Not a good fit
- Request/response patterns (use REST/gRPC)
- One-time data fetch (use REST)
- Server-to-client only, low frequency (use Server-Sent Events — simpler)
- Fire-and-forget events (use async messaging)

### Consider SSE (Server-Sent Events) first
If you only need server → client (no bidirectional), SSE is simpler: HTTP-based, auto-reconnect, works through proxies without special config.

---

## 2. Message Format

### Principles
- Use structured messages (JSON or protobuf), not raw strings
- Every message has a `type` field — clients route/handle based on type
- Include a `request_id` or `correlation_id` for request/response patterns over WS
- Timestamp every message

### Standard envelope
```json
{
  "type": "order.updated",
  "payload": {
    "order_id": "abc-123",
    "status": "shipped"
  },
  "timestamp": "2026-05-01T10:30:00Z",
  "request_id": "req-456"
}
```

### Anti-patterns
- Untyped messages (client has to guess what it received)
- Different shapes for different message types (no consistent envelope)
- No timestamp (can't order events, can't debug timing issues)
- Raw strings instead of structured data

---

## 3. Connection Lifecycle

### Phases
```
Connect → Authenticate → Subscribe → Exchange messages → Disconnect
```

### Principles
- **Authenticate on connect** (or immediately after) — don't allow unauthenticated message exchange
- **Subscribe to topics/channels** after auth — not all clients need all data
- **Graceful disconnect**: notify the server when closing intentionally
- **Connection timeout**: close idle connections after N minutes (save resources)

### Anti-patterns
- No authentication (any client can connect and receive data)
- Auth only at connect time, never re-validated (token expires but connection stays)
- Broadcasting everything to all clients (no topic/channel filtering)
- No idle timeout (connections accumulate, server resources exhausted)

---

## 4. Heartbeats & Keepalive

### Why
- Detect dead connections (client crashed, network dropped)
- Keep connection alive through load balancers/proxies that have idle timeouts
- Give clients a signal that the server is still there

### Pattern
```
Client sends: {"type": "ping"}
Server responds: {"type": "pong"}
```
Or use WebSocket protocol-level ping/pong frames.

### Principles
- Heartbeat interval: 15-30 seconds (balance between detection speed and overhead)
- If N consecutive pings get no pong → consider connection dead, close and clean up
- Client-initiated pings are simpler (server doesn't need to track per-connection timers)

### Anti-patterns
- No heartbeat (dead connections stay open for hours, wasting resources)
- Heartbeat every 1 second (excessive overhead)
- Server-only pings without client-side dead connection detection

---

## 5. Reconnection

### Principles
- Clients MUST implement reconnection — connections will drop
- **Exponential backoff** with jitter: don't hammer the server after a disconnect
- **Resume from last received event**: use sequence numbers or timestamps to request missed messages
- **Re-subscribe after reconnect**: subscriptions are lost on disconnect

### Pattern
```
Disconnect detected
  → Wait: min(base * 2^attempt, max_delay) + random_jitter
  → Reconnect
  → Re-authenticate
  → Re-subscribe
  → Request missed messages (from last_sequence_id)
```

### Anti-patterns
- No reconnection logic (connection drops, user sees nothing forever)
- Immediate reconnect without backoff (DDoS your own server when it's recovering)
- No message recovery (events lost during disconnection)
- Fixed retry interval (all clients reconnect at the same time = thundering herd)

---

## 6. Scaling & State

### Challenges
- WebSocket connections are stateful (unlike REST) — tied to a specific server instance
- Scaling horizontally means connection state must be shared or routed

### Patterns

| Pattern | How | When |
|---|---|---|
| **Sticky sessions** | Load balancer routes same client to same server | Simple, but limits scaling and failover |
| **Pub/Sub backbone** | Servers share events via Redis Pub/Sub, NATS, or Kafka | Multiple server instances, messages reach all connected clients |
| **Connection registry** | Central registry maps user/topic to server instance | Targeted delivery, complex to manage |

### Anti-patterns
- In-memory only state (lost on server restart, can't scale horizontally)
- No consideration for horizontal scaling (works with 1 server, breaks with 2)
- Broadcasting through the app server (instead of dedicated pub/sub layer)

---

## 7. Security

### Principles
- Authenticate before or immediately after connection (token in query param on connect, or first message)
- Validate all incoming messages (same as HTTP input validation)
- Rate limit messages per connection (prevent spam/abuse)
- Authorize per-channel/topic (user can only subscribe to their own data)
- Use WSS (WebSocket Secure — TLS) always, never plain WS

### Anti-patterns
- Auth token in URL query param without TLS (visible in logs)
- No message-level validation (trust client messages blindly)
- No rate limiting (one client floods the server with messages)
- No per-topic authorization (client subscribes to other users' channels)

---

## Tooling

| Tool | What it does |
|---|---|
| **Socket.IO** | WebSocket abstraction with fallbacks, rooms, namespaces (JS) |
| **ws** | Lightweight WebSocket library for Node.js |
| **gorilla/websocket** | WebSocket for Go |
| **tokio-tungstenite** | WebSocket for Rust (async) |
| **AsyncAPI** | Define WebSocket/event-driven contracts as spec |
| **Postman / Insomnia** | WebSocket testing (connect, send, receive) |
| **websocat** | CLI WebSocket client for testing |
