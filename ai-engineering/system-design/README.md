# AI Engineering System Design

Architecture patterns for AI applications. For backend system design (microservices, Clean Architecture, integration patterns), see [`../../backend-engineering/system-design/`](../../backend-engineering/system-design/README.md).

Organized by **solution type** (from simple to complex), then cross-cutting concerns.

---

## 1. Single LLM Call Patterns

The simplest AI integration — one prompt, one response.

### When
- Classification, extraction, summarization, translation
- Input is self-contained (no external data needed)
- Output is predictable in structure

### Patterns

| Pattern | How | Example |
|---|---|---|
| **Zero-shot** | Just the task description, no examples | "Classify this email as spam/not-spam" |
| **Few-shot** | Task description + examples in the prompt | "Here are 3 examples of spam/not-spam. Now classify this:" |
| **Chain-of-thought** | Ask the model to reason step by step before answering | "Think through this step by step, then give your answer" |
| **Structured extraction** | Extract data into a defined schema from unstructured text | "Extract {name, email, company} from this business card image" |

### Principles
- **Start here** — most AI features don't need RAG or agents. A single well-crafted prompt solves many problems.
- **Structured output for extraction** — use schema enforcement, not free-form text parsing
- **Few-shot > zero-shot** when quality matters — examples are the most reliable way to steer output
- **Chain-of-thought for reasoning** — let the model "think" before answering for complex decisions

---

## 2. RAG (Retrieval-Augmented Generation)

Ground the model's response in YOUR data — not its training data.

### Architecture
```
User query
  → Embed query (embedding model)
  → Search vector DB (similarity search)
  → Retrieve top-K documents
  → Assemble context (system prompt + retrieved docs + user query)
  → LLM generates answer grounded in retrieved docs
  → Return response (with sources)
```

### Components

| Component | What it does | Options |
|---|---|---|
| **Document ingestion** | Chunk documents, generate embeddings, store in vector DB | LangChain, LlamaIndex, custom |
| **Chunking** | Split documents into retrieval units | Fixed-size (512 tokens), semantic (paragraph), recursive, by headers |
| **Embedding model** | Convert text to vectors | OpenAI text-embedding-3, Cohere embed, open-source (BGE, E5) |
| **Vector DB** | Store and search embeddings | Pinecone, Weaviate, Qdrant, Chroma, pgvector |
| **Retrieval** | Find relevant chunks for a query | Similarity search, hybrid (vector + keyword), reranking |
| **Reranking** | Re-score retrieved results for relevance | Cohere Rerank, cross-encoder models |

### Chunking strategies

| Strategy | How | Best for |
|---|---|---|
| **Fixed-size** | Split every N tokens with overlap | Simple, works for most text |
| **Semantic** | Split by paragraph/section boundaries | Structured documents (articles, docs) |
| **Recursive** | Split by headers → paragraphs → sentences (hierarchical) | Complex documents with structure |
| **Parent-child** | Index small chunks, retrieve parent (larger context) | When small chunks find the needle, but the model needs surrounding context |

### Retrieval strategies

| Strategy | How | When |
|---|---|---|
| **Dense (vector)** | Cosine similarity on embeddings | Semantic search ("meaning" match) |
| **Sparse (keyword)** | BM25 / TF-IDF | Exact match, acronyms, codes, names |
| **Hybrid** | Combine dense + sparse scores | Best of both — handles meaning AND exact terms |
| **Reranking** | Retrieve N candidates, rerank to top-K | When initial retrieval has noise — reranking improves precision |

### Principles
- **Chunking quality determines RAG quality** — garbage in, garbage out. Spend time on chunking strategy.
- **Hybrid retrieval > pure vector** — vector search misses exact terms, keyword search misses semantics. Combine.
- **Reranking is cheap improvement** — retrieve 20, rerank to top 5. Better precision for small extra cost/latency.
- **Include sources in response** — user should see WHERE the answer came from (trust + verifiability)
- **Evaluate retrieval separately from generation** — retrieval is correct? Generation is faithful to retrieved docs? Two different quality dimensions.

### RAG data staleness (operational problem)

The RAG index is only as good as the documents in it. Stale, duplicate, or inconsistent documents degrade answer quality silently.

