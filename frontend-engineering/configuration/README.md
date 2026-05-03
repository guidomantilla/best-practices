# Frontend Configuration

Frontend-specific configuration considerations. For the full configuration reference (sources, precedence, secrets management, feature flags, validation), see [`../../backend-engineering/configuration/`](../../backend-engineering/configuration/README.md).

This file covers what's **different** in frontend: everything the client receives is public.

---

## 1. The Fundamental Rule

**There are no secrets in the frontend.** Everything shipped to the browser is visible:
- JavaScript bundles (readable in DevTools → Sources)
- Network requests (visible in DevTools → Network)
- Environment variables baked at build time (in the bundle as plain strings)
- localStorage, sessionStorage, cookies (readable via DevTools → Application)

If it leaves your server and reaches the browser, assume it's public.

---

## 2. Build-Time vs Runtime vs Server-Only

| Type | When resolved | Visible to client? | Examples |
|---|---|---|---|
| **Build-time** | During `npm run build` | **Yes** — baked into JS bundle | `VITE_API_URL`, `NEXT_PUBLIC_STRIPE_KEY`, `REACT_APP_*` |
| **Runtime** | When page loads (fetched or injected) | **Yes** — in HTML or fetched via API | `window.__CONFIG__`, `/api/config` endpoint, `<meta>` tags |
| **Server-only** | On the server, never sent to client | **No** | `STRIPE_SECRET_KEY`, `DATABASE_URL`, API keys with write access |

### Build-time config

```bash
# .envrc (local dev)
export VITE_API_URL="http://localhost:3000/api"
export VITE_STRIPE_PUBLISHABLE_KEY="pk_test_..."
export VITE_FEATURE_NEW_CHECKOUT="true"
```

Framework conventions:
| Framework | Prefix for client-exposed vars | Everything else |
|---|---|---|
| **Vite** | `VITE_` | Server-only (not bundled) |
| **Next.js** | `NEXT_PUBLIC_` | Server-only (available in API routes, getServerSideProps) |
| **Create React App** | `REACT_APP_` | Not available |
| **Nuxt** | `NUXT_PUBLIC_` in `runtimeConfig.public` | `runtimeConfig` (server-only) |

### Runtime config

For values that need to change without rebuilding (environment-specific URLs, feature flags):

```html
<!-- Injected by server into HTML -->
<script>
  window.__CONFIG__ = {
    apiUrl: "https://api.production.com",
    featureFlags: { newCheckout: true }
  };
</script>
```

Or fetched from an endpoint:
```typescript
// Fetch config on app init
const config = await fetch('/api/config').then(r => r.json());
```

