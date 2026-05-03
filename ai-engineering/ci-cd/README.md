# AI Engineering CI/CD

CI/CD for AI applications. For general CI/CD practices (pipeline design, artifacts, deployment, security), see [`../../backend-engineering/ci-cd/`](../../backend-engineering/ci-cd/README.md).

AI CI/CD adds a new dimension: **model and prompt are deployable artifacts alongside code**. A model version change or prompt edit changes behavior without code change.

---

## 1. What's Different in AI CI/CD

| Aspect | Traditional CI/CD | AI CI/CD |
|---|---|---|
| **What you deploy** | Code + config | Code + config + prompt templates + model version |
| **What changes behavior** | Code | Code OR prompt OR model version OR retrieved data (RAG index) |
| **Testing** | Assert exact output | Evaluate quality on a spectrum (eval suite) |
| **Rollback** | Redeploy previous code version | Rollback code + prompt version + model version (which one caused the regression?) |
| **Build artifact** | Container image, binary | Container image + prompt template version + model reference + eval results |

---

## 2. CI/CT/CD Pipeline

```
Code Change → Lint → Unit Test → Build → Eval Suite → Deploy
Prompt Change → Eval Suite → Deploy (no build needed)
Model Change → Eval Suite → Deploy (no build needed)
RAG Index Change → Eval Suite → Monitor
```

### CI (Continuous Integration)
Same as backend: lint, unit test, build, security scan. Plus:
- **Prompt template validation**: is the template syntactically correct? Are variables resolved?
- **Eval suite on PR**: run evaluation dataset against changed code/prompt

### CT (Continuous Training) — if fine-tuning
```
New training data → Validate data quality → Fine-tune → Evaluate → Register model → Deploy
```
- Data validation (quality, PII check, format)
- Fine-tune with versioned dataset
- Evaluate fine-tuned model against baseline
- Register in model registry with metadata (dataset version, metrics, config)
- Deploy only if quality meets threshold

### CD (Continuous Deployment)
- Deploy code changes same as backend
- Prompt template changes: version and deploy independently of code
- Model version changes: deploy with eval gate
- RAG index changes: rebuild index, validate retrieval quality, deploy

---

## 3. Prompt Versioning

Prompts are configuration that changes behavior — version them like code.

### How

```
/prompts
  /summarize
    v1.md                    (original)
    v2.md                    (added examples)
    v3.md                    (restructured for Claude)
    current → v3.md          (symlink or config reference)
  /classify
    v1.md
    current → v1.md
```

Or in a prompt management platform (Langfuse, Humanloop, PromptLayer):
- Version history
- A/B testing
- Rollback
- Performance tracking per version

### Principles
- **Every prompt change goes through eval** — a "small prompt edit" can degrade quality dramatically
- **Prompts in version control** (git) or prompt management platform — not hardcoded in code
- **Rollback capability** — switch back to previous prompt version without code deploy
- **Track which prompt version produced which results** — observability links trace → prompt version

### Anti-patterns
- Prompts hardcoded as string literals in code (changes require full deploy)
- Prompt changes without running eval ("it's just a small edit")
- No version history (can't rollback, can't compare performance across versions)
- Multiple team members editing prompts in production without review

---

## 4. Model Registry

Track which models are available, which version is deployed, with what config.

### What to track per model

| Field | Example |
|---|---|
| **Model name** | `claude-sonnet-4-20250514` |
| **Provider** | Anthropic |
| **Purpose** | Main chat, summarization, classification |
| **Eval score** | 4.2/5 on eval dataset v3 (500 test cases) |
| **Config** | temperature: 0.3, max_tokens: 1024 |
| **Prompt version** | summarize/v3 |
| **Cost** | $0.003/1K input tokens, $0.015/1K output tokens |
| **Deployed to** | production since 2026-04-15 |

### Principles
- **Pin model versions explicitly** — not "claude-sonnet-4" but "claude-sonnet-4-20250514"
- **Eval before promoting** — model passes eval suite → promoted to staging → passes again → production
- **Fallback model configured** — primary model unavailable → route to fallback (different provider or smaller model)
- **Track cost per model** — same task on different models has wildly different costs

### For fine-tuned models (if applicable)
- Dataset version used for training
- Training config (learning rate, epochs, LoRA rank)
- Base model version
- Training metrics (loss curves)
- Eval results compared to base model

---

## 5. A/B Testing Models

Compare two model configurations with real traffic.

### What to A/B test

| Experiment | Variant A | Variant B |
|---|---|---|
| **Model version** | claude-sonnet-4-20250514 | claude-sonnet-4-20250601 |
| **Prompt version** | summarize/v2 | summarize/v3 |
| **Temperature** | 0.3 | 0.5 |
| **Model tier** | Opus (expensive, higher quality?) | Sonnet (cheaper, good enough?) |

### How to measure
- **Quality score** (AI-as-judge on both variants)
- **User satisfaction** (thumbs up/down, regeneration rate)
- **Latency** (is the new model faster/slower?)
- **Cost** (is the new model cheaper?)
- **Statistical significance** (is the difference real or noise?)

### Principles
- **Randomize at user level** (same user gets same variant for consistency), not per request
- **Sufficient sample size** before concluding (not "10 requests looked better")
- **Measure quality AND cost** — a model that's 5% better but 3x more expensive may not be worth it

### Shadow deployment
Run the new model in parallel on real traffic but DON'T show results to users. Compare outputs offline.
- Zero risk (users see old model)
- Real traffic (not synthetic)
- Expensive (double the LLM calls)
- Good for: major model changes, new providers, risky prompt rewrites

---

## 6. RAG Index Updates

The RAG knowledge base is a deployable artifact that changes system behavior.

### Pipeline
```
Source docs change → Re-index (chunk, embed, store) → Validate retrieval quality → Deploy index
```

### Principles
- **Version the index** — know which docs are in which version of the index
- **Eval retrieval quality after re-index** — did the new docs improve or degrade retrieval?
- **Monitor retrieval metrics continuously** — relevance scores, hit rate, "no results" rate
- **Incremental updates where possible** — don't rebuild the entire index for one new document

### Anti-patterns
- RAG index updated manually (someone runs a script, no versioning, no eval)
- No retrieval quality eval after index update (new docs pollute results)
- Full re-index on every document change (expensive, slow)
- No monitoring of retrieval quality over time (index degrades as docs get stale)

---

## Tooling

| Tool | What it does |
|---|---|
| **Langfuse** | Prompt versioning, eval tracking, traces |
| **Humanloop** | Prompt management, versioning, evaluation |
| **PromptLayer** | Prompt versioning and logging |
| **MLflow** | Model registry (originally ML, works for LLM fine-tuned models) |
| **Weights & Biases** | Experiment tracking, model registry |
| **promptfoo** | Eval in CI — run test cases, compare versions |

---

## References

- [Chip Huyen — AI Engineering, Ch. 10 (Architecture)](https://www.oreilly.com/library/view/ai-engineering/9781098166298/)
- [Langfuse — Prompt Management](https://langfuse.com/docs/prompts)
- [`../../backend-engineering/ci-cd/`](../../backend-engineering/ci-cd/README.md) — general CI/CD practices
