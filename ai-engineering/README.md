# AI Engineering Best Practices

Best practices for building applications with AI models (LLMs, multimodal). This is NOT about training models (that's ML Engineering) — it's about **using models as components** to build products.

Backend is the foundation — most engineering principles are shared. This guide references `backend-engineering/` for shared content and adds AI-specific topics.

---

## The Fundamental Shift

Traditional software is **deterministic**: same input → same output, every time. AI applications are **probabilistic**: same input → different output each time. This changes everything:

| Aspect | Traditional software | AI-powered software |
|---|---|---|
| **Testing** | Assert exact output | Evaluate quality on a spectrum |
| **Caching** | Key-value (exact match) | Semantic similarity (approximate match) |
| **Monitoring** | Error rate (binary: success/failure) | Quality score (continuous: good/mediocre/hallucination) |
| **Debugging** | Stack trace → root cause | "Why did it say that?" → context analysis |
| **Cost model** | Per request / per instance | Per token (input + output) |
| **Latency** | 50-200ms typical | 1-30 seconds typical |
| **Reliability** | 200 OK = success | 200 OK might contain hallucination |
| **Rollback** | Redeploy previous version | Model version change = behavior change without code change |

---

## Principle: Deterministic First

**Don't use AI when a deterministic solution works.** AI is expensive, slow, and non-deterministic. Use it only when the problem genuinely requires it.

### Don't use AI for this

| Task | ❌ LLM (overkill) | ✅ Deterministic |
|---|---|---|
| Validate email format | Prompt: "is this a valid email?" | Regex |
| Look up product by ID | Prompt: "find product X" | DB query |
| Convert date format | Prompt: "convert this date" | `datetime.strptime()` |
| Classify with clear rules | Prompt: "classify this" | `if/else`, lookup table, decision tree |
| Calculate taxes | Prompt: "calculate the tax" | Formula |
| Format a template | Prompt: "fill in this template" | String interpolation |
| Route by keyword | Prompt: "which category?" | Keyword matching, regex |

### The heuristic
- Can you write an `if/else` or regex that solves it? → Don't use AI.
- Is the input structured and the mapping known? → Don't use AI.
- Does it require understanding natural language, nuance, or generating text? → AI may be justified.

### When you DO use AI, reduce non-determinism

| Technique | How it reduces uncertainty |
|---|---|
| **Temperature 0** | Near-deterministic (always picks highest probability token) |
| **Structured outputs / schema enforcement** | Forces format — model can't invent fields or deviate from structure |
| **Constrained generation** | Limits options (classification with `accepted_values` — model picks from a list, not free-form) |
| **Few-shot examples** | Shows the exact pattern expected — reduces variability dramatically |
| **Validation layer post-model** | Verify output matches expectations, retry if not (max 2 retries) |
| **Deterministic fallback** | If model fails validation after N retries → fall back to rule-based default |
| **Seed parameter** | Some providers support `seed` for reproducible outputs (same seed + same input ≈ same output) |

### The spectrum
```
Pure deterministic (regex, rules) → AI-assisted (model + validation + fallback) → Pure AI (trust model output)
         ↑                                    ↑                                           ↑
    Prefer this                         Acceptable                              Only when necessary
```

Most production AI features should be in the MIDDLE — AI generates, deterministic code validates and constrains. Pure AI with no validation is rarely acceptable in production.

---

## Principle: Design for Confident Wrongness

LLMs are confidently wrong. They don't say "I'm not sure" — they present hallucinated information with the same tone as correct information. This is the #1 UX and trust problem.

### Design patterns for trust

| Pattern | How | When |
|---|---|---|
| **Source attribution** | Show WHERE the answer came from (RAG: link to source doc) | Factual answers, Q&A, search |
| **Confidence signals** | Show retrieval relevance score, or model's self-assessed confidence | When quality varies per query |
| **"AI-generated" labels** | Explicitly mark content as AI-generated | Always for user-facing content |
| **Verification prompts** | "This information may be incorrect. Please verify." | Critical decisions (medical, legal, financial) |
| **Human-in-the-loop** | AI drafts, human approves before action | High-stakes actions (send email, publish, delete) |
| **Show limitations** | "I don't have access to real-time data" / "I can only see documents from X" | When the system has known blind spots |

### Principles
- **Never present AI output as authoritative fact** without source or caveat
- **Users will stop verifying** — design so that over-reliance causes minimal harm
- **"I don't know" is a valid answer** — train/prompt the model to say "I don't have enough information" rather than fabricate
- **Critical paths need human verification** — AI assists, human decides

### Anti-patterns
- AI output with no indication it's AI-generated (user assumes it's human-vetted)
- No source attribution in RAG ("the answer is X" — where did that come from?)
- AI making decisions on high-stakes operations without human approval
- Presenting hallucinated information alongside real data in the same UI (indistinguishable)

