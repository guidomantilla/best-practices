# Frontend Secure Coding

Frontend-specific security considerations. For the full security reference (12 areas, SDLC, tooling), see [`../../backend-engineering/secure-coding/`](../../backend-engineering/secure-coding/README.md).

This file covers what's **different or additional** for frontend.

---

## 1. XSS Prevention (Cross-Site Scripting)

Backend lists XSS as a bullet [CWE-79]. In frontend, it's the #1 attack vector — deserves depth.

### Types

| Type | How it happens | Where |
|---|---|---|
| **Reflected** | User input in URL reflected in page without encoding | Server-rendered pages, error messages |
| **Stored** | Malicious input saved to DB, rendered to other users | Comments, profiles, user-generated content |
| **DOM-based** | Client-side JS reads from URL/input and writes to DOM unsafely | `innerHTML`, `document.write`, `eval` |

### Prevention
- **Never use `innerHTML` with user data** — use `textContent` or framework bindings (React JSX, Vue templates auto-escape)
- **Sanitize HTML when you must render it** — use DOMPurify, never regex-based sanitization
- **Avoid `eval()`, `new Function()`, `setTimeout(string)`** — code execution from strings
- **Avoid `document.write()`** — legacy, dangerous, blocks parsing
- **URL validation**: before using URL params in DOM, validate protocol (`javascript:` is an XSS vector)
- **Framework auto-escaping**: React, Vue, Angular escape by default — but `dangerouslySetInnerHTML`, `v-html`, `[innerHTML]` bypass it

### Anti-patterns
- `dangerouslySetInnerHTML` with user content (the name warns you)
- String concatenation into HTML templates
- Trusting URL query params without validation
- Disabling framework escaping "because the HTML looks broken"

---

## 2. Content Security Policy (CSP)

HTTP header that tells the browser what resources are allowed to load.

### Directives

| Directive | Controls | Recommended |
|---|---|---|
| `default-src` | Fallback for all resource types | `'self'` |
| `script-src` | JavaScript sources | `'self'` (no `'unsafe-inline'`, no `'unsafe-eval'`) |
| `style-src` | CSS sources | `'self' 'unsafe-inline'` (needed for CSS-in-JS, unfortunately) |
| `img-src` | Image sources | `'self' data: https:` |
| `connect-src` | XHR, fetch, WebSocket destinations | `'self' https://api.yourdomain.com` |
| `frame-ancestors` | Who can embed your page in iframe | `'none'` (unless embedding is needed) |
| `form-action` | Where forms can submit to | `'self'` |

### Principles
- **Start strict, loosen as needed** — `default-src 'self'` then add exceptions
- **No `'unsafe-inline'`** for scripts — use nonces or hashes instead
- **No `'unsafe-eval'`** — eliminates `eval()`, `new Function()` vectors
- **Report violations**: `report-uri` / `report-to` — monitor what CSP blocks before enforcing
- **Deploy in report-only first**: `Content-Security-Policy-Report-Only` to test without breaking

### Anti-patterns
- No CSP at all (browser allows any script from anywhere)
- `script-src *` (allows scripts from any domain — useless CSP)
- `'unsafe-inline' 'unsafe-eval'` (disables the two most important protections)
- CSP set and never monitored (violations happen silently)

---

## 3. Cookie Security

### Flags

| Flag | What it does | When to set |
|---|---|---|
| `HttpOnly` | Not accessible to JavaScript | Always for auth tokens (prevents XSS from stealing them) |
| `Secure` | Only sent over HTTPS | Always in production |
| `SameSite=Strict` | Not sent on cross-site requests | Auth cookies (prevents CSRF) |
| `SameSite=Lax` | Sent on top-level navigation only | Default — good balance |
| `SameSite=None; Secure` | Sent on cross-site (required for third-party) | Only when needed (embedded widgets, SSO) |

