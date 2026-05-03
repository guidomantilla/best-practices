# Frontend System Design

Architecture decisions for frontend applications. How to structure, render, manage state, and scale frontend code.

For backend system design (microservices, distributed systems, scalability), see [`../../backend-engineering/system-design/`](../../backend-engineering/system-design/README.md).

---

## Well-Architected Pillars (Frontend)

How the five pillars manifest in frontend:

| Pillar | Where it's covered (frontend) |
|---|---|
| **Operational Excellence** | [`../../backend-engineering/ci-cd/`](../../backend-engineering/ci-cd/README.md) (pipeline, CDN deploy) · [`../observability/`](../observability/README.md) (RUM, error tracking, synthetic) |
| **Security** | [`../secure-coding/`](../secure-coding/README.md) (XSS, CSP, cookies, step-up auth, third-party scripts, client-backend communication) |
| **Reliability** | Error handling in [`../contract-consumption/`](../contract-consumption/README.md) §4 · Graceful degradation (offline, fallback UI) in §6 below |
| **Performance** | §6 below (code splitting, asset optimization, caching) · [`../observability/`](../observability/README.md) §2 (Core Web Vitals, budgets) |
| **Cost** | Bundle size = CDN egress cost · Third-party scripts = bandwidth cost · [`../../well-architected/cost-optimization.md`](../../well-architected/cost-optimization.md) |

For the full well-architected framework, see [`../../well-architected/`](../../well-architected/README.md). For architecture methodology (ADRs, trade-offs, fitness functions), see [`../../backend-engineering/system-design/methodology.md`](../../backend-engineering/system-design/methodology.md) — applies equally to frontend architecture decisions.

---

## 1. Rendering Strategies

