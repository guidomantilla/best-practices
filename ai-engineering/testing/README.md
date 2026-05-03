# AI Engineering Testing

Testing AI applications. For general testing practices (test pyramid, unit, integration), see [`../../backend-engineering/testing/`](../../backend-engineering/testing/README.md).

AI testing is fundamentally different: **there is no binary pass/fail**. The same prompt can produce different outputs each time, and "correct" is a spectrum.

---

## 1. The AI Testing Pyramid

```
         / Human Eval  \          Expensive, slow, ground truth
        /--------------\
       / AI-as-Judge    \        Scalable, automated quality scoring
      /------------------\
     / Assertion Tests    \      Deterministic checks on structured output
    /----------------------\
   / Unit Tests (logic)     \    Traditional — test the code, not the model
  /--------------------------\
```

| Level | What it tests | Deterministic? | Speed |
|---|---|---|---|
| **Unit** | Python/JS code logic (parsers, formatters, context builders) | Yes | ms |
| **Assertion** | Structured output validity (JSON schema, field presence, format) | Yes | seconds |
| **AI-as-Judge** | Output quality scored by another model (relevance, correctness, tone) | No (but consistent) | seconds |
| **Human Eval** | Human rates output quality | No | minutes-hours |

---

## 2. Unit Tests (Traditional)

Test the CODE, not the model. Same as backend unit tests.

### What to unit test
- Prompt template construction (given inputs, does the prompt look correct?)
- Context assembly (RAG: are retrieved docs formatted correctly?)
- Output parsing (does the parser handle edge cases in model output?)
- Tool argument validation (are model-generated tool args validated before execution?)
- Token counting / context window management logic