---

## Solution Types (Spectrum of Autonomy)

| Level | Type | Who decides | Example |
|---|---|---|---|
| **1** | Single LLM call | Developer (hardcoded) | Summarize, translate, classify |
| **2** | RAG | Developer (pipeline fijo) | Q&A over documentation |
| **3** | Chain / Pipeline | Developer (secuencia fija) | Extract → classify → generate report |
| **4** | Tool-using LLM | Model chooses WHICH tool | "What's the weather?" → calls API |
| **5** | Agent | Model controls the FLOW | Claude Code, research agents |
| **6** | Multi-agent | Models coordinate | One researches, one writes, one reviews |

Most production value today is in levels 1-4. Agents (5-6) are powerful but harder to control, test, and predict.

---

## Shared with Backend (reference directly)

| Topic | Reference |
|---|---|
| **Data Privacy** | [`../backend-engineering/data-privacy/`](../backend-engineering/data-privacy/README.md) — EU AI Act, training data privacy, GDPR/CCPA |
| **Software Principles** | [`../backend-engineering/software-principles/`](../backend-engineering/software-principles/README.md) — SOLID, DRY, KISS — applies to AI application code |
| **IaC** | [`../backend-engineering/iac/`](../backend-engineering/iac/README.md) — GPU infrastructure, containers, K8s |
| **Data Design** | [`../backend-engineering/data-design/`](../backend-engineering/data-design/README.md) — vector DBs follow same patterns (connections, queries, lifecycle) |

---

## AI-Engineering-Specific Topics

| Folder | What it covers |
|---|---|
| [secure-coding/](secure-coding/README.md) | Prompt injection, jailbreaks, guardrails, data leakage, model supply chain |
| [observability/](observability/README.md) | LLM metrics (tokens, cost, latency, quality), hallucination detection, model drift |
| [testing/](testing/README.md) | Non-deterministic evaluation, AI-as-judge, adversarial testing, benchmarking |
| [ci-cd/](ci-cd/README.md) | CI/CT/CD, model registry, A/B testing models, shadow deployment |
| [configuration/](configuration/README.md) | Model versions, prompt templates as config, hyperparams, temperature/top_p |
| [contract-design/](contract-design/README.md) | Streaming responses, tool_use/function calling, structured outputs, token limits |
| [system-design/](system-design/README.md) | RAG, agents, prompt/context/memory patterns, fine-tuning, inference optimization, guardrails architecture |

---

## Mathematics for AI Engineers

You don't need to derive formulas or implement algorithms from scratch. But understanding what these concepts DO helps you make better engineering decisions.

### Linear Algebra (vectors and matrices)