| Strategy | How it works | Best for |
|---|---|---|
| **SPA** (Single-Page Application) | Client renders everything. Server sends empty HTML + JS bundle. | Dashboards, internal tools, highly interactive apps |
| **SSR** (Server-Side Rendering) | Server renders HTML per request. Client hydrates. | SEO-critical, dynamic content, personalized pages |
| **SSG** (Static Site Generation) | HTML generated at build time. Served from CDN. | Blogs, docs, marketing sites, content that rarely changes |
| **ISR** (Incremental Static Regeneration) | Static pages that revalidate/regenerate on a schedule or on-demand. | E-commerce product pages, content with periodic updates |
| **Streaming SSR** | Server streams HTML chunks as they become ready. | Pages with slow data dependencies (don't block on slowest query) |
| **Islands** | Static HTML with interactive "islands" hydrated independently. | Content-heavy pages with few interactive elements (Astro) |

### Choosing

| Question | Answer → Strategy |
|---|---|
| Needs SEO? | Yes → SSR/SSG/ISR. No → SPA is fine. |
| Content changes frequently? | Per request → SSR. Daily → ISR. Rarely → SSG. |
| Highly interactive? | Yes → SPA or SSR+hydration. Mostly static → SSG/Islands. |
| Personalized per user? | Yes → SSR (can't pre-generate per user). |
| Need fastest TTFB? | SSG (served from CDN, no server computation). |

### Anti-patterns
- SPA for a blog (no SEO, slow initial load for static content)
- SSR for a dashboard behind auth (SEO irrelevant, adds server cost)
- SSG for 10M product pages that change hourly (build takes forever)
- Full client hydration for a mostly-static page (shipping JS to re-render what's already HTML)

---

## 2. State Management

### State categories

| Category | What it is | Where to manage | Examples |
|---|---|---|---|
| **Server state** | Data from the API that the UI displays | React Query, SWR, Apollo Client, TanStack Query | User profile, order list, product catalog |
| **Client state** | UI-specific state not from the server | Local state (useState), context, Zustand, Jotai | Modal open/close, form input, selected tab |
| **URL state** | State encoded in the URL | Router (query params, path params) | Filters, pagination, search query, selected item |
| **Form state** | Controlled form data and validation | React Hook Form, Formik, native | Input values, errors, dirty/touched state |

### Principles
- **Server state ≠ client state**: don't store API data in Redux/Zustand. Use a server-state library (React Query, SWR) that handles caching, revalidation, loading/error states.
- **Lift state only as needed**: start local (component), lift to parent if shared by siblings, context if shared across a subtree, global only if truly app-wide.
- **URL is state**: filters, pagination, search — these belong in the URL (bookmarkable, shareable, back button works).
- **Derive, don't store**: if state B can be computed from state A, don't store B separately (source of desync).

### Anti-patterns
- Everything in global state (Redux store with modal visibility, form values, and API data — all mixed)
- API data cached in Redux manually (stale data, no revalidation, complex loading logic)
- State that should be in the URL stored in memory (user refreshes → lost)
- Duplicated state (same data in two places that go out of sync)
- Prop drilling 10 levels deep instead of using context or state library

---

## 3. Component Architecture

### Principles
- **Single responsibility**: one component does one thing (display a user card, handle a form, manage a layout)
- **Composition over configuration**: prefer composable small components over one mega-component with 30 props
- **Separation of concerns**: container (data/logic) vs presentational (UI) — even if not strictly enforced, keep logic out of markup
- **Consistent file structure**: one convention for the whole project (feature-based or type-based)

### File structure patterns

**Feature-based (recommended for medium-large apps):**
```
/features
  /orders
    OrderList.tsx
    OrderDetail.tsx
    useOrders.ts
    orders.api.ts
    orders.types.ts
  /auth
    LoginForm.tsx
    useAuth.ts
    auth.api.ts
```

**Type-based (simpler, fine for small apps):**
```
/components
  OrderList.tsx
  OrderDetail.tsx
  LoginForm.tsx
/hooks
  useOrders.ts
  useAuth.ts
/api
  orders.api.ts
  auth.api.ts
```

### Anti-patterns
- God components (500-line component with API calls, logic, and rendering)
- Too many tiny components (every `<div>` is a component — over-abstraction)
- Business logic in components (API calls, transformations inline in JSX)
- Inconsistent structure (some features in `/features`, some in `/components`, some in `/pages`)

---

## 4. Client-Side Storage

### Options

| Storage | Capacity | Persistence | Access | Use case |
|---|---|---|---|---|
| **Memory** (JS variables) | Unlimited (until tab closes) | Session | Sync | Transient UI state |
| **URL** (query params) | ~2KB | Persistent (bookmarkable) | Sync | Filters, pagination, search |
| **sessionStorage** | ~5MB | Tab session | Sync | Multi-step form progress, temporary data |
| **localStorage** | ~5-10MB | Permanent | Sync | User preferences, cached non-sensitive data |
| **IndexedDB** | Hundreds of MB | Permanent | Async | Offline data, large datasets, file caches |
| **Cookies** | ~4KB | Configurable | Sync (sent with requests) | Auth tokens (HttpOnly), consent state |

### Security considerations
- **Never store sensitive data in localStorage/sessionStorage** — accessible to any JS on the page (XSS = full access)
- **Auth tokens in HttpOnly cookies** — not accessible to JS, sent automatically with requests
- **Encrypt locally stored data** if it contains anything user-specific
- See [`../backend-engineering/secure-coding/`](../backend-engineering/secure-coding/README.md) §5.4 for data protection details

### Anti-patterns
- JWT in localStorage (XSS = token stolen)
- Storing large datasets in localStorage (blocking, sync API, limited size)
- No storage quota handling (IndexedDB write fails silently when full)
- Relying on client storage as source of truth (user clears browser → data gone)

---

## 5. Micro-Frontends

Multiple independently deployable frontend applications composed into one user experience.

### When to use
- Multiple teams need to deploy frontend independently
- Large application with distinct domains (checkout team, search team, account team)
- Different tech stacks per section (legacy Angular + new React — migration path)

### When NOT to use
- Single team (overhead exceeds benefit)
- Small application (one SPA is simpler)
- Consistent UX is critical and hard to maintain across teams

### Composition patterns

| Pattern | How | Trade-off |
|---|---|---|
| **Build-time** | npm packages, monorepo | Simple, but couples deploy cycles |
| **Runtime (iframe)** | Each micro-frontend in an iframe | Full isolation, but poor UX (no shared state, separate scrolling) |
| **Runtime (JS)** | Module Federation, single-spa | Shared runtime, flexible, complex setup |
| **Edge-side** | CDN/server composes HTML fragments | Server-side composition, good performance, complex routing |

### Anti-patterns
- Micro-frontends for a 3-person team (massive overhead for no benefit)
- No shared design system (each micro-frontend looks different)
- Shared global state between micro-frontends (defeats independence)
- No versioning contract between shell and micro-frontends

---

## 6. Backend for Frontend (BFF)

A dedicated backend service that exists solely to serve a specific frontend. Not a general-purpose API — it's shaped by what the frontend needs.

### The problem
```
Frontend → General API (returns 50 fields, frontend needs 5)
Frontend → Service A + Service B + Service C (3 calls to render one page)
```

### The solution
```
Frontend → BFF (one call, returns exactly what this frontend needs)
                ↓
         BFF → Service A, Service B, Service C (aggregates, transforms, filters)
```

### When to use
- Multiple frontends (web, mobile, TV) that need different data shapes from the same backends
- Frontend needs to aggregate data from multiple backend services per page
- Reduce chattiness — one BFF call instead of 5 backend calls
- Backend API is too generic (returns too much data, or requires multiple calls for one view)

### When NOT to use
- One frontend, one backend — BFF is unnecessary indirection
- Backend already serves frontend-shaped data (no aggregation needed)
- GraphQL is already in place (GraphQL IS the BFF — client shapes the query)

### Architecture

```
Web App    → Web BFF    ─┐
Mobile App → Mobile BFF ──┤→ Backend Services (shared)
Admin App  → Admin BFF  ─┘
```

Each BFF is owned by the frontend team (or the full-stack team responsible for that frontend). It evolves with the frontend, not with the backend.

### Principles
- **BFF is frontend-owned**: the team that builds the frontend builds the BFF
- **One BFF per frontend type**: web BFF, mobile BFF — not one shared BFF (defeats the purpose)
- **BFF does not contain business logic**: it aggregates, transforms, filters — business rules stay in backend services
- **BFF is thin**: if your BFF has 50 endpoints with complex logic, it's becoming a general-purpose backend
- **BFF can live in the frontend repo**: it's part of the frontend delivery, not a separate service

### Relationship to other patterns
- **API Gateway**: gateway handles cross-cutting (auth, rate limiting, routing). BFF handles frontend-specific aggregation. They can coexist: Gateway → BFF → Services.
- **GraphQL**: GraphQL can replace BFF — the client specifies what data it needs. If you have GraphQL, you probably don't need BFF.
- **contract-consumption**: frontend consumes the BFF's contract, not the backend services directly. See [`../contract-consumption/`](../contract-consumption/README.md).

For backend-side API patterns, see [`../../backend-engineering/system-design/system-level.md`](../../backend-engineering/system-design/system-level.md) and [`../../backend-engineering/contract-design/`](../../backend-engineering/contract-design/README.md).

### Anti-patterns
- Shared BFF for all frontends (becomes a general API — not frontend-specific)
- Business logic in BFF (should only aggregate/transform, not validate/compute business rules)
- BFF that just proxies (no aggregation, no transformation — unnecessary layer)
- Backend team owns the BFF (frontend team can't evolve it at their own pace)

---

## 7. Performance Patterns

### Build tooling
The bundler/compiler doesn't change the principles — tree-shaking, code-splitting, minification apply regardless. Examples by generation:

| Generation | Tools | Notes |
|---|---|---|
| **Legacy** | Webpack, Babel | Mature, plugin ecosystem, slower builds |
| **Current** | Vite, esbuild, SWC | Fast (Rust/Go-based compilation), modern defaults |
| **Emerging** | Turbopack, Rolldown, Oxc | Rust-native, designed for speed at scale |

The principles below apply to all.

### Code splitting
- **Route-based**: lazy load per route (most impactful, easiest)
- **Component-based**: lazy load heavy components (chart library, rich text editor)
- **Don't split too aggressively**: too many chunks = too many network requests

### Asset optimization
- **Images**: use modern formats (WebP, AVIF), responsive sizes (`srcset`), lazy load below fold
- **Fonts**: subset to used characters, `font-display: swap`, preload critical fonts
- **CSS**: purge unused CSS, critical CSS inline in `<head>`, defer non-critical
- **JS**: tree-shake, minify, compress (gzip/brotli)

### Caching strategy
- **Immutable assets** (JS, CSS with hash in filename): `Cache-Control: max-age=31536000, immutable`
- **HTML**: `Cache-Control: no-cache` (always revalidate — ensures latest JS/CSS hashes are loaded)
- **API responses**: cache via library (React Query staleTime), not browser cache
- **Service Workers**: for offline-first or aggressive caching (PWA)

### Anti-patterns
- No code splitting (one 2MB bundle for every page)
- Unoptimized images (5MB hero image on mobile)
- No caching headers (every visit downloads everything again)
- Caching HTML aggressively (users stuck on old version after deploy)
- Loading 15 third-party scripts synchronously (render-blocking)

---

## 8. Accessibility (a11y)

### Principles
- **Semantic HTML first**: use `<button>`, `<nav>`, `<main>`, `<h1>`-`<h6>` — not `<div onclick>`
- **Keyboard navigable**: every interactive element reachable and operable via keyboard
- **Screen reader compatible**: meaningful alt text, ARIA labels where HTML semantics aren't enough
- **Color is not the only indicator**: don't rely solely on color to convey information (add icons, text)
- **Contrast ratios**: WCAG AA minimum (4.5:1 for text, 3:1 for large text)

### Testing accessibility
| Tool | What it does |
|---|---|
| **axe-core** | Automated a11y audit (integrates with Jest, Playwright, CI) |
| **Lighthouse** | Accessibility audit in browser and CI |
| **eslint-plugin-jsx-a11y** | Lint JSX for accessibility issues |
| **VoiceOver / NVDA** | Manual screen reader testing |
| **Stark** | Color contrast checker (Figma/browser) |

### Anti-patterns
- `<div>` and `<span>` for everything (no semantic meaning, invisible to screen readers)
- Missing `alt` on images (screen reader says "image" with no context)
- Focus traps in modals (user can't escape with keyboard)
- Auto-playing media without controls
- Disabled focus outlines (`outline: none`) without alternative focus indicator

---

## References

- [web.dev — Learn Web Development](https://web.dev/learn)
- [Patterns.dev — Design Patterns for Modern Web Apps](https://www.patterns.dev/)
- [WCAG 2.2 Guidelines](https://www.w3.org/TR/WCAG22/)
- [React Documentation](https://react.dev/)
- [Luca Mezzalira — Building Micro-Frontends (2021)](https://www.oreilly.com/library/view/building-micro-frontends/9781492082989/)
