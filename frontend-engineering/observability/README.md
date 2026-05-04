# Frontend Observability

Client-side observability — what to measure, how to track errors, and how to monitor real user experience.

For server-side observability (tracing, metrics, structured logging), see [`../../backend-engineering/observability/`](../../backend-engineering/observability/README.md).

---

## 1. Error Tracking

### What to capture
- Unhandled exceptions (JavaScript errors, promise rejections)
- Network failures (API calls that fail, timeout, or return unexpected status)
- Rendering errors (React error boundaries, Vue error handlers)
- Custom business errors (checkout failed, form submission rejected)

### Required context per error
- Stack trace (with source maps for minified code)
- Browser, OS, device type
- URL / route where error occurred
- User ID (if authenticated — respect PII rules)
- Breadcrumbs (user actions leading up to the error)
- Release/version (which deploy introduced this)

### Principles
- **Source maps**: upload to error tracking service (Sentry, Datadog) — never serve to clients in production
- **Group by root cause**: not by message string (one bug = one issue, not 10,000 individual events)
- **Alert on new errors**: first occurrence of a new error type is signal, not noise
- **Ignore known noise**: browser extensions, bot errors, network errors from user's connection

### Anti-patterns
- No error tracking (users report bugs via support tickets — if at all)
- Tracking every `console.error` without filtering (noise drowns signal)
- No source maps (minified stack traces are useless)
- No release tagging (can't correlate errors to deploys)
- Logging PII in error context (user data in error reports)

### Tooling
| Tool | What it does |
|---|---|
| **Sentry** | Error tracking, source maps, breadcrumbs, release tracking |
| **Datadog RUM** | Real User Monitoring + error tracking |
| **LogRocket** | Session replay + error tracking |
| **Bugsnag** | Error tracking with stability scoring |

---

## 2. Real User Monitoring (RUM)

Measure what real users experience, not what synthetic tests show.

### Core Web Vitals (Google)

| Metric | What it measures | Good | Needs improvement | Poor |
|---|---|---|---|---|
| **LCP** (Largest Contentful Paint) | Loading — when main content is visible | < 2.5s | 2.5-4s | > 4s |
| **INP** (Interaction to Next Paint) | Interactivity — response time to user input | < 200ms | 200-500ms | > 500ms |
| **CLS** (Cumulative Layout Shift) | Visual stability — unexpected layout movement | < 0.1 | 0.1-0.25 | > 0.25 |

### Additional metrics to track

| Metric | What it measures | Why |
|---|---|---|
| **FCP** (First Contentful Paint) | When first content appears | Perceived speed |
| **TTFB** (Time to First Byte) | Server response time | Backend/CDN performance |
| **Bundle size** | JavaScript/CSS payload size | Download time, parse time |
| **Hydration time** | SSR → interactive | Time until SSR page is usable |
| **Long tasks** | JS tasks > 50ms | UI jank, blocked main thread |

### Principles
- **Measure at the percentile** (p75, p90, p95) — averages hide slow users
- **Segment by**: device type (mobile vs desktop), connection speed (3G vs fiber), geography, browser
- **Monitor trends**: a 200ms LCP increase after a deploy is a regression
- **Set budgets**: LCP < 2.5s, bundle < 200KB, etc. — alert on violations

### Anti-patterns
- Only measuring in Chrome DevTools (not real users, not real networks)
- No segmentation (mobile users on 3G have a completely different experience)
- Measuring only averages (p50 is fine while p95 is 10 seconds)
- No performance budget (bundle grows 50KB per sprint, nobody notices)

### Tooling
| Tool | What it does |
|---|---|
| **web-vitals** (library) | Measure Core Web Vitals in browser, send to analytics |
| **Datadog RUM** | Real user monitoring with session replay |
| **Speedcurve** | Performance monitoring, budgets, competitor benchmarking |
| **Lighthouse CI** | Automated performance audits in CI |
| **Chrome UX Report (CrUX)** | Real-world Chrome user experience data |

---

## 3. Client-Side Logging

### What to log
- API call failures (status, URL, duration — not request/response bodies)
- Navigation events (route changes, page views)
- Feature flag evaluations (which variant was shown)
- User actions that lead to errors (breadcrumbs)
- Performance marks (custom timing for critical flows)

### What NOT to log
- User input values (PII risk — form contents, search queries with personal data)
- Auth tokens, session IDs in plaintext
- Full request/response bodies (PII, payload size)
- Every click, scroll, mousemove (excessive volume, minimal value)

### Principles
- **Log to a service, not to console**: `console.log` in production is invisible and costs nothing — but also helps nothing
- **Structured events**: `{ type: "api_error", url: "/api/users", status: 500, duration_ms: 234 }` not `"API call failed"`
- **Volume control**: client-side logging is paid per event (Datadog, Sentry) — sample or filter
- **Respect DNT/consent**: if user opts out of tracking, respect it

### Anti-patterns
- `console.log` left in production (no one will ever see it)
- Logging everything client-side (cost explosion, 80% is noise)
- No structured format (unqueryable blobs of text)
- Logging PII (violates data privacy, see `../../backend-engineering/data-privacy/`)

---

## 4. Performance Monitoring

Beyond Core Web Vitals — runtime performance.

### What to monitor
- **Bundle size per route**: lazy-loaded chunks, initial bundle, vendor chunk
- **Runtime performance**: long tasks (> 50ms), memory usage, frame rate drops
- **API waterfall**: are requests sequential when they could be parallel?
- **Cache hit rate**: are service workers / browser cache actually working?
- **Third-party impact**: how much latency do analytics, ads, chat widgets add?

### Budgets

| Budget | Target | Enforce |
|---|---|---|
| Initial JS bundle | < 200KB (gzipped) | CI check (bundlesize, size-limit) |
| Total page weight | < 1MB | CI check |
| LCP | < 2.5s (p75) | RUM alert |
| INP | < 200ms (p75) | RUM alert |
| Third-party JS | < 100KB | Manual review |

### Tooling
| Tool | What it does |
|---|---|
| **Lighthouse** | Performance, accessibility, SEO audit (synthetic) |
| **size-limit** | Bundle size enforcement in CI |
| **bundleanalyzer** (webpack/vite) | Visualize what's in your bundle |
| **Chrome DevTools Performance** | Runtime performance profiling |
| **Perfume.js** | Custom performance metrics library |

---

## 5. Synthetic Monitoring

Automated checks that simulate user behavior — complements RUM (real users).

### What to monitor
- Critical pages load successfully (home, login, checkout)
- Core Web Vitals from known locations/devices
- API availability from client perspective
- Third-party service availability (CDN, auth provider, payment)

### Principles
- Run from multiple geographic locations (not just your office)
- Run on schedule (every 5-15 minutes for critical flows)
- Alert on degradation, not just failure (LCP increased from 1.5s to 3.5s)
- Complement with RUM — synthetic catches outages, RUM catches real-world issues

### Anti-patterns
- Only synthetic, no RUM (doesn't represent real user diversity)
- Only RUM, no synthetic (can't detect outages when no users are active — 3am)
- Synthetic from one location only (regional CDN issues invisible)

### Tooling
| Tool | What it does |
|---|---|
| **Checkly** | Synthetic monitoring with Playwright scripts |
| **Grafana k6** | Synthetic browser checks |
| **Pingdom** | Uptime and page speed monitoring |
| **Datadog Synthetics** | Browser and API synthetic tests |

---

## 6. Security Metrics (Frontend)

Security-relevant signals from the client side. Feeds into backend UEBA (User and Entity Behavior Analytics). For backend security metrics, see [`../../backend-engineering/observability/`](../../backend-engineering/observability/README.md) §6 (Security Metrics).

### What to track from the client

| Metric | What it detects | How |
|---|---|---|
| **Failed login attempts** | Brute force, credential stuffing | Count 401s on login endpoint per session/IP |
| **MFA challenge failures** | Phishing, account takeover | Count failed MFA submissions |
| **Rapid re-authentication** | Token theft, session hijacking | Multiple 401→re-auth cycles in short time |
| **New device/browser detected** | Account compromise | Compare stored fingerprint/cookie with current |
| **Unusual navigation patterns** | Automated abuse, bot | Accessing admin paths without navigating through UI |
| **CSP violations** | XSS attempts, compromised third-party | `report-uri` / `report-to` CSP header |
| **Step-up auth triggers** | Sensitive operations being attempted | Count step-up challenges per user/session |

### Principles
- **Frontend detects, backend decides**: frontend tracks signals and sends them as structured events — backend correlates and acts (lock account, require step-up, alert security team)
- **Don't duplicate backend metrics**: auth failure RATE and anomaly detection is backend's job. Frontend sends raw events, backend aggregates.
- **CSP reporting is free security observability**: configure `report-to` and monitor — it tells you about XSS attempts and misconfigured third-party scripts.

### Anti-patterns
- No security events tracked client-side (all security observability is backend — misses client-side signals like CSP violations)
- Security events logged to `console.log` (invisible in production)
- Tracking too much (every click as "security event" — noise)
- No CSP reporting configured (XSS attempts invisible)

For the zero trust perspective on visibility and analytics, see [`../../zero-trust/cross-cutting.md`](../../zero-trust/cross-cutting.md) §1.
