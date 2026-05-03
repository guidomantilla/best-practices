# AI Engineering Observability

Monitoring AI applications. For service-level observability (tracing, RED/USE, structured logging), see [`../../backend-engineering/observability/`](../../backend-engineering/observability/README.md).

AI observability answers different questions: not just "is it fast?" but **"is it correct? Is it costing too much? Is the quality degrading?"**

---

## 1. LLM-Specific Metrics

| Metric | What it measures | Why it matters |
|---|---|---|
| **Token usage** (input + output per request) | How much context and response | Cost driver #1. Input tokens (prompt + context) often > output tokens. |
| **Cost per request** | Token usage × model pricing | A poorly designed prompt can cost 10x more than a good one |
| **Latency** (time to first token + total) | How fast the model responds | TTFT matters for streaming UX. Total latency for batch. 1-30s is normal, not ms. |
| **Throughput** (requests/min to LLM) | How many concurrent LLM calls | Rate limits per provider, capacity planning |
| **Quality score** | How good is the output (human eval, AI-as-judge, automated metrics) | The most important metric — and the hardest to measure |
| **Hallucination rate** | % of responses with claims not grounded in provided context | Trust metric — high hallucination = users can't trust the system |
| **Guardrail trigger rate** | % of requests blocked by input/output guardrails | Security signal — injection attempts, policy violations |
| **Retrieval relevance** (RAG) | How relevant are the retrieved documents to the query | Low relevance = model answers from general knowledge, not your data |
| **Tool call success rate** | % of tool calls that succeed vs fail/timeout | Agent reliability |
| **Fallback rate** | % of requests that fell back to secondary model or default response | Primary model availability issues |

---

## 2. Cost Monitoring

AI applications have a fundamentally different cost model — **per token, not per instance**.

### What to track