### Principles
- **If it has the public prefix, it's public** — never put secrets in `VITE_*`, `NEXT_PUBLIC_*`, `REACT_APP_*`
- **Build-time for stable values** (API base URL per environment, public keys, feature flags that don't change often)
- **Runtime for dynamic values** (values that change without redeploy, A/B test variants, maintenance mode)
- **Server-only for secrets** (API keys with write access, database URLs, third-party secret keys)

---

## 3. What's Safe for the Client

| Safe (public) | NOT safe (server-only) |
|---|---|
| API base URL | API keys with write/admin permissions |
| Stripe publishable key (`pk_*`) | Stripe secret key (`sk_*`) |
| Google Maps API key (with domain restriction) | Unrestricted API keys |
| Analytics/tracking IDs (GA, Segment) | Database connection strings |
| Feature flag states (on/off) | Feature flag management API keys |
| Public OAuth client ID | OAuth client secret |
| Sentry DSN | Internal service URLs |
| App version / git SHA | Environment-specific secrets |

### The test
Ask: "if an attacker sees this value, can they do damage?" If yes → server-only. If no → safe for client.

---

## 4. API Keys in Frontend

### Keys that ARE safe in frontend (with restrictions)
- **Stripe publishable key** — designed to be public, can only create tokens (not charge)
- **Google Maps API key** — restrict to your domain in Google Console
- **Firebase config** — public by design, security is via Firestore rules
- **Analytics keys** — track only, can't extract data

### Keys that are NOT safe in frontend
- Any key that can read/write/delete data on your behalf
- Any key without domain/IP restriction
- Any key where the vendor says "keep this secret"

### Principles
- **Restrict API keys** — every cloud provider lets you restrict by domain, IP, or API scope. Do it.
- **Use backend as proxy** — if a key must be secret, frontend calls your backend, backend calls the third-party with the secret key
- **Separate keys per environment** — dev key restricted to localhost, prod key restricted to your domain

### Anti-patterns
- Unrestricted Google Maps API key in frontend (anyone can use it, you pay)
- OpenAI/Anthropic API key in frontend (anyone can make calls on your account)
- Admin API keys in frontend "because it's easier" (full account access to any visitor)
- Same API key for dev and prod (compromising dev key = compromising prod)

---

## 5. Feature Flags (Frontend-Specific)

Backend feature flags reference applies (see `../../backend-engineering/configuration/README.md` §6). Additional frontend considerations:

### Client-side evaluation
- Flag state must be available before render (to avoid flicker/layout shift)
- Initial flag state from: server-rendered HTML, config endpoint on page load, or cached from previous visit
- **Default to off** if flag service is unreachable (fail closed)

### SSR + Feature flags
- Evaluate flags on the server during SSR (no flicker, SEO-correct)
- Pass flag state to client for hydration (don't re-evaluate client-side with different result)
- Cache flag state per request (don't call flag service per component render)

### Anti-patterns
- Flag evaluated client-side only → content flickers from default to flagged variant
- Different flag result on server vs client → hydration mismatch
- Fetching flags synchronously on every page load (blocks rendering)
- No fallback when flag service is down (app breaks instead of defaulting)

---

## 6. Client-Side Config is Tamper-able

Users can open DevTools and modify any client-side state: `window.__CONFIG__`, feature flags in memory, localStorage, cookies (non-HttpOnly), JavaScript variables.

### The principle
**Client-side config controls what the user SEES, not what they CAN DO.** Authorization lives on the server.

### Example
```
Feature flag "premium_export" = false in client
→ Export button hidden

User edits flag to true in DevTools
→ Button appears
→ User clicks it
→ Backend responds 403 Forbidden (user is not premium)
→ No damage done
```

If editing client-side config allows the user to do something they shouldn't, **the bug is in the backend**, not the frontend.

### Rules
- Feature flags in the client control **UI visibility**, not **access**
- Every server endpoint validates authorization independently of client state
- Pricing, permissions, quotas — always enforced server-side
- Client-side validation is for UX (fast feedback), server-side validation is for security
- Assume every request is hand-crafted by an attacker, regardless of what the UI shows

### Anti-patterns
- Feature flag hides premium UI → no server-side check → user calls API directly → gets premium data
- Client-side discount calculation trusted by server (user modifies price to $0)
- Admin panel hidden by flag → admin API endpoints have no auth check
- Rate limiting only in the client (disabled by removing the client code)

---

## 7. Environment Detection

### Principles
- **Don't detect environment in client code** — inject the right config at build/deploy time
- **No `if (window.location.hostname === 'production.com')`** — fragile, error-prone
- **Config per environment, not code per environment**

### Pattern
```typescript
// GOOD — config injected at build time
const API_URL = import.meta.env.VITE_API_URL;

// BAD — environment detection in code
const API_URL = window.location.hostname === 'myapp.com'
  ? 'https://api.myapp.com'
  : 'http://localhost:3000';
```

### Anti-patterns
- `if (process.env.NODE_ENV === 'production')` scattered through business logic
- Hostname detection for config (breaks on staging, preview deploys, custom domains)
- Different code paths per environment (ship the same code everywhere, config differs)

---

## References

- [Vite — Env Variables and Modes](https://vitejs.dev/guide/env-and-mode)
- [Next.js — Environment Variables](https://nextjs.org/docs/app/building-your-application/configuring/environment-variables)
- [12-Factor App — III. Config](https://12factor.net/config)
