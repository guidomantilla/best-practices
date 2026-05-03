# AI Engineering Configuration

Configuration for AI applications. For general configuration practices (sources, precedence, secrets, feature flags, validation), see [`../../backend-engineering/configuration/`](../../backend-engineering/configuration/README.md).

AI applications have **configuration that directly changes model behavior** — unlike traditional software where config changes operational parameters.

---

## 1. Model Configuration

| Parameter | What it controls | Impact |
|---|---|---|
| **Model version** | Which model to use (`claude-sonnet-4-20250514`) | Quality, cost, latency, behavior — EVERYTHING changes |
| **Temperature** | Randomness of output (0.0 = deterministic, 1.0+ = creative) | Too low = repetitive. Too high = nonsensical. Task-dependent. |
| **Top-p (nucleus sampling)** | Only consider tokens with cumulative probability ≥ p | Fine-tunes randomness alongside temperature |
| **Top-k** | Only consider the k most likely tokens | Simpler alternative to top-p |
| **Max tokens** | Maximum output length | Cost control + prevents runaway responses |
| **Stop sequences** | Tokens that signal the model to stop generating | Prevents over-generation, formats output |
| **System prompt** | Instructions and persona for the model | Behavior, personality, constraints |

### Guidelines

| Task type | Temperature | Max tokens | Notes |
|---|---|---|---|
| Classification / extraction | 0.0 - 0.1 | Low (50-200) | Deterministic, structured |
| Summarization | 0.2 - 0.4 | Medium (200-500) | Focused but some variation OK |
| Q&A (factual) | 0.1 - 0.3 | Medium (200-1000) | Accuracy over creativity |
| Creative writing | 0.7 - 1.0 | High (1000+) | Variety is the goal |
| Code generation | 0.0 - 0.2 | High (2000+) | Correct code > creative code |
| Chat / conversation | 0.5 - 0.7 | Medium (500-1000) | Natural but not wild |

### Principles
- **Pin model version explicitly** — `claude-sonnet-4-20250514`, not `claude-sonnet-4`. Version changes = behavior changes.
- **Temperature is task-dependent** — no global "best" temperature
- **Max tokens is a cost guard** — set it. Don't let the model generate 10K tokens when you need 200.
- **Document WHY each parameter is set to its value** — future you won't remember

### Anti-patterns
- Using provider default temperature for everything (default is often 1.0 — too high for factual tasks)
- No max_tokens set (model generates 4K tokens for a one-sentence question — cost waste)
- Unpinned model version (provider updates model, behavior changes, nobody knows why quality dropped)
- Temperature tuned by "feel" without evaluation (run eval at different temperatures, pick the one that scores best)

---

## 2. Prompt Templates as Configuration

Prompts should be externalized — not hardcoded strings in application code.

### Why
- Prompt changes don't require code deploys
- Prompts can be versioned independently (see [`../ci-cd/`](../ci-cd/README.md) §3)
- Non-engineers (product, domain experts) can edit prompts
- A/B testing different prompts is trivial when they're config

### Patterns

```python
# BAD — hardcoded
response = client.messages.create(
    system="You are a helpful assistant that summarizes documents...",
    ...
)

# GOOD — externalized
prompt = load_prompt("summarize", version="v3")  # from file, DB, or prompt platform
response = client.messages.create(
    system=prompt.render(context=context),
    ...
)
```

### Storage options

| Option | When |
|---|---|
| **Markdown/text files in git** | Simple, version-controlled, code-reviewed. Good starting point. |
| **Prompt management platform** (Langfuse, Humanloop) | When you need versioning, A/B testing, analytics, non-engineer editing |
| **Database** | When prompts are per-tenant or user-customizable |
| **Config service** | When you need runtime changes without restart |

### Principles
- **Prompts are NOT code** — treat them as configuration / content
- **Variables in templates, not string concatenation** — use `{context}`, `{user_query}` placeholders
- **System prompt separate from user template** — system prompt changes rarely, user template changes per request type
- **Version every change** — see [`../ci-cd/`](../ci-cd/README.md) §3

---

## 3. Context Window Management

Managing what goes into the model's limited context window.

