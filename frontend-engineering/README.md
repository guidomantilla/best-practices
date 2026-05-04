# Frontend Engineering Best Practices

Best practices for frontend development. Backend is the foundation — most principles are shared. This guide references `backend-engineering/` for shared content and adds frontend-specific topics.

---

## Shared with Backend (reference directly)

These topics apply identically to frontend. Read from `backend-engineering/`:

| Topic | Reference |
|---|---|
| **Data Privacy** | [`../backend-engineering/data-privacy/`](../backend-engineering/data-privacy/README.md) — consent management, PII handling, cookie consent, GDPR/CCPA applies equally to frontend |
| **Secure Coding (base)** | [`../backend-engineering/secure-coding/`](../backend-engineering/secure-coding/README.md) — 12 security areas, SDLC, tooling |
| **Software Principles** | [`../backend-engineering/software-principles/`](../backend-engineering/software-principles/README.md) — SOLID, DRY, KISS, DI, composition — all apply to component/module design |
| **Configuration (base)** | [`../backend-engineering/configuration/`](../backend-engineering/configuration/README.md) — sources, precedence, secrets management, feature flags, validation |
| **CI/CD** | [`../backend-engineering/ci-cd/`](../backend-engineering/ci-cd/README.md) — pipeline design, artifacts, deployment (frontend deploys to CDN instead of K8s) |

---

## Frontend-Specific Topics

| Folder | What it covers |
|---|---|
| [secure-coding/](secure-coding/README.md) | Frontend-specific security — XSS, CSP, cookies, CSRF, step-up auth UX, SRI, third-party scripts |
| [configuration/](configuration/README.md) | Frontend config — no secrets in client, build-time vs runtime vs server-only, API keys, tamper-able config |
| [observability/](observability/README.md) | Client-side observability — error tracking, RUM, Core Web Vitals, performance monitoring, security metrics |
| [system-design/](system-design/README.md) | Frontend architecture — rendering strategies, state management, components, BFF, micro-frontends, performance, a11y |
| [contract-consumption/](contract-consumption/README.md) | Consuming APIs — client generation, caching, optimistic updates, error handling, zero trust assumptions |
| [testing/](testing/README.md) | Frontend-specific testing — component, visual regression, accessibility, fitness functions |
| [frameworks/](frameworks/README.md) | How React, Vue, Angular, Svelte, Astro implement the principles — state, composition, fetching, testing, performance |

---

## Partially Applicable (with notes)

### IaC
Only relevant for SSR deployments (Next.js, Nuxt in containers). For Dockerfile and K8s patterns, see [`../backend-engineering/iac/`](../backend-engineering/iac/README.md). For static sites deployed to CDN, IaC is typically the CDN configuration (Cloudflare, CloudFront) managed by platform/infra teams.

### Data Design
Not applicable — frontend doesn't manage data stores. Client-side storage (localStorage, IndexedDB) is covered in [`system-design/`](system-design/README.md).

---

## References

- [web.dev — Core Web Vitals](https://web.dev/vitals/)
- [MDN Web Docs](https://developer.mozilla.org/)
- [Patterns.dev — Modern Web Design Patterns](https://www.patterns.dev/)
