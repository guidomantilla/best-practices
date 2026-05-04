# Best Practices

A curated knowledge base of software engineering best practices. Organized by engineering domain, with cross-cutting security and architecture frameworks.

## What this repo IS

- A **proxy/index** of best practices — enumerates what to consider, references canonical sources (OWASP, CWE, NIST, CISA, Kimball, GoF, etc.)
- **AI-assisted consultation against a curated knowledge base** — the skills query this content to produce narrative findings, gap analysis, and roadmaps
- **Opinionated where it matters** — takes a position on trade-offs, anti-patterns, and tooling choices
- **Written for developers** — deep on what devs own, lighter on what infra/platform teams own
- **Multi-domain** — backend is the canonical base, other domains reference it and add domain-specific content
- **AI-readable** — structured for use by AI coding assistants (Claude Code skills included)

## What this repo is NOT

- Not a tutorial or step-by-step guide
- Not a source of truth — it references sources of truth (OWASP, NIST, etc.), not replaces them
- Not framework-specific — principles are language/framework-agnostic (tooling is mentioned as examples)
- Not exhaustive — covers the most impactful practices, not every edge case
- Not static — evolves with the industry (content is dated 2026, reviewed for currency)
- **Not a substitute for static analyzers.** The repo recommends specific analyzers per language/topic — the analyzers enforce, this repo helps decide *what* to enforce.
- **Not a PR review bot.** Skills are not designed for automated per-PR runs in CI. Output varies between invocations.
- **Not a quality gate.** Severity labels (High/Medium/Low) are reading aids, not thresholds for automated blocking.
- **Not language-specific.** No *Effective Java*, no *Idiomatic Go*, no *Clean Code* book content, no PEP 8 detail. Those exist; this repo references them as tools, doesn't replace them.
- **Not opinion-free.** "Opinionated" means the author has taken positions on trade-offs. Read positions as informed opinion, not industry consensus.
- **Not a playbook.** Lists what to consider, not what to do in order.

## How this compares to tools you may know

If you've used the tools below, this is how they relate. They are complementary — none replaces another.

| Tool | What it is | Output | When to use |
|---|---|---|---|
| SonarQube · Semgrep · ruff · gosec | Static analyzer with deterministic rules | Reproducible findings, exit codes | In CI, every commit |
| Greptile · CodeRabbit · SonarCloud | AI bot for PR review | Line-by-line diff comments | On every PR |
| **best-practices skills** | LLM consultation against a curated knowledge base | Narrative findings + roadmap + tooling recommendations | On demand, exploratory |
| *Effective Java* · *Clean Code* · *Idiomatic Go* | Reference book | Text the dev reads | Onboarding, critical reading |

This repo does not compete with static analyzers — it tells you which ones to wire up. It does not compete with PR bots — it works on whole codebases, not diffs. It does not replace books — it points to them.

---

## Structure

### Engineering Domains

| Domain | Description | Status |
|---|---|---|
| [`backend-engineering/`](backend-engineering/README.md) | **Canonical base.** 11 topics: secure coding, software principles, observability, configuration, testing, CI/CD, IaC, contract design, system design, data design, data privacy. | Complete |
| [`frontend-engineering/`](frontend-engineering/README.md) | 7 domain-specific topics + references to backend for shared content. Covers: secure coding (XSS, CSP, cookies), observability (RUM, CWV), system design (SPA/SSR, state, BFF), testing (component, visual, a11y), frameworks (React/Vue/Angular/Svelte/Astro), configuration (no secrets in client), API consumption. | Complete |
| [`data-engineering/`](data-engineering/README.md) | 5 domain-specific topics + references to backend. Covers: secure coding (PII in pipelines, masking), observability (freshness, lineage, quality metrics), testing (data quality, schema validation, contracts), contract design (schema registry, compatibility), system design (batch/streaming, dimensional modeling, lakehouse, data mesh). | Complete |
| [`ai-engineering/`](ai-engineering/README.md) | 7 domain-specific topics + references to backend. Building apps WITH AI models (LLMs, multimodal). Covers: secure coding (prompt injection, guardrails, OWASP LLM Top 10), observability (tokens, cost, quality, drift), testing (AI-as-judge, adversarial, eval datasets), CI/CD (CI/CT/CD, model registry, A/B), configuration (model params, prompts as config), contract design (streaming, tool_use, structured outputs), system design (RAG, agents, MCP, extended thinking, fine-tuning, inference optimization). | Complete |
| [`ml-engineering/`](ml-engineering/) | Training and adapting models (not using them). | Pending |

### Cross-Cutting Frameworks

