---
name: assess-ci-cd
description: Review a project's CI/CD pipeline for gaps, anti-patterns, and improvement opportunities. Use when the user asks to review pipeline design, check deployment strategy, assess build reliability, evaluate rollback capabilities, or identify CI/CD bottlenecks. Triggers on requests like "review my pipeline", "is my CI/CD solid", "check deployment strategy", "review my GitHub Actions", or "/assess-ci-cd".
category: hybrid
---

# CI/CD Pipeline Review

Review a project's CI/CD setup for gaps, anti-patterns, and structural issues. Produce actionable findings — not generic "add more stages" advice.

## Context Files

Before reviewing, read this reference document for the full rule set:

- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/ci-cd/README.md` — 10 areas: CI fundamentals, pipeline design, artifacts, deployment strategies, environment promotion, rollback, security, monorepo, tech variations, DORA metrics

## Review Process

1. **Detect the CI/CD platform**: identify from config files (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/config.yml`, `Earthfile`, `Dagger`).
2. **Detect the tech type**: backend (containerized/binary), frontend (SPA/SSR), data pipeline, mobile, library.
3. **Detect the deployment target**: K8s, serverless, traditional, CDN, PaaS.
4. **Map the pipeline stages**: identify what stages exist and in what order (lint, test, build, scan, publish, deploy).
5. **Assess deployment strategy**: how is the app deployed? Rolling, blue-green, canary, recreate?
6. **Scan against the 10 areas**: review against each applicable area from the ci-cd reference.
7. **Report findings**: list each issue with impact, location, and fix.
8. **Recommend tooling**: based on detected platform and stack, suggest applicable tools.
9. **Offer capabilities**: based on findings, offer additional deliverables.

## Review Areas

1. **CI fundamentals** — integration frequency, branch strategy, build speed, broken build policy
2. **Pipeline design** — stage order, parallelization, caching, fail-fast, pipeline as code
3. **Build artifacts** — immutability, versioning, reproducibility, single artifact across environments
4. **Deployment strategy** — appropriate for the service type? Canary/blue-green for critical services?
5. **Environment promotion** — same artifact promoted? Config-only differences? Proper gates?
6. **Rollback** — mechanism exists? Tested? Automated? Database compatible?
7. **Pipeline security** — secrets handling, least privilege, pinned dependencies, signed artifacts
8. **Monorepo concerns** — affected detection, selective builds, dependency graph (only if monorepo)
9. **Tech-appropriate pipeline** — stages match the application type and deployment target?
10. **DORA metrics readiness** — can you measure deployment frequency, lead time, failure rate, MTTR?

These 10 areas are the minimum review scope. Flag additional CI/CD issues beyond these based on the detected platform, team size, or deployment complexity.

## Impact Assessment

| Impact | Criteria |
|---|---|
| **High** | Deployments are risky (no rollback), pipeline has security gaps (secrets exposed, no signing), or broken builds go undetected |
| **Medium** | Pipeline is slow (>15 min), no caching, wrong deployment strategy for the risk level, no environment gates |
| **Low** | Suboptimal parallelization, minor config issues, missing but non-critical stages |

## Detection Patterns

### No fail-fast
```yaml
# BAD — build runs even if lint failed
jobs:
  lint:
    runs-on: ubuntu-latest
    steps: ...
  build:
    runs-on: ubuntu-latest
    steps: ...
    # no "needs: lint" — runs in parallel regardless of lint result
```

### Mutable artifacts
```yaml
# BAD — always pushes to :latest
- run: docker build -t myapp:latest .
- run: docker push myapp:latest
# Which version is in production? Nobody knows.

# GOOD — tagged with git SHA
- run: docker build -t myapp:${{ github.sha }} .
- run: docker push myapp:${{ github.sha }}
```