| Problem | What happens | Mitigation |
|---|---|---|
| **Stale documents** | Docs updated in source but not re-indexed → model answers with outdated info | Re-index on doc change (event-driven) or on schedule. Monitor index freshness. |
| **Duplicate documents** | Same content indexed multiple times → retrieval returns duplicates, wastes context | Deduplication at ingestion. Content hash check before indexing. |
| **Contradictory documents** | Old version and new version both in index → model gets conflicting info | Version control on docs. Remove old versions when new ones are indexed. |
| **Low-quality documents** | Poorly written, incomplete, or irrelevant docs pollute retrieval | Content quality filtering at ingestion. Human review of source docs. |

Monitor: retrieval relevance scores over time. If average relevance drops, the index quality is degrading.

### Anti-patterns
- One giant chunk per document (too much context, model ignores most of it)
- Only vector search (fails on exact terms — "what's policy ABC-123?" → cosine similarity doesn't help)
- No reranking (top 10 results include 5 irrelevant ones — model confused)
- No source attribution (user can't verify, can't trust)
- RAG for data that changes every minute (index is always stale — consider real-time retrieval instead)
- No index freshness monitoring (docs get stale, answers degrade, nobody notices for months)
- No deduplication (same doc indexed 3 times = 3 of 5 retrieval slots wasted on the same content)

---

## 3. Chains and Pipelines

Multiple LLM calls in sequence, each step feeding the next.

### Patterns

| Pattern | How | Example |
|---|---|---|
| **Sequential chain** | Step 1 output → Step 2 input → Step 3 input | Extract entities → classify → generate summary |
| **Map-reduce** | Split input into chunks, process each (map), combine results (reduce) | Summarize a 100-page document (summarize each section, then summarize the summaries) |
| **Router** | Classify input, route to specialized prompt/chain | "Is this a complaint or a question?" → complaint chain vs question chain |
| **Refine** | Process sequentially, refining output with each new piece of context | Iterative summarization — start with first section, refine with each subsequent section |
| **Verify and retry** | LLM generates → validator checks → retry if invalid | Generate JSON → validate schema → if invalid, retry with error message |

### Principles
- **Each step should be independently testable and evaluable**
- **Fail fast** — if step 1 fails, don't run step 2-5
- **Log intermediate outputs** — debugging a 5-step chain requires seeing what each step produced
- **Consider cost** — each LLM call costs money. 5-step chain = 5x cost vs single call.

### Anti-patterns
- Long chains for simple tasks (one well-crafted prompt may replace a 3-step chain)
- No error handling between steps (step 3 gets garbage from step 2, produces garbage)
- No logging of intermediate steps (can't debug)

---

## 4. Tool Use and Function Calling

The model decides WHICH tool to call and generates the arguments.

### Architecture
```
User query
  → LLM (with tool definitions)
  → Model returns: "I need to call get_weather(location='Bogotá')"
  → Application validates args, executes tool
  → Application sends result back to model
  → Model generates final response incorporating tool result
```

### Design principles
- **Tool descriptions are the API** — the model reads them to decide when to use each tool. Clear, specific descriptions.
- **Input schemas are strict** — the model generates arguments. Validate them. The model WILL hallucinate invalid arguments sometimes.
- **Separate read and write tools** — read tools are safe to auto-execute. Write/delete tools need confirmation.
- **Return structured results** — the model processes tool output better when it's structured (JSON) vs free text
- **Limit the tool set** — 5-10 tools is ideal. 50 tools = model confused about which to use.

For the full contract design for tool use, see [`../contract-design/`](../contract-design/README.md) §2.

---

## 5. Agents

The model controls the FLOW — decides what to do, when, in what order, and when to stop.

### Core loop
```
while not done:
    observation = perceive(environment)    # user message, tool results, context
    thought = reason(observation)          # model decides next action
    action = act(thought)                  # execute tool, respond, or ask for input
    done = evaluate(action)               # goal achieved? max steps? error?
```

### Agent patterns

| Pattern | How | When |
|---|---|---|
| **ReAct** (Reason + Act) | Model alternates: Thought → Action → Observation → Thought → ... | General agent pattern — most common |
| **Plan then execute** | Model creates full plan upfront, then executes steps sequentially | When the task is well-defined and plannable |
| **Iterative refinement** | Model produces output, evaluates it, refines, repeats | Writing, code generation, research |
| **Tool selection** | Model picks from available tools based on the task | Extension of function calling with autonomous selection |

### Agent memory

| Memory type | What it stores | How |
|---|---|---|
| **Conversation memory** | Current conversation history | Messages array (managed by context window strategies) |
| **Working memory** | Scratchpad for current task (intermediate results, plan state) | System prompt or tool results |
| **Long-term memory** | Knowledge across conversations (user preferences, past interactions) | External storage (DB, vector DB), retrieved when relevant |

### Common failure modes (production data)

| Failure | What happens | Detection | Mitigation |
|---|---|---|---|
| **Infinite loop** | Agent calls the same tool with same args repeatedly, never advances | Detect tool+args repetition (same call 3+ times) | Deduplication check, force different action after N repeats |
| **Death spiral** | Agent retries with minimal changes (adds one word to search, retries) | Detect low-variation retries | Require meaningful change between retries, or abort |
| **Token explosion** | Agent loop consumes thousands of tokens per step — one user request costs $5+ | Token budget per agent run, alert on anomalous cost | Hard token budget limit, circuit breaker on cost |
| **Planning failure** | Agent makes incorrect plan, executes all steps, result is useless | Difficult — plan looks reasonable but is wrong | Plan validation step (separate model critiques the plan before execution) |
| **Ignored stop signals** | Agent ignores termination criteria, keeps going | Step counter, timeout | Hard limits (max steps + max time + max tokens — any one triggers stop) |
| **Confident wrong action** | Agent performs destructive action based on misunderstanding | Audit log, confirmation gates | Human-in-the-loop for write/delete, undo capability |

### Principles
- **Set THREE limits**: max steps (10-20) + max time (5 min) + max tokens (50K). Any one triggers stop.
- **Detect loops**: track tool+args history. Same call 3 times = loop. Force different action or abort.
- **Token budget per run**: set a hard dollar/token limit per agent invocation. Alert and abort if exceeded.
- **Require confirmation for destructive actions** — agent can read freely, but write/delete needs human approval
- **Log every step** — agent decisions must be traceable (what did it think? what did it do? what did it observe?)
- **Evaluate agent trajectories, not just final output** — the PATH matters, not just the destination
- **Fail gracefully with context** — if the agent gets stuck, give up with a clear message explaining what it tried and why it stopped

### Anti-patterns
- Only max step limit (no time or token limit — agent does 10 expensive steps = $50)
- No loop detection (agent calls `search("best restaurants")` 15 times)
- Agent with unrestricted tool access (can delete databases, send emails, call external APIs without bounds)
- No logging of agent reasoning (can't debug why it made a bad decision)
- Complex agent for a simple task (a 5-step agent for something a single prompt solves)
- No cost tracking per agent run (one user triggers $100 in API costs, nobody notices until the bill)

---

## 6. Multi-Agent Systems

Multiple agents collaborating, each with specialized roles.

### Patterns

| Pattern | How | When |
|---|---|---|
| **Supervisor** | One agent delegates tasks to specialized agents | Complex task with distinct sub-tasks (research, write, review) |
| **Sequential handoff** | Agent A completes, passes to Agent B | Pipeline where each agent has different expertise |
| **Debate / critique** | Multiple agents discuss/critique each other's output | When you want diverse perspectives or higher quality through verification |
| **Swarm** | Agents hand off to each other based on the query | Customer service routing (billing agent, technical agent, sales agent) |

### Production reality

Multi-agent systems have **41-86.7% failure rates** in production (Augment Code, 2026). Common failures:
- **Role confusion**: agents misinterpret their role, duplicate each other's work
- **Coordination failure**: agents skip verification steps, or repeat completed work
- **Inconsistent outputs**: same input produces wildly different multi-agent results across runs
- **Cost multiplication**: 3 agents × 5 steps × tokens per step = 15 LLM calls per user request

### Principles
- **Start with single agent, add multi-agent only if needed** — given the failure rates, multi-agent must be justified
- **Clear role separation with explicit protocols** — not just "you're the researcher" but exact input/output format per agent
- **Structured handoff** — agents pass structured data (JSON), not free-form text (reduces misinterpretation)
- **Verification agent** — dedicated agent that validates other agents' output before returning to user
- **Cost budget per multi-agent run** — set a hard limit. 15 LLM calls × $0.01 each = $0.15 per user request. Is that acceptable?
- **Fallback to single agent** — if multi-agent fails or exceeds budget, fall back to simpler approach

### Anti-patterns
- Multi-agent for a task one agent can handle (over-engineering with 41-86% failure rate)
- Agents with overlapping roles (both try to answer → inconsistent, duplicated work)
- No cost awareness (user query triggers 20 LLM calls across agents)
- Free-form handoff between agents (agent A writes prose, agent B misinterprets it)
- No verification step (agents produce garbage, nobody checks before returning to user)

---

## 7. Fine-Tuning (AI Engineer Level)

Adapting a model to your specific task using your data — via API/tooling, not custom training loops.

### When to fine-tune

| Signal | Fine-tune? |
|---|---|
| Prompt engineering + few-shot gets 90%+ quality | No — prompt is enough |
| Need consistent style/format across thousands of outputs | Yes — fine-tuning teaches style better than examples |
| Need to reduce cost (shorter prompts after fine-tuning) | Yes — fine-tuned model needs fewer examples in prompt |
| Need to teach domain-specific knowledge | Maybe — RAG is often better for knowledge, fine-tuning for behavior |
| Need to improve latency (shorter prompts = fewer input tokens) | Yes — fine-tuned model with no few-shot examples is faster |

### Process
```
1. Collect examples (input/output pairs)
2. Clean and validate data (quality > quantity)
3. Format for fine-tuning API (JSONL with messages)
4. Fine-tune via API (OpenAI, Anthropic) or tooling (Unsloth, Axolotl for LoRA)
5. Evaluate against baseline (is it actually better?)
6. Deploy with version tracking
```

### Methods

| Method | What it changes | Cost | When |
|---|---|---|---|
| **API fine-tuning** (OpenAI, etc.) | Full model weights (managed by provider) | $$, simple | Provider-supported tasks, easiest path |
| **LoRA** | Small adapter matrices (few % of total params) | $, requires GPU | Custom models, open-source, cost-efficient |
| **QLoRA** | LoRA + quantized base model | $, less GPU RAM | Same as LoRA with less hardware |

### Principles
- **Fine-tuning teaches BEHAVIOR, not KNOWLEDGE** — for knowledge, use RAG. Fine-tuning teaches format, style, tone, reasoning patterns.
- **Quality > quantity** — 100 high-quality examples often beats 10,000 mediocre ones
- **Always compare to baseline** — run eval before and after. Fine-tuning can make things worse.
- **Version your datasets** — which data produced which model. Reproducibility matters.
- **Start with prompting** — exhaust prompt engineering before fine-tuning. It's cheaper and faster to iterate.

### Anti-patterns
- Fine-tuning to "teach" the model facts (use RAG — facts change, model weights don't update easily)
- Training on low-quality data ("garbage in, garbage out" — amplified by fine-tuning)
- No evaluation against baseline ("we fine-tuned, it must be better" — not necessarily)
- Fine-tuning when few-shot prompting works (unnecessary cost and complexity)

---

## 8. Inference Optimization

Making LLM calls faster and cheaper.

### Strategies

| Strategy | What it does | Savings |
|---|---|---|
| **Model routing** | Use cheap model for simple tasks, expensive for complex | 50-80% cost (most queries are simple) |
| **Semantic caching** | Cache responses for semantically similar queries (not exact match) | Varies — high for FAQ/support (many similar questions) |
| **Prompt caching** | Cache static prefix (system prompt, docs), pay reduced rate on cache hits | 50-90% on cached tokens (see §14) |
| **Prompt compression** | Shorter prompts, fewer examples, compressed context | 20-50% cost per request |
| **Batch API** | Non-real-time requests in batch (Anthropic Batch API, OpenAI Batch API) | 50% cost reduction, 24h turnaround |
| **Self-hosted models** | Run open-source models on your own infra | Variable — cheaper at scale, more ops burden |
| **Quantization** | Reduce model precision (fp16 → int8 → int4) for self-hosted | 2-4x faster, some quality loss |
| **Speculative decoding** | Small model drafts, large model verifies (faster overall) | 2-3x faster for self-hosted |

### Semantic caching
Unlike traditional caching (exact key match), semantic caching matches by MEANING:
```
Cache hit: "What's the return policy?" ≈ "How do I return an item?" (cosine similarity > 0.95)
```

Considerations:
- Threshold tuning — too low = wrong cache hits, too high = no hits
- Cache invalidation — when the underlying data changes
- Per-user context — same question from different users might have different answers (personalization)

### Model routing
```
User query → Classify complexity (cheap model or rule-based)
  → Simple → Haiku/GPT-4o-mini (fast, cheap)
  → Complex → Opus/GPT-4o (slower, expensive, higher quality)
```

### Principles
- **Route before you scale** — model routing saves more than adding GPUs
- **Semantic caching for repetitive workloads** — support, FAQ, onboarding questions
- **Batch what doesn't need real-time** — report generation, batch classification, data enrichment
- **Self-host only if you have ops maturity** — see [`../../well-architected/cost-optimization.md`](../../well-architected/cost-optimization.md)

---

## 9. Guardrails Architecture

The system that wraps around the model to ensure safety and quality.

### Architecture
```
User input
  → [Input Guardrails]
  │   ├── Injection detection
  │   ├── PII scrubbing
  │   ├── Topic filtering
  │   ├── Token budget check
  │   └── Rate limiting
  │
  → [Model Call]
  │
  → [Output Guardrails]
  │   ├── Hallucination check (grounded in context?)
  │   ├── PII detection (model generated PII?)
  │   ├── Content safety (toxic, harmful?)
  │   ├── Format validation (valid JSON? correct schema?)
  │   └── Factual grounding check (for RAG)
  │
  → Response to user
```

### Principles
- **Guardrails are separate from the model** — don't rely on the model's safety training alone
- **Fail closed** — if guardrails can't evaluate (timeout), block — don't pass through
- **Input AND output** — guard both sides
- **Lightweight guardrails** — add minimal latency. Use fast classifiers, regex, schemas — not another LLM call for every guard.
- **Log all blocks** — security signal + UX improvement opportunity

For detailed security practices, see [`../secure-coding/`](../secure-coding/README.md).

---

## 10. MCP (Model Context Protocol)

Anthropic's open standard for connecting LLMs to external tools and data sources. Replaces ad-hoc tool integration with a standardized protocol.

### What MCP provides
```
LLM Application (MCP Client)
  ↔ MCP Protocol (standardized JSON-RPC)
    ↔ MCP Server (filesystem)
    ↔ MCP Server (PostgreSQL)
    ↔ MCP Server (GitHub)
    ↔ MCP Server (web search)
    ↔ MCP Server (custom internal API)
```

### Why MCP matters
- **Standardized**: one protocol for all tool integrations — no custom adapter per tool
- **Reusable**: MCP servers are shared across applications (community ecosystem)
- **Secure**: protocol-level permissions, sandboxing, approval flows
- **Composable**: add/remove MCP servers without changing application code

### MCP capabilities

| Capability | What it provides |
|---|---|
| **Tools** | Functions the model can call (search, query, create, update) |
| **Resources** | Data the model can read (files, DB rows, API responses) |
| **Prompts** | Pre-built prompt templates the server exposes |
| **Sampling** | Server can request LLM completions (model-in-the-loop) |

### When to use MCP
- Any tool integration in a Claude-based application
- Building reusable tool servers for multiple projects
- When you want the community ecosystem of pre-built integrations

### When NOT to use MCP
- Simple single-tool integration (direct function calling may be simpler)
- Non-Anthropic models (MCP is Anthropic-originated, adoption by others is growing but not universal yet)

### Principles
- **Prefer MCP servers over custom tool implementations** — reusable, standardized, community-maintained
- **Scope permissions per server** — filesystem MCP server only accesses project directory, not entire disk
- **Audit MCP server code** — community servers are code you run locally. Review before trusting.

---

## 11. Extended Thinking / Reasoning Models

Models with internal reasoning traces — they "think" before answering. Changes prompting, evaluation, and cost.

### How it works
```
Traditional: Prompt → Answer (model figures it out in one pass)
Extended thinking: Prompt → [Thinking tokens — internal reasoning] → Answer
```

The thinking tokens are visible (in some APIs) and billed. The model reasons step-by-step internally before producing the final answer.

### When to use

| Use | Extended thinking | Standard |
|---|---|---|
| Complex reasoning, math, logic | ✅ better accuracy | May get it wrong |
| Multi-step planning (agents) | ✅ better plan quality | Plans may be shallow |
| Simple extraction/classification | ❌ overkill — slower, costlier | ✅ sufficient |
| Creative writing | Depends — thinking may over-constrain | ✅ usually fine |
| Code generation with complex requirements | ✅ better architecture decisions | May miss edge cases |

### Cost implications
- Thinking tokens are ADDITIONAL cost — model produces N thinking tokens + M answer tokens
- For simple tasks, thinking adds cost without adding quality
- For complex tasks, thinking reduces retries and downstream errors (net savings)

### Evaluation implications
- Must evaluate REASONING quality, not just final answer
- A correct answer with wrong reasoning is fragile (will fail on similar but different inputs)
- Eval datasets should include reasoning assessment criteria

### Prompting differences
- Don't over-constrain with chain-of-thought instructions — the model already does it
- Provide clear criteria for what a good answer looks like (the model's thinking will try to meet it)
- For deterministic tasks, thinking may add unnecessary variation — use standard mode

### Anti-patterns
- Using extended thinking for simple lookups (paying for reasoning you don't need)
- Ignoring thinking tokens in cost tracking (they can be 2-5x the answer tokens)
- Not evaluating reasoning traces (correct answer, wrong reasoning = future bug)

---

## 12. Computer Use / Automation

The model can control a computer — mouse, keyboard, screenshots — to interact with existing applications.

### Architecture
```
Agent loop:
  1. Take screenshot → send to model (vision)
  2. Model analyzes screen, decides action (click, type, scroll)
  3. Execute action on computer
  4. Take new screenshot → repeat
  5. Goal achieved → stop
```

### When to use
- Automate existing web applications that don't have APIs
- UI testing with AI (model verifies visual state, not just DOM)
- Multi-step workflows across multiple applications (model navigates between apps)
- Legacy system integration (no API, only UI)

### When NOT to use
- API exists — always prefer API over computer use (faster, cheaper, more reliable)
- Simple data entry — script it, don't screenshot-and-click it
- High-frequency operations — computer use is slow (screenshot per action)

### Cost considerations
- Screenshots are expensive in tokens (image tokens)
- Each action requires a round-trip: screenshot → model → action → screenshot
- An agent that clicks 20 times = 20 vision API calls

### Security
- Model controls a computer — restrict what it can access (sandboxed environment)
- Don't let it access production systems without approval
- Log every action (screenshot + action for audit trail)

### Anti-patterns
- Computer use when an API exists (10x slower, 100x more expensive)
- No sandboxing (model navigates to arbitrary URLs, enters credentials)
- No action logging (can't audit what the model did)

---

## 13. Multimodal as First-Class

Vision, audio, and text are equally standard input modalities. Not special features — core capabilities.

### Modalities

| Modality | Input as | Cost | Use cases |
|---|---|---|---|
| **Text** | Token string | Base rate | Everything traditional |
| **Vision (images)** | Base64 or URL → tokens | Higher per token (image size dependent) | Document extraction, UI analysis, diagram understanding, product photos |
| **Vision (PDF)** | Pages → images → tokens | Higher (per page) | Contract analysis, form processing, report extraction |
| **Audio** | Transcribed to text (or native audio input) | Varies | Voice interfaces, meeting analysis, call transcription |

### Architectural implications
- **Token budgeting must account for images** — one high-res image can be 1000+ tokens
- **Caching** — images don't benefit from prompt caching the same way text does
- **Latency** — processing images is slower than text
- **Eval datasets** — must include multimodal test cases (image + expected extraction)
- **Security** — adversarial images (text embedded in image to manipulate model)

### Principles
- **Right modality for the task** — don't OCR → text → LLM when you can send the image directly
- **Optimize image size** — resize before sending (smaller image = fewer tokens = less cost, often same quality)
- **Include multimodal cases in eval** — if your app handles images, test with images

---

## 14. Prompt Caching

Reuse cached prompt context across requests — massive cost reduction for repeated prefixes.

### How it works
```
Request 1: [System prompt (2K tokens)] + [User query] → full price for all tokens
Request 2: [Same system prompt (2K tokens)] + [Different query] → system prompt served from cache (90% cheaper)
```

### When it helps most

| Scenario | Cache benefit |
|---|---|
| Long system prompt reused across all requests | High — system prompt cached, only user query varies |
| RAG with same document set queried repeatedly | High — document context cached |
| Multi-turn conversation (growing context) | Medium — previous turns cached, only new turn added |
| Unique prompts per request | None — nothing to cache |

### Configuration
- Anthropic: `cache_control: {"type": "ephemeral"}` on cacheable content blocks
- OpenAI: automatic for identical prefixes
- Cache TTL: typically 5 minutes minimum (varies by provider)

### Principles
- **Structure prompts for cacheability** — put static content (system prompt, examples, docs) first, dynamic content (user query) last
- **Monitor cache hit rate** — low hit rate = prompt structure prevents caching
- **Combine with prompt optimization** — shorter cached prefix = cheaper even with cache miss

### Anti-patterns
- Dynamic content at the beginning of the prompt (breaks cache — prefix must be identical)
- Not monitoring cache hit rate (paying full price thinking cache is working)
- Ignoring prompt caching in cost estimates (actual cost can be 50-90% less than calculated)

---

## 15. Context Window Strategy (2026)

Context windows have grown from 4K (2023) to 200K-1M+ tokens (2026). This changes RAG strategy fundamentally.

### The question: do I still need RAG?

| Scenario | RAG? | Why |
|---|---|---|
| Knowledge base < 200K tokens | Maybe not — fits in context | Direct context inclusion is simpler, no retrieval errors |
| Knowledge base > 1M tokens | Yes — can't fit everything | Need selective retrieval |
| Knowledge changes frequently | Yes — RAG index updates, context doesn't | Re-embedding a doc is cheaper than changing the prompt |
| Need source attribution | Yes — RAG tracks which doc answered | Full context inclusion loses source granularity |
| Cost-sensitive | Yes — including 200K tokens in every request is expensive | RAG retrieves only relevant chunks (fewer tokens) |
| Latency-sensitive | Yes — processing 200K tokens is slow | Smaller context = faster response |

### The trade-off
```
Large context (no RAG):     Simple architecture, no retrieval errors, but expensive and slow
RAG (selective retrieval):  Complex architecture, retrieval errors possible, but cheap and fast
Hybrid:                     Large context for important docs + RAG for the rest
```

### Context quality degradation (Lost in the Middle / Context Rot)

More context ≠ better responses. Research shows:

- **Lost in the middle**: models remember information at the START and END of the context window but miss information buried in the MIDDLE. Positional bias is real.
- **Context rot**: model performance degrades predictably as context size grows — more severe on complex tasks (Stanford, 2023; confirmed in 2025 studies).
- **Smaller needles are harder**: a short relevant passage (5 lines) in a large context (100K tokens) is much harder to find than a long relevant passage (500 lines). The smaller the signal, the more noise hurts.

### Implications for architecture

| Strategy | How it mitigates quality degradation |
|---|---|
| **RAG (selective retrieval)** | Only relevant chunks in context — no filler, no "lost in the middle" |
| **Put critical info at start and end** | If using full context, structure so the most important data is at the beginning and the question at the end |
| **Reranking** | Retrieve many, rank by relevance, include only top results — higher signal-to-noise |
| **Summarize before including** | Long doc → summary in context (loses detail but avoids context rot) |
| **Evaluate at different context sizes** | Test quality with 10K, 50K, 200K context — find the degradation point |

### Principles
- **"Fits in context" doesn't mean "should be in context"** — cost, latency, AND quality degrade with more tokens
- **More context can make answers WORSE** — context rot is real. Measure quality at different context sizes.
- **RAG is still relevant** — even with 1M tokens, selective retrieval gives higher signal-to-noise than dumping everything
- **Prompt caching changes the cost math** — but doesn't fix quality degradation. Cached or not, the model still struggles with information in the middle.
- **Evaluate both approaches** — run your eval suite with RAG vs full-context. Let quality + cost + latency decide, not dogma.

---

## References

- [Chip Huyen — AI Engineering (2025)](https://www.oreilly.com/library/view/ai-engineering/9781098166298/)
- [Anthropic — Building with Claude](https://docs.anthropic.com/en/docs/build-with-claude)
- [Anthropic — Agents](https://docs.anthropic.com/en/docs/build-with-claude/agentic)
- [Anthropic — MCP](https://docs.anthropic.com/en/docs/agents-and-tools/mcp)
- [Anthropic — Extended Thinking](https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking)
- [Anthropic — Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Anthropic — Computer Use](https://docs.anthropic.com/en/docs/build-with-claude/computer-use)
- [LangChain — RAG](https://python.langchain.com/docs/tutorials/rag/)
- [LlamaIndex Documentation](https://docs.llamaindex.ai/)
- [`../../backend-engineering/system-design/`](../../backend-engineering/system-design/README.md) — backend system design
