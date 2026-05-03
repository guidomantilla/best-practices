# Well-Architected: AI Workloads

How the five well-architected pillars manifest when your system includes AI/LLM components. The pillars don't change — but what "well-architected" MEANS changes when the system is probabilistic.

---

## Operational Excellence — AI

| Traditional | With AI |
|---|---|
| Deploy code → behavior changes | Deploy code OR change prompt OR change model version OR update RAG index → behavior changes |
| Rollback = redeploy previous code | Rollback = which artifact caused the regression? Code? Prompt? Model? Data? |
| CI/CD pipeline | CI/CT/CD pipeline (continuous training for fine-tuned models) |
| Logs + metrics + traces | + token usage, cost/request, quality scores, prompt versions in traces |

**Key additions:**
- Version prompts alongside code
- Track model versions in deployment metadata
- Run eval suite before and after any change (code, prompt, model, RAG index)
- Monitor cost as an operational metric (not just infra — per-token cost is variable)

---

## Security — AI

| Traditional | With AI |
|---|---|
| Input validation (SQL injection, XSS) | + Prompt injection, jailbreaking |
| Data protection (encrypt, access control) | + PII leakage via model output, training data extraction |
| Supply chain (dependencies) | + Model supply chain (poisoned models, provider dependency) |
| Auth per request | + Tool use permissions (model can call APIs — least privilege per tool) |

**Key additions:**
- Guardrails (input + output) as a security layer
- System prompt is NOT a security boundary (will be extracted)
- Assume prompt injection will succeed → limit blast radius (sandboxed tools, confirmation for destructive actions)
- PII scrubbing before sending to external LLM API

---

## Reliability — AI

| Traditional | With AI |
|---|---|
| 200 OK = success | 200 OK might contain hallucination (invisible failure) |
| Retry on 500/timeout | Retry on 500/timeout + retry on quality failure? (non-deterministic — retry might produce better or worse output) |
| Circuit breaker on dependency failure | + Fallback to cheaper/different model when primary fails |
| Health check: can process requests | + Quality check: is the model producing good output? (drift detection) |

**Key additions:**
- Multi-provider fallback (Anthropic down → OpenAI, or vice versa)
- Quality monitoring as reliability metric (hallucination rate IS an availability concern — the feature "works" but provides wrong information)
- Model version pinning (don't let provider updates break your app)
- Graceful degradation: if AI component fails → return cached response, default answer, or "I don't know" (not a 500)

---

## Performance — AI

| Traditional | With AI |
|---|---|
| p99 < 200ms | p99 of 5-15 seconds is NORMAL for LLM calls |
| Cache by exact key | Semantic cache (approximate meaning match) |
| Scale compute horizontally | Rate limited by provider API (not your compute) |
| Optimize queries, indexes | Optimize prompt length, context window, model routing |

**Key additions:**
- TTFT (Time to First Token) is the key UX metric — streaming makes 5s feel like 0.5s
- Model routing: cheap model for simple tasks, expensive for complex (biggest cost/performance optimization)
- Semantic caching for repetitive queries
- Token budget management (shorter prompts = faster + cheaper)
- Batch API for non-real-time workloads

---

## Cost — AI

| Traditional | With AI |
|---|---|
| Pay per instance/hour | Pay per token (input + output) |
| Cost scales with compute | Cost scales with USAGE (more users = more tokens = more cost, linearly) |
| Right-size instances | Right-size model (don't use Opus when Haiku suffices) |
| Monitor infra spend | Monitor token spend per user, per feature, per model |

**Key additions:**
- **Model routing is the #1 cost optimization** — route 80% of queries to cheap model (Haiku/$0.25 per 1M tokens) instead of expensive model (Opus/$15 per 1M tokens)
- **Prompt optimization** — shorter system prompt, fewer examples, compressed context = fewer input tokens = less cost
- **Per-user cost tracking** — one power user can generate 100x the cost of a normal user
- **Cost per feature** — summarization costs $X/month, search costs $Y/month. Know where money goes.
- **Set cost alerts** — daily/weekly budget per feature, alert at 80%

---

## References

- [`../ai-engineering/`](../ai-engineering/README.md) — full AI engineering best practices
- [`./operational-excellence.md`](operational-excellence.md) — general operational excellence
- [`./security.md`](security.md) — general security
- [`./reliability.md`](reliability.md) — general reliability
- [`./performance.md`](performance.md) — general performance
- [`./cost-optimization.md`](cost-optimization.md) — general cost optimization