| Concept | Where you use it (indirectly) | Why it matters |
|---|---|---|
| **Vectors** | Embeddings — text/images converted to vectors of numbers | Every RAG system converts text to vectors for similarity search |
| **Vector dimensions** | Embedding models produce vectors of N dimensions (768, 1536, 3072) | More dimensions = more nuance but more storage/compute cost |
| **Dot product / Cosine similarity** | Comparing how similar two embeddings are (0 = unrelated, 1 = identical) | You set similarity thresholds for retrieval — too low = noise, too high = miss relevant docs |
| **Matrix multiplication** | What happens inside the transformer (attention mechanism) | Why GPU matters — matrix ops are parallelizable. Why larger models are slower — more matrices. |
| **Dimensionality reduction** | Reducing vector size for storage/speed (PCA, t-SNE for visualization) | Visualizing embedding clusters, compressing vectors for cheaper storage |

**Practical impact**: when you choose an embedding model (OpenAI `text-embedding-3-small` vs `text-embedding-3-large`), you're choosing vector dimensions. When you set a similarity threshold in RAG (`cosine_similarity > 0.8`), you're using linear algebra.

### Statistics & Probability

| Concept | Where you use it | Why it matters |
|---|---|---|
| **Probability distributions** | Token generation — the model assigns probabilities to every possible next token | Temperature controls how "peaked" vs "flat" the distribution is |
| **Temperature** | Scales the probability distribution before sampling. Low (0.0) = deterministic (highest prob token). High (1.0+) = creative (flatter distribution). | You configure this. Too low = repetitive. Too high = nonsensical. |
| **Top-p (nucleus sampling)** | Only consider tokens whose cumulative probability ≥ p. Top-p=0.9 means ignore the bottom 10% least likely tokens. | Fine-tune randomness. Use with temperature. |
| **Top-k** | Only consider the k most likely tokens | Simpler version of top-p |
| **Perplexity** | How "surprised" the model is by the text — lower = more predictable | Used in evaluation — high perplexity on expected output = model struggling |
| **Statistical evaluation** | Mean, median, percentiles of quality scores across eval datasets | You evaluate model outputs — "average quality score of 4.2/5 across 500 test cases" |
| **Confidence intervals** | When comparing model A vs model B — is the difference statistically significant? | A/B testing models — "is the new prompt actually better, or is it noise?" |

**Practical impact**: when you set `temperature: 0.3` for a classification task or `temperature: 0.9` for creative writing, you're applying probability. When you evaluate "model A scores 4.1 vs model B scores 4.3" — is that a real improvement or noise? That's statistics.

### Calculus (gradients and optimization)

| Concept | Where you use it (indirectly) | Why it matters |
|---|---|---|
| **Gradients / Backpropagation** | Fine-tuning — adjusting model weights based on your training data | You don't compute gradients, but you configure learning rate, epochs, batch size — these control gradient behavior |
| **Loss function** | How the model measures "how wrong am I?" during fine-tuning | Different loss functions for different tasks. You choose them in fine-tuning config. |
| **Learning rate** | How big the gradient steps are during fine-tuning | Too high = unstable. Too low = slow. You configure this. |
| **Overfitting** | Model memorizes training data instead of learning patterns | You monitor training loss vs validation loss. Diverging = overfitting. |
| **Gradient descent** | The optimization algorithm that adjusts weights | Why fine-tuning is iterative (epochs), why batch size matters, why training takes time |

**Practical impact**: when you fine-tune via LoRA and set `learning_rate: 2e-5, epochs: 3, batch_size: 4` — you're controlling gradient descent. When training loss drops but eval quality doesn't improve — that's overfitting. You don't compute the math, but you read the signals.

### The Bottom Line

| Math area | AI Engineer needs to | AI Engineer does NOT need to |
|---|---|---|
| **Linear algebra** | Understand embeddings, similarity, dimensions | Implement matrix multiplication, eigenvalue decomposition |
| **Statistics** | Configure temperature/top_p, evaluate outputs, A/B test | Derive probability distributions, implement sampling algorithms |
| **Calculus** | Configure fine-tuning params, read training metrics | Implement backpropagation, derive loss functions |

You operate the machine, you don't build the machine. But understanding how it works makes you a better operator.

---

## Ecosystem