### Unpinned CI actions
```yaml
# BAD — supply chain risk
- uses: actions/checkout@v4  # tag can be moved to malicious commit

# GOOD — pinned to SHA
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

### Secrets in logs
```yaml
# BAD — debug mode exposes secrets
- run: echo "Deploying with key $API_KEY"
- run: curl -v -H "Authorization: Bearer $TOKEN" https://...  # -v prints headers
```

## Tooling by Platform

### GitHub Actions
| Category | Tool/Feature | What it does |
|---|---|---|
| Caching | `actions/cache` | Cache dependencies between runs |
| Security | `step-security/harden-runner` | Restrict network/process access |
| Security | `github/codeql-action` | SAST scanning |
| Artifacts | `actions/upload-artifact` | Store build outputs |
| Deployment | Environments + protection rules | Approval gates, secrets scoping |

### GitLab CI
| Category | Tool/Feature | What it does |
|---|---|---|
| Caching | `cache:` directive | Cache dependencies |
| Security | Auto DevOps, SAST, DAST | Built-in security scanning |
| Artifacts | `artifacts:` directive | Store build outputs |
| Deployment | Environments + approvals | Deployment gates |

### Kubernetes
| Category | Tool | What it does |
|---|---|---|
| GitOps | ArgoCD | Sync cluster to git state |
| GitOps | Flux | Pull-based K8s deployment |
| Progressive | Argo Rollouts | Canary/blue-green with metrics |
| Progressive | Flagger | Automated canary with metrics |

### Cross-Platform
| Category | Tool | What it does |
|---|---|---|
| Portable pipelines | Dagger | CI-agnostic pipeline definitions |
| Reproducible builds | Earthly | Dockerfile-like CI, runs anywhere |
| Image signing | cosign | Sign and verify container images |
| Scanning | Trivy | Container + IaC + dependency scanning |
| Monorepo | Nx / Turborepo | Affected detection, task caching |

## Output Format

### Findings

For each finding:

```
### [IMPACT] — Short description
- **File**: .github/workflows/ci.yml:42 (or project-level if structural)
- **Area**: which of the 10 CI/CD areas
- **Issue**: what's wrong or missing
- **Fix**: specific action to take (with config snippet if applicable)
- **Tool**: which tool from the toolbox helps here
```

### Summary

```
## Summary
- High: N
- Medium: N
- Low: N
- CI platform: [detected]
- Tech type: [backend | frontend | data | mobile | library]
- Deployment target: [K8s | serverless | traditional | CDN | PaaS]
- Deployment strategy: [rolling | blue-green | canary | recreate | unknown]
- Pipeline stages present: [lint | test | build | scan | publish | deploy]
- Pipeline stages missing: [which are absent]
- Estimated build time: [if determinable]
- Rollback mechanism: [present | absent | untested]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable:

```
## What I Can Generate

Based on this review, I can also:

### For reproducibility (deterministic, CI-ready)
- [ ] **Generate a pipeline-linting workflow** that lints the pipeline definitions themselves (so the pipeline doesn't drift) on every PR. Deterministic — runs alongside the pipeline, not invoked manually.

### For deeper exploration (LLM, non-deterministic)
- [ ] Design a pipeline from scratch for this tech type and deployment target
- [ ] Add caching to reduce build time
- [ ] Implement a canary/blue-green deployment strategy
- [ ] Add security scanning stages (SAST, SCA, secret scanning)
- [ ] Create a rollback mechanism/script
- [ ] Implement affected-only builds for this monorepo
- [ ] Add environment promotion gates
- [ ] Generate DORA metrics tracking setup

Select which ones you'd like me to generate.

## What NOT to Do

- Don't recommend migrating CI platforms unless the current one is fundamentally unsuitable
- Don't prescribe trunk-based development to a team that explicitly uses gitflow (note the trade-off, don't force)
- Don't recommend canary/blue-green for a hobby project with 10 users
- Don't flag missing stages that aren't relevant to the tech type (no "add container scanning" to a frontend SPA)
- Don't recommend monorepo tooling for a single-service repo
- Don't assume K8s — many services deploy to serverless, PaaS, or bare metal
- Don't flag code you haven't read
- Don't recommend SLSA Level 4 for a startup MVP

## Invocation examples

These cover the most useful patterns for this skill. The full list (7 patterns + bonus on context formats) is in the [Invocation patterns section of the README](../../README.md#invocation-patterns).

- **Blind** — `/assess-ci-cd`
- **Narrative** — `/assess-ci-cd stack: GitHub Actions, deploy a EKS via ArgoCD`
- **Roadmap** — `/assess-ci-cd dame un plan para llegar a multi-env con rollback automático`
