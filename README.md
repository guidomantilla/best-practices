# Best Practices

A curated knowledge base of software engineering best practices. Organized by engineering domain, with cross-cutting security and architecture frameworks.

## What this repo IS

- A **proxy/index** of best practices — enumerates what to consider, references canonical sources (OWASP, CWE, NIST, CISA, Kimball, GoF, etc.)
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

# List available skills
make list
```

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
