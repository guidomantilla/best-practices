---
name: assess-system-design
description: Review system architecture for design issues, wrong patterns, scalability gaps, and resilience weaknesses. Use when the user asks to review architecture, assess system design decisions, evaluate scalability, check resilience patterns, or validate integration patterns. Triggers on requests like "review my architecture", "is this system design sound", "check scalability", "review my microservices", or "/assess-system-design".
---

# System Design Review

Review system architecture for design issues, pattern misuse, and structural weaknesses. Produce actionable findings — not generic "use microservices" advice.

## Domain Detection

| Signal | Domain | Context files to read |
|---|---|---|
| Go, Rust, Java, Python services, microservices, K8s, gRPC | **Backend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/system-design/` (README + relevant zoom-level file + methodology.md) |
| React, Vue, Angular, SPA/SSR, state management, BFF | **Frontend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/frontend-engineering/system-design/README.md` |
| dbt, Spark, Airflow, Kafka, warehouse, data lake, star schema | **Data** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/data-engineering/system-design/README.md` |
| LLM SDK, RAG, vector DB, agents, tool_use, prompt chains, embeddings | **AI** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/ai-engineering/system-design/README.md` (RAG, agents, chains, fine-tuning, inference, guardrails arch) |

Backend system-design files by zoom level (read only what's relevant):
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/system-design/code-level.md` — GoF patterns
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/system-design/application-level.md` — Clean/Hexagonal/DDD/12-Factor/authz as architecture
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/system-design/integration-level.md` — EIP, Saga, Circuit Breaker, service mesh, centralized authz
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/system-design/system-level.md` — Microservices, Monolith, Event-Driven, Serverless
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/system-design/scalability.md` — scaling strategies
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/system-design/resilience.md` — fault tolerance, DR, chaos
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/system-design/methodology.md` — QA scenarios, ADRs, fitness functions, trade-offs, cost as QA

## Review Process

1. **Detect domain**: backend (service architecture), frontend (rendering, state, components, BFF), or data (batch/streaming, dimensional modeling, lakehouse, data mesh).
2. **Identify the zoom level** (backend): code-level, application-level, integration-level, or system-level?
3. **Understand the context**: team size, traffic scale, domain complexity, maturity.
4. **Assess pattern fit**: are the chosen patterns appropriate for the context?
5. **Identify anti-patterns**: are common mistakes present?
6. **Evaluate trade-offs**: are the trade-offs acknowledged and appropriate? (see methodology.md)
7. **Report findings**: list each issue with impact, location, and recommendation.
8. **Offer capabilities**: based on findings, offer additional deliverables.

## Review Areas

### Architecture Fit
1. **Complexity vs need** — is the architecture proportional to the problem? Over-engineered? Under-engineered?
2. **Pattern appropriateness** — are patterns used correctly and for the right reasons?
3. **Boundary quality** — are service/module boundaries in the right places?

### Application Level
4. **Internal structure** — layers, dependency direction, separation of concerns
5. **12-Factor compliance** — stateless, config externalized, disposable, port-bound
6. **Domain modeling** — appropriate use of DDD patterns (if applicable)

### Integration Level
7. **Inter-service communication** — sync vs async choice, circuit breakers, retries
8. **Data consistency** — saga patterns, eventual consistency handled correctly
9. **Coupling** — services appropriately decoupled? Or distributed monolith?

### System Level
10. **Topology** — monolith vs microservices vs serverless appropriate for team/scale?
11. **Data ownership** — each service owns its data? No shared databases?
12. **Deployment independence** — can services deploy independently?

### Scalability
13. **Bottleneck identification** — what's the scaling bottleneck? Is it addressed?
14. **Horizontal scaling readiness** — stateless? Load balanced? Auto-scaled?
15. **Database scaling** — read replicas? Sharding planned? Connection management?

### Resilience
16. **Failure modes** — what happens when each dependency fails?
17. **Timeouts and circuit breakers** — present on all external calls?
18. **Redundancy** — single points of failure identified and mitigated?
19. **Recovery** — rollback, DR plan, health checks, self-healing?

These areas are the minimum review scope. Flag additional concerns based on detected architecture, scale, or team context.

## Impact Assessment

| Impact | Criteria |
|---|---|
| **High** | Architectural mismatch (microservices for 2 developers), single points of failure in critical path, distributed monolith, no resilience for production system |
| **Medium** | Wrong pattern for the context, missing circuit breakers, no graceful degradation, coupling that will cause pain on next change |
| **Low** | Suboptimal but functional, minor pattern misuse, premature abstraction, over-engineering for current scale |

## Output Format

### Findings

For each finding:

```
### [IMPACT] — Short description
- **Zoom level**: code / application / integration / system / scalability / resilience
- **Location**: which service, module, or architectural decision
- **Issue**: what's wrong or mismatched
- **Context**: why this matters given the team/scale/domain
- **Recommendation**: what to do (with trade-off acknowledged)
```

### Summary

```
## Summary
- High: N
- Medium: N
- Low: N
- Architecture type: [Monolith | Modular Monolith | Microservices | Serverless | Hybrid]
- Team size: [if known]
- Domain complexity: [Low | Medium | High]
- Primary concerns: [scalability | resilience | coupling | complexity | all]
- Biggest risk: [one sentence]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable:

```
## What I Can Generate

Based on this review, I can also:
- [ ] Propose a target architecture with migration path
- [ ] Design service boundaries based on detected domain
- [ ] Create a resilience strategy (circuit breakers, fallbacks, timeouts)
- [ ] Design a scaling strategy for the detected bottleneck
- [ ] Propose a strangler fig migration plan (monolith → services)
- [ ] Design integration patterns between detected services
- [ ] Create a disaster recovery plan for this architecture
- [ ] Evaluate event-driven vs synchronous for detected communication patterns

Select which ones you'd like me to generate.
```

Only list capabilities that are relevant to the findings and context.

## What NOT to Do

- Don't recommend microservices to a 3-person team
- Don't recommend a monolith to a 50-person organization with 10 teams
- Don't prescribe patterns without understanding the context (team, scale, domain)
- Don't flag a simple 3-layer architecture as "wrong" for a simple service
- Don't assume the team has unlimited operational capacity (microservices + K8s + service mesh requires significant ops maturity)
- Don't recommend event sourcing for CRUD applications
- Don't recommend CQRS for services with one read and one write pattern
- Don't flag code you haven't read or architecture you haven't understood
- Don't ignore team size and maturity — the "right" architecture depends on who's building it
- Don't say "it depends" without explaining the trade-offs and making a recommendation for the detected context
