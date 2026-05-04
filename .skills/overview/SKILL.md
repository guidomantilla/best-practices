---
name: overview
description: List and describe the best-practices review skills available in this project. Use when the user asks what review/assessment skills are installed, wants a tour of capabilities, or doesn't know which skill to invoke. Triggers on requests like "what skills do I have", "list best-practices skills", "what can you review", "show me available reviews", or "/overview".
---

# Best Practices — Skills Overview

This project ships 10 review skills from [guidomantilla/best-practices](https://github.com/guidomantilla/best-practices). Each one focuses on a single domain and produces actionable findings — not generic advice.

## How to invoke

- **Slash**: type `/<skill-name>` (e.g. `/secure-review`).
- **Natural language**: ask in your own words — "review the security of this service", "are there testing gaps".
- **Scoped**: pass a path or pattern to focus the review (e.g. `/iac-review terraform/`).

## The 10 skills

| Skill | Scope | Use when |
|---|---|---|
| `/secure-review` | Vulnerabilities, secure coding, privacy compliance (HIPAA/GLBA/CCPA/GDPR/LGPD/PCI-DSS) | Auditing security posture, before shipping a sensitive feature |
| `/principles-review` | Software design principles, code quality, maintainability, testability | Reviewing a refactor, evaluating code smells |
| `/system-design-review` | Architecture patterns, scalability, resilience, integration | Designing or revising a service / microservice boundary |
| `/contract-design-review` | REST, gRPC, GraphQL, WebSocket, async messaging, webhooks | Designing a new endpoint, evolving an API |
| `/data-design-review` | Schema design, queries, connection management, caching, data lifecycle | Reviewing database code, query performance, schema decisions |
| `/configuration-review` | Env vars, secrets, feature flags, validation, environment hygiene | Auditing how configuration and secrets are handled |
| `/observability-review` | Logging, metrics, tracing, instrumentation gaps | Checking if a service is operable in production |
| `/testing-review` | Test pyramid, quality, flakiness, coverage gaps | Evaluating testing strategy or specific test code |
| `/ci-cd-review` | Pipeline design, deployment strategy, build reliability, rollback | Reviewing GitHub Actions / GitLab CI / Jenkins setup |
| `/iac-review` | Terraform, Pulumi, CloudFormation, Kubernetes, Helm, Dockerfiles | Reviewing infrastructure code or container images |

## Sample invocations

```
/secure-review src/api/
/iac-review terraform/
/contract-design-review proto/
review my testing strategy
is this database schema well designed
```

## Going deeper

The skills reference the canonical knowledge base at:

- Backend: https://github.com/guidomantilla/best-practices/tree/main/backend-engineering
- Frontend: https://github.com/guidomantilla/best-practices/tree/main/frontend-engineering
- Data: https://github.com/guidomantilla/best-practices/tree/main/data-engineering
- AI: https://github.com/guidomantilla/best-practices/tree/main/ai-engineering
- Cross-cutting: `zero-trust/` and `well-architected/`

## What this skill does

When invoked, present the table above and (optionally) suggest 1–2 skills tailored to the user's stated context — for example, if they mention a pipeline, recommend `/ci-cd-review`; if they mention a database, `/data-design-review`. Keep the response short.