| Framework | Description | Status |
|---|---|---|
| [`zero-trust/`](zero-trust/README.md) | CISA Zero Trust Maturity Model v2 + NIST SP 800-207. 5 pillars (Identity, Devices, Networks, Applications, Data) + 3 cross-cutting capabilities. Developer-focused — deep on identity/apps/data, lighter on devices/networks. | Complete |
| [`well-architected/`](well-architected/README.md) | Synthesized from AWS/Azure/GCP Well-Architected Frameworks + Bass (*Software Architecture in Practice*) + Richards/Ford (*Fundamentals of Software Architecture*). 5 pillars + architecture methodology (QA scenarios, ADRs, fitness functions, trade-off analysis, cost optimization). | Complete |

### Skills (Claude Code)

| Folder | Description |
|---|---|
| [`.skills/`](.skills/) | 10 Claude Code skills with automatic domain detection (backend/frontend/data/AI). Each skill reads the appropriate reference files based on the code being reviewed. |

Available skills: `secure-review`, `principles-review`, `observability-review`, `configuration-review`, `testing-review`, `ci-cd-review`, `iac-review`, `contract-design-review`, `system-design-review`, `data-design-review`.

---

## About the skills

What to expect when you invoke a skill.

- **Consultative, not prescriptive.** Output is a starting point for conversation, not a verdict. The skill says "consider X, here's why" — you decide what to do.
- **Auto-domain detection.** Skills inspect imports and file patterns to figure out whether you're in backend, frontend, data, or AI code, and read the right slice of the knowledge base accordingly.
- **Defined scope.** Each skill is bounded. `principles-review` evaluates *how* code is written, not *what* exists; it cannot tell you what to build next. Combining skills covers more ground than asking one skill to do everything.

Skills fall into three categories by what they can observe (a planned rename — tracked in a separate issue — will surface this in the names themselves):

- **Coverage-type** (additive topics): observe what's present vs absent. Output: *"you're missing X, add Y"*. E.g. observability gaps, testing gaps.
- **Review-type** (qualitative topics): observe what exists and rate it against principles. Output: *"what you have violates Z"*. E.g. principles, secure coding patterns.
- **Assess-type** (hybrid topics): both — what's missing, and what exists is good or bad. E.g. system design, data design.

## Reproducibility — what to expect, what to do

> **Skill output is non-deterministic.** Skills are powered by LLMs. Same skill + same code + same prompt can produce slightly different findings between runs. This is a feature (the skill adapts to context) and a limitation (you cannot diff outputs to detect regressions like you would with `ruff` or `gosec`).
>
> **Implications:**
> - Use static analyzers (recommended in the topic READMEs) for reproducible CI gates.
> - Use these skills for exploration, onboarding, gap analysis, and architectural conversations — not for automated quality enforcement.

### What to do if you need determinism

Don't invoke skills in CI. Pair them with deterministic tools instead:

1. Invoke the skill **once** locally to get a review.
2. Ask the skill to **generate a scanning script** with the tools it recommends for your stack (every skill offers this in its `What I Can Generate` section).
3. Use the **script** in CI. The script is deterministic. The skill is exploratory.

| Use case | What to use |
|---|---|
| Exploration, onboarding, gap analysis, architecture conversations | Skill |
| Pre-merge gate, CI, compliance audit | Generated script (with tools the skill picked for your stack) |
| Continuous dashboard | Skill output to seed the dashboard; scripts to keep it updated |

Skills also fall into three categories by how much of their scope can be delegated to deterministic tools:

- **Tool-backed**: a deterministic tool fully covers the skill's scope (`iac-review`, `configuration-review`).
- **Hybrid**: some aspects deterministic, others LLM judgment (`secure-review`, `testing-review`).
- **LLM-pure**: no deterministic counterpart exists; non-determinism is the feature (`principles-review`).

A dedicated structural treatment of this (categorization in skill frontmatter, scanning script structure) is tracked separately.

---

## How the Domains Relate

```
backend-engineering/     ← canonical base (all other domains reference this)
  ├── frontend-engineering/   references backend + adds frontend-specific (XSS, RUM, SPA/SSR, components)
  ├── data-engineering/       references backend + adds data-specific (pipelines, quality, dimensional modeling)
  ├── ai-engineering/         references backend + adds AI-specific (prompts, RAG, agents, eval, guardrails)
  └── ml-engineering/         references backend + adds ML-specific (training, MLOps) [pending]
```

Content that's identical across domains lives in `backend-engineering/` only. Other domains:
- Reference backend for shared content (software principles, CI/CD, IaC, data privacy)
- Create domain-specific files where practices differ
- Don't include topics that don't apply (frontend has no data-design, for example)

---

## How to Use This Repo

### As a developer (human)
1. Start with your domain (`backend-engineering/`, `frontend-engineering/`, etc.)
2. Each domain has a README that maps topics → files
3. Each file is self-contained with principles, anti-patterns, and tooling
4. Cross-references point to related content (never required — each file stands alone)

