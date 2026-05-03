# AI Engineering Contract Design

How to design APIs that serve AI capabilities. For general API contract design (REST, gRPC, GraphQL), see [`../../backend-engineering/contract-design/`](../../backend-engineering/contract-design/README.md).

AI APIs have unique characteristics: **streaming responses, tool/function calling, structured outputs, token-based limits, and non-deterministic results**.

---

## 1. Streaming Responses

LLM responses take 1-30 seconds. Without streaming, the user stares at a spinner. With streaming, they see tokens appear in real-time.

### How it works
```
Client sends request
  → Server starts LLM call
  → Server streams tokens as they arrive (SSE or WebSocket)
  → Client renders tokens incrementally
  → Stream ends with [DONE] signal
```

### Protocol options

| Protocol | How | When |
|---|---|---|
| **Server-Sent Events (SSE)** | HTTP response with `text/event-stream`, server pushes chunks | Most common for LLM APIs (OpenAI, Anthropic use this) |
| **WebSocket** | Bidirectional, persistent connection | Multi-turn chat where client sends mid-stream, or real-time collaboration |
| **HTTP chunked transfer** | Standard HTTP with chunked encoding | Simpler clients that don't need event parsing |

### What to stream

| Data | Stream it? | Why |
|---|---|---|
| **Text tokens** | Yes — always | UX: user sees response forming |
| **Tool calls** | Partially — stream the decision, execute after | User sees "I'm going to search for..." before the search runs |
| **Metadata** (tokens, cost) | After stream ends | Don't mix metadata with content during stream |
| **Errors** | Immediately | Don't wait for full response to report an error |

### Principles
- **Always offer a streaming endpoint** for user-facing AI features (non-streaming for batch/internal is fine)
- **Time to First Token (TTFT)** is the key UX metric — user perceives response as fast if first token arrives in < 500ms
- **Handle stream interruption** — client disconnects, network drops. Clean up server-side resources.
- **Include stop reason at end of stream** — `end_turn`, `max_tokens`, `tool_use` — client needs to know why it stopped