### The budget
```
Context window (200K - 1M+ tokens in 2026)
  = System prompt (~500-2000 tokens)
  + Conversation history (~variable)
  + Retrieved documents (RAG) (~variable)
  + Tool results (~variable)
  + User message (~variable)
  + Room for output (max_tokens)
```

### Strategies

| Strategy | How | When |
|---|---|---|
| **Truncation** | Cut oldest messages from conversation | Simple chat — oldest messages least relevant |
| **Summarization** | Summarize old messages, keep summary in context | Long conversations where early context matters |
| **Sliding window** | Keep last N messages, drop the rest | Fixed-window memory |
| **Selective retrieval** | Only include relevant parts of conversation history | Agent with many tool calls — most intermediate steps aren't needed |
| **Token budgeting** | Allocate token budget per section (system: 1K, history: 4K, RAG: 8K, output: 2K) | Predictable context management |

### Principles
- **Always leave room for output** — if your context fills the window, the model can't respond
- **RAG context competes with conversation history** — more docs = less history, and vice versa
- **Quality over quantity** — 3 highly relevant docs > 10 marginally relevant docs
- **Monitor token usage** — track how much of the context window is used per request (see [`../observability/`](../observability/README.md))

### Anti-patterns
- Stuffing the entire document into context when a relevant excerpt would suffice
- No token budget (context overflows, request fails with unhelpful error)
- Including all conversation history (100 messages of history, only last 3 are relevant)
- No summarization strategy for long conversations (context grows until it hits the limit)

---

## 4. Feature Flags for AI

Feature flags for AI applications — control model behavior, routing, and rollout.

| Flag type | Example | Purpose |
|---|---|---|
| **Model routing** | `use_opus_for_complex: true` | Route complex queries to expensive model, simple to cheap |
| **Feature rollout** | `enable_tool_use: 50%` | Gradually enable new capability |
| **Prompt version** | `prompt_version: v3` | Switch prompt versions without deploy |
| **Guardrail toggle** | `strict_guardrails: true` | Tighten/loosen guardrails without deploy |
| **Fallback toggle** | `enable_fallback_model: true` | Enable/disable fallback to secondary provider |
| **RAG toggle** | `use_rag: true` | Enable/disable retrieval (debug: does RAG help or hurt?) |

### Principles
- **Model routing as flag** — most impactful AI-specific flag. Route by query complexity, user tier, or task type.
- **Gradual rollout for prompt changes** — 10% → 50% → 100%, monitoring quality at each step
- **Kill switch for AI features** — if the model starts hallucinating badly, disable the feature instantly via flag
- Same flag hygiene as backend (see [`../../backend-engineering/configuration/`](../../backend-engineering/configuration/README.md) §6 — lifecycle, cleanup, ownership)

---

## 5. Multi-Provider Configuration

Don't depend on one LLM provider.

### Pattern
```yaml
providers:
  primary:
    name: anthropic
    model: claude-sonnet-4-20250514
    api_key: ${ANTHROPIC_API_KEY}
    timeout: 30s
  fallback:
    name: openai
    model: gpt-4o
    api_key: ${OPENAI_API_KEY}
    timeout: 30s
  cheap:
    name: anthropic
    model: claude-haiku-4-5-20251001
    api_key: ${ANTHROPIC_API_KEY}
    timeout: 15s

routing:
  complex_tasks: primary
  simple_tasks: cheap
  on_primary_failure: fallback
```

### Principles
- **Prompts may need adaptation per provider** — Claude and GPT respond differently to the same prompt
- **Eval per provider** — run your eval suite against each provider's model
- **Unified interface** (LiteLLM or custom abstraction) — application code doesn't know which provider is behind the call
- **Monitor per provider** — latency, error rate, cost, quality separately

### Anti-patterns
- Single provider, no fallback (provider outage = product down)
- Same prompt for all providers without testing (quality varies significantly)
- Switching providers without running eval ("GPT-4o and Claude are basically the same" — they're not)

---

## References

- [Anthropic — Prompt Engineering Guide](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering)
- [OpenAI — API Reference (parameters)](https://platform.openai.com/docs/api-reference/)
- [`../../backend-engineering/configuration/`](../../backend-engineering/configuration/README.md) — general configuration practices