### Principles
- **Auth tokens in HttpOnly cookies** — not localStorage, not sessionStorage (XSS can't read HttpOnly cookies)
- **Set all three flags** on auth cookies: `HttpOnly; Secure; SameSite=Strict`
- **Short expiration** on session cookies — balance between UX and security

### Anti-patterns
- JWT in localStorage (any XSS = full account takeover)
- No `SameSite` flag (browser defaults vary — be explicit)
- No `Secure` flag (cookie sent over HTTP — interceptable)
- `SameSite=None` without a reason (opens to CSRF)

---

## 4. CSRF Protection

### How CSRF works
Attacker's page makes a request to your API using the victim's cookies (browser sends cookies automatically).

### Frontend responsibilities
- Include anti-CSRF token in state-changing requests (from meta tag, cookie, or API response)
- `SameSite=Strict/Lax` on auth cookies (modern browsers block cross-site requests)
- Verify `Origin` / `Referer` headers on the server (backend responsibility, but frontend must send them)

### With SPA + API (token-based auth)
- If auth is via `Authorization: Bearer` header (not cookies) → CSRF is not possible (browser doesn't auto-send headers)
- If auth is via cookies → CSRF protection is required

---

## 5. Step-Up Authentication (Frontend UX)

When the backend requires re-authentication for sensitive operations (zero trust: continuous validation, not just login-time auth).

### How it works
```
User is logged in (valid session)
  → User clicks "Delete Account" or "Change Password" or "Confirm Payment"
  → Backend responds 401/403 with step-up challenge (or custom header/body indicating re-auth needed)
  → Frontend shows MFA modal / password re-entry / biometric prompt
  → User completes challenge
  → Frontend retries the original request with fresh auth
```

### Frontend responsibilities
- **Detect step-up challenge**: recognize when the backend is asking for re-authentication (HTTP 401 with specific error code, or custom response field like `"requires_step_up": true`)
- **Show re-auth UI**: MFA prompt, password re-entry, or redirect to IdP — without losing the user's context (don't navigate away, use a modal)
- **Retry the original action**: after successful re-auth, replay the request the user was trying to make (don't make them click again)
- **Support FIDO2/WebAuthn**: if the backend supports phishing-resistant MFA, the frontend must implement the WebAuthn browser API (`navigator.credentials.get()`)
- **Handle timeout gracefully**: if the user takes too long on the MFA prompt, the challenge may expire — show a clear message and allow retry

### When step-up is triggered (backend decides, frontend handles)
- Password change, email change
- Payment / financial transactions
- Account deletion
- Downloading sensitive data (export PII)
- Elevated admin actions
- First action from a new device/IP

### Anti-patterns
- No step-up auth (changing password requires the same auth level as viewing a profile)
- Full page redirect to login for step-up (user loses form data, context, scroll position)
- No retry after re-auth (user completes MFA but has to click "Delete Account" again)
- Hardcoded list of "sensitive actions" in frontend (backend should decide what requires step-up, not frontend)

---

## 6. Subresource Integrity (SRI)

Verify that externally loaded scripts/styles haven't been tampered with.

```html
<script
  src="https://cdn.example.com/lib.js"
  integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxAh/..."
  crossorigin="anonymous">
</script>
```

### When to use
- Loading JS/CSS from third-party CDNs
- Not needed for self-hosted assets (you control them)

### Anti-patterns
- Third-party scripts without SRI (CDN compromise = your users are compromised)
- SRI on assets that change frequently without version pinning (hash mismatch = broken site)

---

## 7. Sensitive Data Exposure (Client-Side)

### Never expose in client code
- API keys with write permissions (read-only public keys are OK — e.g., Stripe publishable key)
- Backend secrets, database connection strings
- Internal API URLs that should not be public
- User data of OTHER users (API returning more than needed)

### Where data leaks
- JavaScript bundles (secrets in env vars bundled at build time — visible in DevTools)
- Network tab (API responses with excessive data)
- Error messages (stack traces, internal paths in production)
- Browser history / URL (sensitive data in query params)
- Console logs left in production

### Principles
- **Build-time env vars are PUBLIC** — anything in `NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*` is in the bundle
- **Only include what the client needs** — backend should return minimal data, not full objects
- **Strip console.log in production** — use build plugin or linter rule

---

## 8. Third-Party Scripts

### Risks
- Analytics, ads, chat widgets, A/B testing scripts — all run with full access to your page
- One compromised third-party = access to your users' data (Magecart attacks on payment pages)

### Principles
- **Audit third-party scripts** — know what each one does and what data it accesses
- **CSP restricts what they can do** — `connect-src` limits where they can send data
- **Load non-critical scripts async/defer** — don't block page render
- **Subresource Integrity** on CDN-loaded libraries
- **Sandbox iframes** for third-party widgets (`sandbox` attribute)
- **Payment pages: minimize third-party scripts** — PCI DSS requires this

### Anti-patterns
- 15 third-party scripts on a payment page (each is an attack surface)
- No CSP to restrict third-party behavior
- Third-party scripts loaded synchronously blocking render
- "We trust them" without auditing what data they collect

---

## 9. Communicating with the Backend (Client-Side Limitations)

The frontend cannot prove its identity to the server cryptographically. Understanding what the client CAN and CANNOT guarantee.

For server-side enforcement (CORS config, gateway security, defense in depth), see [`../../backend-engineering/secure-coding/`](../../backend-engineering/secure-coding/README.md) §5.13.

### What the browser guarantees
- **`Origin` header is truthful** — the browser sets it automatically, JavaScript cannot override it
- **CORS is enforced** — if the server doesn't allow your origin, the browser blocks the response
- **Cookies follow their flags** — `HttpOnly` cookies are invisible to JS, `SameSite` cookies aren't sent cross-site
- **Referrer-Policy is respected** — `Referer` header follows the policy

### What the browser does NOT guarantee
- That the request comes from YOUR frontend (anyone can open DevTools and copy the request)
- That the user hasn't modified the payload (request body, headers, query params)
- That client-side validation was executed (it can be bypassed entirely)
- That the JWT/token hasn't been extracted and used elsewhere

### Frontend responsibilities
- **Send the `Authorization` header** (JWT) or rely on `HttpOnly` cookies — the gateway validates it
- **Don't embed secret API keys** — if the backend needs a secret key to call an external API, the frontend calls the backend, not the external API directly
- **Trust the gateway to reject bad origins** — frontend doesn't need to "prove" itself, the browser + CORS + gateway handle it
- **Handle auth failures gracefully** — 401 → redirect to login, 403 → show "not authorized"

### The frontend's role in the security chain
```
Frontend: sends request with auth token
  ↓
Browser: attaches Origin header (unforgeable in browser context)
  ↓
API Gateway: validates Origin + JWT + rate limit
  ↓
Backend: validates authorization (user X can do action Y on resource Z)
  ↓
External API: backend calls with secret key (frontend never sees it)
```

The frontend is the first link, not the security boundary. Its job is to send the right credentials and handle responses — not to enforce security.

### Anti-patterns
- Frontend trying to hide API endpoints (all URLs visible in Network tab)
- Frontend encrypting payloads "for security" (if TLS is in place, this adds nothing)
- Frontend validating permissions client-side and trusting the result (bypasseable)
- Storing secret keys in the frontend "temporarily" (no such thing — it's public the moment it's shipped)

---

## Tooling

| Tool | What it does |
|---|---|
| **DOMPurify** | Sanitize HTML safely (XSS prevention) |
| **helmet** (Express) | Set security headers (CSP, HSTS, X-Frame-Options) — server-side |
| **csp-evaluator** (Google) | Evaluate CSP strength |
| **Report URI / Sentry CSP** | Collect CSP violation reports |
| **eslint-plugin-security** | Security-related lint rules |
| **npm audit / Snyk** | Dependency vulnerability scanning |
| **Observatory** (Mozilla) | Website security assessment |

---

## References

- [OWASP — XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Scripting_Prevention_Cheat_Sheet.html)
- [MDN — Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [MDN — SameSite cookies](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite)
- [web.dev — Security](https://web.dev/security/)
