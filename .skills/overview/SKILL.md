---
name: overview
description: List, recommend, and explain the best-practices assessment skills available in this project. Use when the user asks what skills are installed (default catalog), wants advice on which skill to pick (--ask / "asesorame qué skill uso"), or asks how to use a specific skill (positional skill name / "cómo uso /assess-X"). Triggers on requests like "what skills do I have", "list best-practices skills", "asesorame qué corro", "cómo uso /assess-secure-coding", "/overview", "/overview --ask", or "/overview <skill-name>".
---

# Best Practices — Skills Overview

This project ships 10 assessment skills from [guidomantilla/best-practices](https://github.com/guidomantilla/best-practices). Each one focuses on a single domain and produces actionable findings — not generic advice.

## Invocation modes

Three modes. Pick by what's in the prompt. Each mode has a clear trigger and a clear output shape — never silently mix them.

### Mode 1 — Default catalog (no args)

Trigger: `/overview` with no arguments, or natural-language phrases like *"what skills do I have"*, *"list best-practices skills"*, *"show me available assessments"*.

Output: render the **catalog** below as-is (the table of 10 skills + sample invocations + going-deeper links). Optionally, if the user provided light context inline (e.g. *"I'm working on a pipeline"*), append a one-line recommendation at the end (*"For your pipeline, the most relevant is `/assess-ci-cd`"*) — but DO NOT ask questions in this mode.

### Mode 2 — Advisory (`--ask` / "asesorame")

Trigger if the prompt contains either:

- The flag `--ask` (anywhere in the invocation), or
- A natural-language equivalent: *"asesorame qué skill uso"*, *"qué skill corro si...?"*, *"cuál me recomendás para X"*, *"ask me first"*, *"preguntame qué necesito"*, or any phrase clearly requesting a recommendation.

Behavior: BEFORE rendering the catalog, ask the user this short context block in a single message and wait for answers:

   1. ¿En qué etapa está el proyecto? (early-MVP, growth, production, maintenance)
   2. ¿Cuál es la preocupación o tarea inmediata? (free-form)
   3. ¿Hay áreas o dominios que quieras priorizar o ignorar?
   4. ¿Hay constraint inmediato? (deadline, regulación, costos, scaling)

After receiving answers, recommend **1–2 specific skills** with one-line rationale per recommendation. Format:

```
Based on your context, the most relevant skills are:

1. /assess-<skill> — <why it fits>
2. /assess-<skill> — <why it fits, if a second one applies>

For full usage of either, run /overview <skill-name>.
```

**Do not run the recommended skills.** Advisory mode only suggests.

If the answers strongly match a single skill, recommend just that one and skip the second slot.

### Mode 3 — How-to (positional skill name)

Trigger if the prompt's first non-flag argument is a known skill name, e.g.:

- `/overview assess-secure-coding`
- `/overview assess-iac`
- Natural language: *"cómo uso /assess-testing"*, *"explicame cómo invocar /assess-system-design"*, *"how do I get a roadmap from /assess-X"*

Behavior: render a **focused page for that skill** — not the catalog. Three blocks:

1. **What it covers** — pull from the catalog row for that skill (one line).
2. **Recommended invocation patterns** — pick the 2–3 most relevant patterns from the [Invocation patterns](https://github.com/guidomantilla/best-practices#invocation-patterns) section in the README that fit this skill best. Show the pattern name, a sample invocation, and what output to expect. Examples by skill:
   - `assess-system-design` → favor Plan-first + Roadmap-driven.
   - `assess-iac` → favor Scoped + Deterministic.
   - `assess-testing` → favor Roadmap + Plan-first.
   - `assess-secure-coding` → favor Narrative + Deterministic.
3. **What it can generate** — point to the skill's own `What I Can Generate` section, calling out the deterministic counterpart specifically (every assess-* skill has one as the first item now).

Keep the output short — one screenful, not a manual.

If the skill name in the prompt is unknown, fall back to Default catalog mode and gently note the typo (*"I don't recognize `<input>`. Available skills are listed below."*).

---

## Catalog

This is the content rendered in **Default catalog** mode. Mode 3 (How-to) uses a single row from this table for the chosen skill.

| Skill | Scope | Use when |
|---|---|---|
| `/assess-secure-coding` | Vulnerabilities, secure coding, privacy compliance (HIPAA/GLBA/CCPA/GDPR/LGPD/PCI-DSS) | Auditing security posture, before shipping a sensitive feature |
| `/assess-coding-principles` | Software design principles, code quality, maintainability, testability | Reviewing a refactor, evaluating code smells |
| `/assess-system-design` | Architecture patterns, scalability, resilience, integration | Designing or revising a service / microservice boundary |
| `/assess-contract-design` | REST, gRPC, GraphQL, WebSocket, async messaging, webhooks | Designing a new endpoint, evolving an API |
| `/assess-data-design` | Schema design, queries, connection management, caching, data lifecycle | Reviewing database code, query performance, schema decisions |
| `/assess-configuration` | Env vars, secrets, feature flags, validation, environment hygiene | Auditing how configuration and secrets are handled |
| `/assess-observability` | Logging, metrics, tracing, instrumentation gaps | Checking if a service is operable in production |
| `/assess-testing` | Test pyramid, quality, flakiness, coverage gaps | Evaluating testing strategy or specific test code |
| `/assess-ci-cd` | Pipeline design, deployment strategy, build reliability, rollback | Reviewing GitHub Actions / GitLab CI / Jenkins setup |
| `/assess-iac` | Terraform, Pulumi, CloudFormation, Kubernetes, Helm, Dockerfiles | Reviewing infrastructure code or container images |

## Sample invocations (across modes)

```
# Default catalog
/overview
what skills do I have

# Advisory (intake to recommend)
/overview --ask
asesorame qué skill uso para mi pipeline de datos

# How-to (focused page for one skill)
/overview assess-secure-coding
cómo uso /assess-iac

# Direct skill invocations (from the catalog)
/assess-secure-coding src/api/
/assess-iac terraform/
/assess-contract-design proto/
```

## Going deeper

The skills reference the canonical knowledge base at:

- Backend: https://github.com/guidomantilla/best-practices/tree/main/backend-engineering
- Frontend: https://github.com/guidomantilla/best-practices/tree/main/frontend-engineering
- Data: https://github.com/guidomantilla/best-practices/tree/main/data-engineering
- AI: https://github.com/guidomantilla/best-practices/tree/main/ai-engineering
- Cross-cutting: `zero-trust/` and `well-architected/`

For prompting patterns shared across all skills (Blind, Scoped, Narrative, Roadmap, Conversational, Deterministic, Plan-first), see the [Invocation patterns section in the README](https://github.com/guidomantilla/best-practices#invocation-patterns).