### LLM Providers
| Provider | Models | Key features (2026) |
|---|---|---|
| **Anthropic** | Claude Opus 4.6, Sonnet 4.6, Haiku 4.5 | Extended thinking, MCP, computer use, prompt caching, 200K-1M context |
| **OpenAI** | GPT-4o, GPT-4.1, o1, o3 (reasoning) | Structured outputs, batch API, reasoning models, vision/audio |
| **Google** | Gemini (Pro, Flash, Ultra) | Long context (1M+), multimodal native, grounding |
| **Open Source** | Llama (Meta), Mistral, Qwen (Alibaba), DeepSeek | Self-hostable, fine-tunable, no API dependency |

### SDKs & Frameworks
| Tool | What it does | Status (2026) |
|---|---|---|
| **Anthropic SDK + MCP** | Official Claude client + Model Context Protocol for tools | Preferred for Claude-based apps |
| **Claude Agent SDK** | Build agents with Claude (tool loops, extended thinking) | First-class agent support |
| **OpenAI SDK** | Official GPT/o-series client | Agents API, structured outputs |
| **LiteLLM** | Unified interface for 100+ LLM providers | Multi-provider abstraction |
| **LangGraph** | Structured agent workflows (stateful, graph-based) | Mature for complex agents |
| **LangChain** | Framework for chaining LLM calls, tools, memory | Widely adopted, can be heavyweight |
| **LlamaIndex** | Framework focused on RAG and data indexing | Strong RAG ecosystem |
| **Vercel AI SDK** | Streaming UI components for AI apps (React/Next.js) | Frontend-focused AI integration |

### Vector Databases
| Tool | Type |
|---|---|
| **pgvector** | PostgreSQL extension (use existing DB) |
| **Pinecone** | Managed, serverless |
| **Weaviate** | Open-source, self-hosted or cloud |
| **Qdrant** | Open-source, high performance |
| **Chroma** | Lightweight, developer-friendly |

### Evaluation
| Tool | What it does |
|---|---|
| **promptfoo** | CLI for evaluating prompts against test cases |
| **RAGAS** | RAG evaluation framework |
| **DeepEval** | LLM evaluation with metrics (hallucination, relevance, etc.) |
| **Braintrust** | Eval + logging + prompt management |

### Guardrails
| Tool | What it does |
|---|---|
| **Guardrails AI** | Input/output validation for LLMs |
| **NeMo Guardrails (NVIDIA)** | Programmable guardrails for LLM apps |
| **Rebuff** | Prompt injection detection |

### Observability
| Tool | What it does |
|---|---|
| **Langfuse** | Open-source LLM observability (traces, cost, quality) |
| **LangSmith** | LangChain's observability platform |
| **Helicone** | LLM proxy with logging, caching, rate limiting |
| **Weights & Biases** | Experiment tracking, eval |

### Inference
| Tool | What it does |
|---|---|
| **vLLM** | High-throughput LLM serving (PagedAttention) |
| **TGI (Text Generation Inference)** | HuggingFace's LLM serving |
| **Ollama** | Run open-source models locally |
| **llama.cpp** | CPU/GPU inference for GGUF models |

### Fine-tuning
| Tool | What it does |
|---|---|
| **OpenAI Fine-tuning API** | Fine-tune GPT models via API |
| **Unsloth** | Fast LoRA/QLoRA fine-tuning (2x faster, 50% less memory) |
| **Axolotl** | Configurable fine-tuning framework |
| **LoRA / QLoRA** | Parameter-efficient fine-tuning methods |

---

## References

- [Chip Huyen — AI Engineering (2025)](https://www.oreilly.com/library/view/ai-engineering/9781098166298/)
- [Anthropic Documentation](https://docs.anthropic.com/)
- [OpenAI Documentation](https://platform.openai.com/docs/)
- [Simon Willison's Blog](https://simonwillison.net/) — practical AI engineering insights
- [Langfuse Documentation](https://langfuse.com/docs)