### Anti-patterns
- No streaming on user-facing chat (user waits 10 seconds staring at a spinner)
- Streaming without backpressure handling (slow client, server buffers entire response in memory)
- No TTFT metric (can't tell if the first token is slow)
- Error at token 500 of 1000 — client already rendered half the response, now what?

---

## 2. Tool Use / Function Calling

The model decides to call a function, the application executes it, returns the result.

### Contract structure
```json
// Define available tools
{
  "tools": [
    {
      "name": "get_weather",
      "description": "Get current weather for a location",
      "input_schema": {
        "type": "object",
        "properties": {
          "location": { "type": "string", "description": "City name" }
        },
        "required": ["location"]
      }
    }
  ]
}

// Model response (tool use)
{
  "stop_reason": "tool_use",
  "content": [
    {
      "type": "tool_use",
      "name": "get_weather",
      "input": { "location": "Bogotá" }
    }
  ]
}

// Application executes tool, sends result back
{
  "role": "user",
  "content": [
    {
      "type": "tool_result",
      "tool_use_id": "...",
      "content": "Bogotá: 18°C, partly cloudy"
    }
  ]
}
```

### Design principles for tools
- **Clear, descriptive names and descriptions** — the model uses these to decide WHEN to call the tool
- **Strict input schema** — validate model-generated arguments before executing (the model can hallucinate invalid args)
- **Minimal tool set** — fewer tools = model makes better decisions. Don't expose 50 tools.
- **Idempotent where possible** — model may call the same tool twice (retry, loop)
- **Read vs write tools** — separate clearly. Write tools should require confirmation for destructive actions.
- **Error responses** — return structured errors so the model can recover ("location not found" → model asks user to clarify)
- **MCP (Model Context Protocol)** — for Claude-based apps, prefer MCP servers over ad-hoc tool implementations. Standardized, reusable, community ecosystem. See system-design §10.

### Anti-patterns
- Vague tool descriptions ("does stuff with data") — model won't know when to use it
- No input validation (model sends `{"location": 42}` — crashes your function)
- Tool with side effects called without user confirmation (model deletes a record)
- Returning raw internal errors to the model (stack traces in tool results)

---

## 3. Structured Outputs

Force the model to respond in a specific format (JSON, schema-compliant). In 2026, **native schema enforcement is the standard**, not a workaround.

### Approaches (prefer native — top of list)

| Approach | How | Reliability | Status (2026) |
|---|---|---|---|
| **Native schema enforcement** | Provide JSON schema via API, model is constrained to produce valid output | Guaranteed | **Default — use this** |
| **tool_use pattern** (Anthropic) | Define a "tool" with input schema, model "calls" it with structured data | Guaranteed | Standard for Claude |
| **structured outputs** (OpenAI) | `response_format: { type: "json_schema", json_schema: {...} }` | Guaranteed | Standard for GPT |
| **JSON mode** | API flag for valid JSON (no specific schema) | Medium — valid JSON, wrong shape possible | Fallback only |
| **Prompt instruction** | "Respond in JSON with fields: ..." | Low — model may not comply | **Legacy — avoid** |

### Principles
- **Native schema enforcement is the default** — every major provider supports it. Prompt-based JSON is legacy.
- **Define the schema explicitly** — not "return JSON" but the exact fields, types, and constraints
- **Schema enforcement makes assertions deterministic** — you CAN assert on structure (always valid), even if content varies
- **Separate structured extraction from generation** — if you need both free text AND structured data, use two calls or tool_use pattern

### Anti-patterns
- Parsing model output with regex (fragile — one extra newline and it breaks)
- "Return JSON" in the prompt without validation (model adds markdown, comments, extra text)
- No retry on parse failure (one failed parse = user sees error)

---

## 4. Rate Limits and Token Budgets

LLM APIs have unique rate limiting — per token, not just per request.

### Rate limit types

| Limit | Unit | Example |
|---|---|---|
| **Requests per minute (RPM)** | API calls | 60 RPM for Tier 1 |
| **Tokens per minute (TPM)** | Input + output tokens | 100K TPM |
| **Tokens per day (TPD)** | Daily token budget | 1M TPD |
| **Concurrent requests** | Simultaneous connections | 5 concurrent |

### Handling rate limits

| Strategy | How |
|---|---|
| **Retry with backoff** | 429 → wait (Retry-After header), retry |
| **Queue and throttle** | Queue requests, process at rate below limit |
| **Model routing** | Route to fallback provider when primary is rate-limited |
| **Token budgeting per user** | Cap tokens per user per hour/day (prevent one user from exhausting shared quota) |
| **Request batching** | Combine small requests into batch calls (OpenAI Batch API) |

### Principles
- **Monitor token usage against limits** — alert at 80% of limit
- **Per-user budgets** — one user shouldn't be able to exhaust the organization's token quota
- **Graceful degradation** — when rate-limited, fall back to cheaper model or cached response, not error

### Anti-patterns
- No retry logic on 429 (request fails permanently)
- No per-user limits (one user generates $500 in API costs)
- Hard error on rate limit (user sees "service unavailable" instead of degraded response)

---

## 5. Conversation API Design

If your application is conversational, design the conversation contract.

### Conversation state

| Approach | How | Trade-off |
|---|---|---|
| **Stateless (client sends full history)** | Client sends all messages each request | Simple server, client manages state, context grows |
| **Stateful (server stores history)** | Server stores conversation, client sends conversation_id | Server manages context window, client is simple |
| **Hybrid** | Server stores, client can override/append | Most flexible, most complex |

### Message format
```json
{
  "conversation_id": "conv-123",
  "messages": [
    { "role": "system", "content": "..." },
    { "role": "user", "content": "..." },
    { "role": "assistant", "content": "..." },
    { "role": "user", "content": "What about..." }
  ],
  "model": "claude-sonnet-4-20250514",
  "stream": true,
  "max_tokens": 1024
}
```

### Principles
- **Conversation ID for stateful** — client can resume, server can load history
- **Server-side context management** — server decides what stays in context (truncation, summarization), not client
- **Return token usage per response** — client knows how much of the budget is consumed
- **Support conversation forking** — user wants to "go back" and try a different path

---

## References

- [Anthropic API Reference — Messages](https://docs.anthropic.com/en/api/messages)
- [Anthropic — Tool Use](https://docs.anthropic.com/en/docs/build-with-claude/tool-use)
- [OpenAI API Reference — Chat Completions](https://platform.openai.com/docs/api-reference/chat)
- [`../../backend-engineering/contract-design/`](../../backend-engineering/contract-design/README.md) — general contract design