| Metric | Granularity | Alert when |
|---|---|---|
| **Daily/hourly cost** | Per model, per feature | Exceeds budget (sudden spike = abuse or bug) |
| **Cost per user action** | Per feature (summarize, search, chat) | Rising without traffic increase (prompt got bigger, model changed) |
| **Input vs output token ratio** | Per request type | Input >> output suggests over-stuffed context (paying for context the model doesn't use) |
| **Cost by model** | Breakdown by model used | Expensive model used where cheap model would suffice |

### Cost optimization patterns

| Pattern | What it does | Savings |
|---|---|---|
| **Model routing** | Use cheap model for simple tasks, expensive for complex | 50-80% (most queries are simple) |
| **Prompt caching** | Cache static prefix (system prompt, docs) — provider serves from cache | 50-90% on cached tokens (Anthropic, OpenAI) |
| **Prompt optimization** | Shorter system prompt, fewer examples, compressed context | 20-50% per request |
| **Semantic caching** | Cache responses for semantically similar queries | Varies — high for repetitive queries (FAQ, support) |
| **Context window management** | Only include relevant context, not everything | 30-60% (less input tokens) |
| **Batch processing** | Batch API for non-real-time workloads (Anthropic Batch, OpenAI Batch) | 50% cost reduction |

### Unbounded consumption (OWASP LLM #10)

LLM APIs can be exploited for cost — intentionally or accidentally:
- **Agentic loops**: agent loops 50 times, each step costs tokens → $50+ per user request
- **Large context abuse**: user sends 100K token input → expensive even with one response
- **Rate limit exhaustion**: one user exhausts shared API quota → all users affected (60% of LLM production errors are rate limit errors — Datadog, 2026)

### Mitigation

| Control | What it does |
|---|---|
| **Per-user token budget** | Max tokens per user per hour/day |
| **Per-request cost limit** | Abort if single request exceeds $X |
| **Per-agent-run budget** | Max tokens/cost per agent invocation |
| **Rate limiting** | RPM + TPM limits per user, per API key |
| **Circuit breaker on cost** | If daily cost exceeds threshold → degrade to cheaper model or disable |
| **Input length limits** | Max input tokens per request |

### Anti-patterns
- No cost tracking (surprise $10K bill at end of month)
- Sending entire documents as context when a summary would suffice
- Using GPT-4/Claude Opus for every request including trivial ones
- No rate limiting per user (one user generates $500 in API costs)
- No agent cost circuit breaker (runaway agent burns budget silently)
- No input size limit (user sends 200K token prompt as a DoS vector)

---

## 3. Quality Monitoring

The hardest part — "is the output good?" is not binary.

### Approaches

| Approach | How | When |
|---|---|---|
| **Automated metrics** | BLEU, ROUGE, BERTScore — compare output to reference | When you have reference answers (translation, summarization) |
| **AI-as-judge** | Use a strong model to evaluate a weaker model's output | When no reference exists — judge rates quality 1-5 |
| **Human evaluation** | Humans rate outputs on a sample | Ground truth — expensive, not scalable, but necessary |
| **User feedback** | Thumbs up/down, ratings, regenerate clicks | Implicit signal from real usage — most scalable |
| **Factual grounding** | Check if output claims are supported by provided context | RAG — did it answer from docs or hallucinate? |

### What to monitor continuously

| Signal | What it indicates |
|---|---|
| **Quality score trending down** | Model degradation, context quality dropping, prompt regression |
| **Hallucination rate increasing** | RAG retrieval quality dropping, or model version change |
| **User regeneration rate** | Users clicking "regenerate" = unsatisfied with output |
| **Thumbs down rate** | Direct negative feedback |
| **Average conversation length** | Getting longer = users struggling to get what they need |

### Anti-patterns
- No quality monitoring (assume model output is always good)
- Only monitoring latency and error rate (model is fast and returns 200 but output is garbage)
- No human evaluation baseline (can't calibrate automated metrics without human ground truth)
- Quality checked only at launch, not continuously (model drift is real)

---

## 4. Tracing for AI Applications

Distributed tracing adapted for LLM applications — tracking the full journey of a request through model calls, RAG retrieval, tool use, and guardrails.

### What a trace looks like

```
User query
  ├── Input guardrails (2ms)
  ├── Embedding generation (50ms)
  ├── Vector search (30ms) → 5 docs retrieved
  ├── Context assembly (5ms) → 2000 tokens
  ├── LLM call (3500ms)
  │   ├── Model: claude-sonnet-4-20250514
  │   ├── Input tokens: 2400
  │   ├── Output tokens: 350
  │   ├── Cost: $0.012
  │   └── Temperature: 0.3
  ├── Tool call: get_user_data (200ms)
  ├── LLM call #2 with tool result (2100ms)
  ├── Output guardrails (15ms)
  └── Response to user (total: 5902ms)
```

### What to capture per LLM call
- Model name and version
- Input/output token count (+ thinking tokens if extended thinking)
- Cache hit/miss (prompt caching — affects cost significantly)
- Cost (actual, accounting for cache hits)
- Latency (TTFT + total)
- Temperature and other params
- Prompt template used (version/ID)
- Retrieved context (for RAG — what docs were used)
- Tool calls made and results
- Modality (text only, or images/audio included — affects token count and cost)
- Reasoning quality (for extended thinking — was the reasoning sound?)

### Tooling

| Tool | What it does |
|---|---|
| **Langfuse** | Open-source LLM tracing, cost tracking, prompt management, evaluation |
| **LangSmith** | LangChain's tracing and evaluation platform |
| **Helicone** | LLM proxy with automatic logging, caching, cost tracking |
| **Braintrust** | Tracing, evaluation, prompt versioning |
| **OpenTelemetry + custom spans** | Use existing OTel infrastructure, add LLM-specific spans |

### Principles
- **Trace every LLM call** — not just the HTTP request. The LLM call IS the important span.
- **Include cost and tokens in the trace** — not just latency
- **Link traces to quality scores** — "this trace scored 2/5 in evaluation" → investigate why
- **Trace multi-step agents fully** — an agent may make 5-10 LLM calls per user request. Trace all of them.

---

## 5. Model Drift

The model's behavior changes over time — even without code changes.

### Causes

| Cause | Example |
|---|---|
| **Provider updates model** | OpenAI updates GPT-4o → behavior changes subtly |
| **Context drift** | RAG index grows/changes → different docs retrieved → different answers |
| **User behavior drift** | Users ask different questions than what you evaluated on |
| **Prompt template changes** | Someone edited the system prompt → unintended quality change |

### Detection
- Run evaluation suite regularly (weekly, after model updates)
- Monitor quality scores over time — trend, not point-in-time
- Compare output distributions (are responses getting shorter? More cautious? Different tone?)
- A/B test model versions before switching

### Anti-patterns
- No regular evaluation (drift happens silently for months)
- Switching model versions without running eval suite
- Monitoring only operational metrics (latency, errors) not quality metrics

---

## References

- [Langfuse Documentation](https://langfuse.com/docs)
- [Helicone Documentation](https://docs.helicone.ai/)
- [Anthropic — Monitoring and Evaluation](https://docs.anthropic.com/en/docs/build-with-claude/develop-tests)
- [`../../backend-engineering/observability/`](../../backend-engineering/observability/README.md) — service-level observability