### As an AI coding assistant
1. Read the relevant domain README to understand structure
2. Read specific topic files based on the review/task at hand
3. Skills in `.skills/` are pre-built prompts that automate this (domain detection + appropriate file reading)
4. Cross-cutting frameworks (`zero-trust/`, `well-architected/`) provide lens for architectural review

### Installing skills in your project
```bash
# Clone this repo
git clone https://github.com/guidomantilla/best-practices.git

# Install skills into your project (choose your tool)
make install-claude TARGET=~/projects/my-app        # Claude Code
make install-copilot TARGET=~/projects/my-app       # GitHub Copilot
make install-cursor TARGET=~/projects/my-app        # Cursor

# Install only specific skills
make install-claude TARGET=~/projects/my-app SKILLS='secure-review testing-review'

# Roll back an install
make uninstall-claude TARGET=~/projects/my-app
make uninstall-all TARGET=~/projects/my-app          # all 3 tools at once

# List available skills
make list
```

### Quick start (after installing)

After `make install-claude`, open Claude Code in your project and try:

**1. Discover what's installed**
```
/best-practices
```
or, in natural language:
```
what best-practices skills do I have here?
```
Claude responds with a catalog of the 10 review skills, what each one covers, and when to use it.

**2. Run a focused review**
```
/secure-review src/api/
```
Claude reads the code under `src/api/`, reports concrete vulnerabilities with file:line citations, and references the relevant section of `backend-engineering/secure-coding/` for the rationale.

**3. Ask in natural language**
```
review the testing strategy for this service — are there gaps?
```
Claude auto-invokes `testing-review`, walks the test pyramid, flags missing levels, and proposes the highest-value tests to add first.

In Cursor and Copilot, the same content is loaded as rules / instructions — invoke by asking the assistant directly (slash commands are Claude-Code-specific).

### For a new project
1. Install skills (see above)
2. `backend-engineering/system-design/methodology.md` — ADRs, trade-off analysis, quality attribute scenarios
3. `well-architected/` — the 5 pillars checklist
4. `zero-trust/` — security posture from day 1
5. Your domain folder — domain-specific best practices

---

## Design Decisions

| Decision | Rationale |
|---|---|
| **Proxy, not source of truth** | Content references canonical sources (OWASP, CWE, NIST). Stable concepts are copied locally (SOLID, CISA ZTMM). Frequently changing content (CVE lists, specific laws) is referenced. |
| **Backend is canonical** | Backend is the foundation of all software. Frontend, data, and AI extend it — they don't exist without it. |
| **Organized by domain, not by topic** | A developer thinks "I'm building a frontend" not "I need the observability chapter". Each domain has its own entry point. |
| **Each file is self-contained** | You can read one file and get value. Cross-references are "for more depth", never "go read this instead". |
| **Anti-patterns alongside practices** | Knowing what NOT to do is as valuable as knowing what to do. Every section has anti-patterns. |
| **Tooling is examples, not prescriptions** | Tools change faster than principles. Mentioned as examples, not mandates. |
| **Skills use relative paths** | Portable — works for anyone who clones the repo, regardless of where they put it. |
| **No sustainability pillar** | AWS-only concept, out of scope for this repo. |
| **No mobile/platform engineering** | Mobile is a different world (not the author's domain). Platform engineering is operations, not code best practices. |
| **Managed vs self-hosted is a trade-off, not a recommendation** | Cloud vendor frameworks recommend managed because they sell managed. This repo presents both sides honestly. |

---

## References (Foundational)

### Standards & Frameworks
- [OWASP Top 10](https://owasp.org/Top10/) · [OWASP API Security Top 10](https://owasp.org/API-Security/) · [OWASP LLM Top 10](https://genai.owasp.org/llm-top-10/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final)
- [CISA Zero Trust Maturity Model v2](https://www.cisa.gov/resources-tools/resources/zero-trust-maturity-model)
- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/) · [Azure](https://learn.microsoft.com/en-us/azure/well-architected/) · [GCP](https://cloud.google.com/architecture/framework)

### Books
- Bass, Clements, Kazman — *Software Architecture in Practice* (4th ed, 2021)
- Richards, Ford — *Fundamentals of Software Architecture* (2nd ed, 2024)
- Kleppmann — *Designing Data-Intensive Applications* (2017)
- Hohpe, Woolf — *Enterprise Integration Patterns* (2003)
- Chip Huyen — *AI Engineering* (2025)
- Kimball — *The Data Warehouse Toolkit* (2013)
- Martin — *Clean Code* (2008) · *Clean Architecture* (2017)
- Beck — *Test-Driven Development* (2003)
- Gamma et al. — *Design Patterns* (1994)
- Hunt, Thomas — *The Pragmatic Programmer* (1999)

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).

Copyright 2026 Guido Mauricio Mantilla Tarazona (guidomau / usq0x6e.co). Bogotá, Colombia.