### What NOT to unit test
- Model output quality (that's evaluation, not unit testing)
- Whether the model "understands" the prompt (you can't unit test intelligence)

---

## 3. Assertion Tests

Deterministic checks on model output — the closest thing to traditional testing.

### What you can assert

| Check | Example | Tool |
|---|---|---|
| **Output is valid JSON** | Model should return JSON → parse it, assert structure | `json.loads()`, Zod schema |
| **Required fields present** | Structured output has `title`, `summary`, `score` | Schema validation |
| **Output length** | Response is between 50-500 words | String length check |
| **No PII in output** | Response doesn't contain emails, phone numbers | Regex / Presidio |
| **Contains expected keywords** | Summarization includes key entities from input | Keyword check |
| **Doesn't contain forbidden content** | No profanity, no competitor mentions | Keyword blocklist |
| **Tool call format** | Function calling response has correct name and valid args | Schema validation |

### Principles
- Assertions test FORMAT and CONSTRAINTS, not quality
- They're cheap, fast, and deterministic — run on every request in production
- Guard against structural failures (model returns prose when you expected JSON)

---

## 4. AI-as-Judge Evaluation

Use a strong model to evaluate another model's output. The scalable alternative to human evaluation.

### How it works

```
Test case: { input, expected_behavior, context }
     ↓
Run your AI app → get output
     ↓
Send to judge model: "Rate this output 1-5 on [criteria]. Here's the input, context, and output."
     ↓
Judge returns: { score: 4, reasoning: "Accurate but missed one detail" }
```

### Evaluation criteria

| Criterion | What it measures | When |
|---|---|---|
| **Relevance** | Does the output answer the question asked? | Always |
| **Correctness / Accuracy** | Is the information factually correct? | Fact-based tasks |
| **Groundedness** | Is the output supported by provided context (not hallucinated)? | RAG |
| **Completeness** | Does it cover all aspects of the question? | Complex queries |
| **Conciseness** | Is it appropriately brief without losing meaning? | Summarization |
| **Tone / Style** | Does it match the expected voice? | Customer-facing |
| **Harmfulness** | Does it contain harmful or inappropriate content? | Always |
| **Instruction following** | Did it follow the specific instructions in the prompt? | Structured tasks |

### Principles
- **Use a stronger model as judge** (judge with Opus, evaluate Sonnet/Haiku output)
- **Define clear rubrics** — "rate 1-5" is useless without criteria. "5 = factually correct, complete, concise. 1 = wrong or hallucinated."
- **Include reasoning** — ask the judge to explain its score (catches random scoring)
- **Calibrate against human eval** — run both on the same dataset, check agreement
- **Eval dataset should be versioned** — like test fixtures, your eval cases evolve with the product

### Anti-patterns
- AI judges itself (same model evaluates its own output — biased)
- No rubric (just "is this good?" — inconsistent scores)
- Eval dataset too small (10 examples doesn't tell you anything)
- No human calibration (judge scores 5/5 on everything — broken rubric)
- Eval run once, never again (quality drifts, you don't notice)

---

## 5. Evaluating Reasoning Models (Extended Thinking)

When using models with extended thinking (Claude thinking tokens, o1/o3), evaluation changes:

### What's different
- Model produces **thinking tokens + answer tokens** — both need evaluation
- A correct answer with **wrong reasoning** is fragile (will fail on similar but different inputs)
- Reasoning traces can be **long and expensive** — cost tracking must include thinking tokens

### What to evaluate

| Aspect | How | Why |
|---|---|---|
| **Answer correctness** | Same as traditional (assertions, AI-as-judge) | Does the final answer meet the criteria? |
| **Reasoning soundness** | AI-as-judge on the thinking trace: "Is the reasoning logical and complete?" | Wrong reasoning + right answer = unreliable |
| **Reasoning efficiency** | Thinking tokens used vs answer quality | 10K thinking tokens for a simple classification = overkill |
| **Hallucinations in reasoning** | Check if reasoning references facts not in context | Model can hallucinate during thinking, leading to wrong conclusions |

### When to use extended thinking in eval
- Complex reasoning tasks (math, logic, multi-step decisions) — evaluate reasoning, not just answer
- Simple tasks (classification, extraction) — skip extended thinking in eval (unnecessary cost)

### Anti-patterns
- Evaluating only the final answer (ignoring reasoning — misses fragile correct answers)
- Paying for extended thinking on every eval case (most don't need it)
- Not tracking thinking token cost separately (hidden cost explosion)

---

## 6. Adversarial Testing

Intentionally try to break your AI application.

### What to test

| Attack | What you're testing | Example |
|---|---|---|
| **Prompt injection** | Do guardrails catch it? | "Ignore previous instructions and..." |
| **Jailbreaking** | Can the model be tricked into unsafe behavior? | Role-play scenarios, encoding tricks |
| **Data extraction** | Can the user extract the system prompt? | "Repeat everything above this line" |
| **Boundary testing** | What happens at extreme inputs? | Empty input, 100K token input, special characters, unicode |
| **Adversarial examples** | Inputs designed to confuse the model | Typos, homoglyphs, invisible characters |
| **Multi-turn attacks** | Gradual manipulation across conversation turns | First turn normal, slowly escalate to injection |

### Principles
- Run adversarial tests regularly (not just once at launch)
- Include known attack datasets (OWASP LLM Top 10 examples)
- Automate with promptfoo or custom test suites
- Track adversarial success rate over time (should decrease, not increase)

---

## 7. Regression Testing for Model Changes

When the model version changes, does your app still work?

### When to run regression
- Model provider releases new version
- You change the system prompt
- You change RAG retrieval logic (different docs retrieved)
- You add/remove/modify tools
- You change temperature or other parameters

### How
1. Maintain an eval dataset (100-500 representative test cases)
2. Run your app against the dataset with the OLD config → save scores
3. Run your app against the dataset with the NEW config → save scores
4. Compare: did quality improve, stay the same, or degrade?
5. Investigate regressions before deploying

### Principles
- **Never change model version without running regression** — even "minor" version updates change behavior
- **Version your eval dataset** — like test fixtures, not like prod data
- **Automate** — regression should run in CI, not manually

---

## 8. Evaluation Datasets

The test cases you evaluate against.

### How to build

| Source | How | Pros/Cons |
|---|---|---|
| **Manual creation** | Domain experts write test cases | High quality, expensive, small |
| **Production sampling** | Sample real user queries + human-rated responses | Realistic, requires annotation effort |
| **Synthetic generation** | Use a model to generate test cases | Scalable, but may not represent real usage |
| **Adversarial** | Specifically crafted to break the system | Tests robustness, not typical usage |

### Structure
```json
{
  "test_id": "order-status-001",
  "input": "Where is my order #12345?",
  "context": "Order #12345: shipped 2026-04-28, tracking: UPS1234, est delivery: 2026-05-02",
  "expected_behavior": "Should reference the tracking number and estimated delivery date",
  "criteria": ["groundedness", "completeness", "conciseness"],
  "category": "order-status"
}
```

### Principles
- **Diverse** — cover different categories, edge cases, languages, difficulty levels
- **Versioned** — in git, not in a spreadsheet
- **Growing** — add cases from production failures ("this real query caused a bad response" → add to eval set)
- **Categorized** — so you can see where quality is strong vs weak

---

## Tooling

| Tool | What it does |
|---|---|
| **promptfoo** | CLI for prompt evaluation — test cases, assertions, AI-as-judge, comparisons |
| **RAGAS** | RAG-specific evaluation (faithfulness, relevance, context precision/recall) |
| **DeepEval** | LLM evaluation framework (14+ metrics, hallucination, bias, toxicity) |
| **Braintrust** | Eval + tracing + prompt management |
| **Langfuse Scores** | Attach quality scores to traces (manual or automated) |
| **pytest + custom** | Traditional test framework with custom AI evaluation helpers |

---

## References

- [Anthropic — Developing and Testing](https://docs.anthropic.com/en/docs/build-with-claude/develop-tests)
- [promptfoo Documentation](https://www.promptfoo.dev/docs/)
- [RAGAS Documentation](https://docs.ragas.io/)
- [Hamel Husain — Your AI Product Needs Evals](https://hamel.dev/blog/posts/evals/)
- [`../../backend-engineering/testing/`](../../backend-engineering/testing/README.md) — general testing practices
