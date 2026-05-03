# Secure Coding Best Practices

Principles and practices for building secure software, applicable to any language (Go, Rust, Java, Python, TypeScript) and any organization.

---

## 1. Shift-Left Security in the SDLC

Embed security as early as possible — don't wait until the end.

### Requirements
- Define security and compliance requirements early: data classification, access controls, encryption, logging.
- Initiate **threat modeling** to identify risks and document required security controls before design begins.

### Design
- Use threat modeling outcomes to design secure architectures and mitigate identified risks.
- Prepare required artifacts: architecture diagrams, security checklists, cloud control reviews.

### Configuration
- Establish secure configurations for environments, platforms, and services before development.
- Apply approved baseline configurations, enforce least privilege.
- Ensure secrets, keys, and credentials are managed through secret-management tools — never hardcoded.

### Development
- Build using secure coding practices and approved frameworks.
- Perform code reviews and automated scans (SAST/SCA) to identify vulnerabilities.
- Ensure dependencies are approved, current, and free of known risks.

### Testing
- Conduct security testing alongside functional testing: static (SAST), dynamic (DAST), and vulnerability scanning.
- Document and remediate findings based on risk severity before release.

### Deployment
- Release through CI/CD pipelines with required security checks integrated.
- Validate that logging, monitoring, and alerting are enabled and operational.

### Maintenance
- Continuously monitor for vulnerabilities, security events, and configuration drift.
- Apply patches, update dependencies, reassess risk after changes.

---

## 2. Secure Development Pipeline

A generalized secure development flow:

```
Developer → Threat Modeling → Source Code → Source Control (CI/CD) → SAST/SCA → Production → DAST → Bug Bounty/VDP
```

| Stage | What happens |
|---|---|
| **Developer** | Writes secure code following coding standards throughout the SDLC |
| **Threat Modeling** | Identifies risks, attack paths, and required security controls at requirements phase |
| **Source Code** | Must follow secure coding standards; no hardcoded secrets, credentials, or sensitive data |
| **Source Control + CI/CD** | Security checks integrated into pipelines (pre-commit hooks, automated scans) |
| **SAST / SCA** | Static analysis to identify insecure code patterns and vulnerable dependencies. Issues must be resolved before deployment |
| **Production** | Only code that meets security, testing, and approval requirements gets deployed |
| **DAST** | Dynamic testing on deployed applications to find runtime vulnerabilities |
| **Bug Bounty / VDP** | External vulnerability disclosure program — triage and remediate per policy |

---

## 3. Secure Coding Process

Three steps that catch vulnerabilities before production:

### Step 1 — Threat Modeling
- Kick off during requirements/discovery phase.
- Identify risks, attack vectors, and design-level controls before coding begins.

### Step 2 — Code Reviews
- Begin once a repository exists; repeat for every major feature, sprint, or release.
- Peer reviews validate secure coding practices, check for unvalidated inputs, and enforce standards.

### Step 3 — Security Testing
- **SAST** (Static): run any time code is committed; rerun with each iteration or change.
- **DAST** (Dynamic): run once the app is deployed to test/production; repeat for each significant release.

---

## 4. CIA Triad

The three pillars guiding security decisions:

| Principle | What it means |
|---|---|
| **Confidentiality** | Only authorized users access sensitive data. Enforce least privilege, encryption, access controls. |
| **Integrity** | Data remains accurate and untampered. Ensure trust through validation, checksums, audit trails. |
| **Availability** | Applications are consistently accessible to authorized users. Design for operational reliability. |

---

## 5. Security Areas

Comprehensive reference of what to protect against. Based on OWASP Top 10 (2025), OWASP API Security Top 10, CWE/SANS Top 25, and practical experience.

### 5.1 Injection

All external input that gets interpreted as code or commands.

- **SQL injection**: string concatenation in queries instead of parameterized queries [CWE-89]
- **Command / OS injection**: user input passed to shell commands or exec calls [CWE-78]
- **XSS (Cross-Site Scripting)**: reflected, stored, DOM-based — user input rendered as HTML/JS [CWE-79]
- **Server-Side Template Injection (SSTI)**: user input evaluated by template engines [CWE-1336]
- **NoSQL injection**: manipulating NoSQL query operators via user input [CWE-943]
- **LDAP injection**: crafted input altering LDAP queries [CWE-90]
- **Header injection**: injecting headers via user-controlled values (CRLF injection) [CWE-113]
- **Log injection**: crafted input that manipulates log entries to deceive SIEM or hide attacks [CWE-117]

**Parameterized query examples:**
```go
// Go — database/sql
db.QueryRow("SELECT * FROM users WHERE id = $1", userID)
```
```python
# Python — psycopg2 / SQLAlchemy
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```
```java
// Java — PreparedStatement
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
ps.setInt(1, userId);
```
```typescript
// TypeScript — Prisma / parameterized
await prisma.user.findUnique({ where: { id: userId } })
```

### 5.2 Authentication & Identity

Everything that validates "who you are".

- Weak or default passwords allowed [CWE-521]
- Missing MFA on sensitive operations [CWE-308]. Prefer phishing-resistant MFA (FIDO2/WebAuthn) over SMS/email OTP.
- Brute force / credential stuffing without protection (rate limiting, lockout) [CWE-307]
- Insecure password storage (MD5, SHA1, unsalted hashes). Use bcrypt, scrypt, or Argon2. [CWE-916]
- Broken session management: tokens without expiration, without rotation on auth state changes [CWE-613]
- Insecure password recovery flows (predictable tokens, no expiry) [CWE-640]
- JWT misuse: `alg:none` accepted, weak signing secret, missing expiration, no audience validation [CWE-347]
- Session cookies missing HttpOnly, Secure, SameSite flags [CWE-614]
- No step-up authentication: sensitive operations (password change, payment, delete account) should re-prompt MFA, not rely on session alone
- No continuous session validation: sessions should be re-evaluated on context changes (new IP, new device, privilege escalation) — not just validated at login
- No service-to-service authentication: internal services must authenticate each other (mTLS, JWT, workload identity via SPIFFE/SPIRE) — "it's internal" is not authentication [CWE-306]
- Passwordless not considered: FIDO2/passkeys are the direction — more secure and better UX than passwords + MFA

See `../../zero-trust/identity.md` for the full zero trust perspective on authentication and identity.

### 5.3 Authorization & Access Control

Everything that validates "what you can do".

- **BOLA / IDOR**: accessing another user's data by changing an ID in the request [CWE-639] [OWASP API #1]
- **Broken Function-Level Authorization**: accessing admin endpoints without admin role [CWE-285] [OWASP API #5]
- **Privilege escalation**: horizontal (user A accesses user B's data) and vertical (user becomes admin) [CWE-269]
- Missing or overly permissive RBAC [CWE-285]
- CORS misconfiguration (wildcard origins with credentials) [CWE-942]. See §5.13 for CORS and origin validation in depth.
- CSRF (Cross-Site Request Forgery): state-changing requests without anti-CSRF tokens [CWE-352]
- Missing authorization checks on individual object/resource access [CWE-862]
- No authorization on internal APIs: every endpoint must enforce auth — internal services are not exempt
- Authorization model too coarse: RBAC is a starting point, not the end. Progression: **RBAC → ABAC → FGA (Fine-Grained Authorization)**
  - **RBAC**: role-based (admin/user) — simplest, sufficient for basic cases
  - **ABAC**: attribute-based (role + department + time + resource owner) — for context-aware decisions
  - **FGA**: fine-grained (ReBAC + ABAC) — relationship-based (owner, editor, viewer) + attributes. Tools: OpenFGA, SpiceDB, AWS Cedar, OPA
- No policy-as-code: authorization logic hardcoded (`if user.role == "admin"`) instead of externalized to a policy engine (OPA/Rego, Cedar, Casbin)
- No just-in-time access (JIT/JEA): standing privileges that are always active instead of granted only when needed and revoked automatically

See `../../zero-trust/identity.md` for the full zero trust perspective on authorization.

### 5.4 Data Protection & Cryptography

Everything that protects data confidentiality and integrity.

- Missing encryption in transit (TLS 1.2+ required) [CWE-319]
- Missing encryption at rest (AES-256) [CWE-311]
- Weak cryptographic algorithms: DES, RC4, MD5 for hashing, SHA1 for signatures [CWE-327]
- Insecure random number generation (using `math/rand` instead of `crypto/rand` in Go) [CWE-338]
- Static IVs / reused nonces in encryption [CWE-329]
- Secrets hardcoded in source code, logs, config files, or environment variables without a secret manager [CWE-798]
- PII/PHI/NPI exposed in logs, error messages, URLs, or query strings [CWE-532]
- Sensitive data in browser localStorage (accessible to XSS) [CWE-922]
- Missing key rotation policies [CWE-320]. Automate rotation — manual rotation = rotation never happens.
- No field-level encryption: disk-level encryption protects against physical theft but the application (and any compromised service) sees plaintext. Sensitive fields (SSN, card numbers, health data) should be encrypted at the application level before storage.
- Internal traffic not encrypted: TLS required between ALL services, not just external-facing. "Internal network" is not a security boundary. See `../../zero-trust/networks.md`.

See `../../zero-trust/data.md` for the full zero trust perspective on data protection.

### 5.5 Input & Output Handling

Beyond injection — how you handle data flowing in and out.

- Missing input validation / sanitization on all user-facing endpoints [CWE-20]
- **Mass assignment**: binding request body directly to model, allowing users to set fields they shouldn't (e.g., `role`, `isAdmin`) [CWE-915]
- **Excessive data exposure**: API responses returning more fields than the consumer needs [OWASP API #3]
- **Path traversal**: `../../etc/passwd` via file path parameters [CWE-22]
- **Unrestricted file upload**: no validation on file type, size, or content [CWE-434]
- **Open redirects**: redirect URLs controlled by user input [CWE-601]
- **Unsafe deserialization**: deserializing objects from untrusted input (critical in Java, Python pickle) [CWE-502]

### 5.6 Supply Chain & Dependencies

Everything you didn't write but execute.

- Dependencies with known CVEs (check go.mod, package.json, requirements.txt, Cargo.toml) [CWE-1104]
- **Typosquatting**: malicious package with a name similar to a legitimate one [CWE-427]
- **Lockfile manipulation**: attacker modifies lockfile to point to compromised versions [CWE-494]
- Unsigned packages / unverified sources [CWE-494]
- Outdated dependencies without patches [CWE-1104]
- **Transitive vulnerabilities**: the dependency of your dependency has a CVE [CWE-1104]
- **CI/CD pipeline poisoning**: compromised build steps, injected commands in CI config [CWE-829]

### 5.7 Configuration & Infrastructure

How your systems are configured.

- Default credentials on services, databases, admin panels [CWE-798]
- Unnecessary features/services/ports enabled in production [CWE-1188]
- Exposed admin panels, debug endpoints, health checks leaking sensitive info [CWE-200]
- Missing security headers (Content-Security-Policy, Strict-Transport-Security, X-Frame-Options, X-Content-Type-Options) [CWE-693]
- Open ports beyond what's required [CWE-284]
- **Privileged containers**: Docker running as root, no resource limits [CWE-250]
- K8s misconfigs: no network policies, no pod security standards, secrets in env vars [CWE-16]
- Terraform/IaC misconfigs: public S3/GCS buckets, overly permissive IAM, no state encryption [CWE-16]
- Cloud storage publicly accessible [CWE-284]

### 5.8 Error Handling & Resilience

How your system fails.

- **Fail-open vs fail-closed**: if auth/authz fails, does the system allow or deny? Always fail-closed. [CWE-636]
- Verbose error messages exposing internals to clients (stack traces, DB names, internal paths) [CWE-209]
- Unhandled panics/exceptions that crash the service [CWE-248]
- **Resource exhaustion**: memory leaks, goroutine leaks, connection pool exhaustion, thread starvation [CWE-400]
- Missing rate limiting / throttling on public endpoints [CWE-770]
- Missing circuit breakers for external dependencies [CWE-400]
- **Denial of Service via input**: catastrophic regex backtracking (ReDoS), billion laughs (XML), zip bombs [CWE-1333] [CWE-776]
- No graceful degradation under load [CWE-400]

### 5.9 Logging, Monitoring & Incident Response

What you know when something happens.

- Missing audit logs: who accessed what data, when, from where [CWE-778]
- Logging PII/PHI/NPI in plaintext [CWE-532]
- **No alerting**: logs exist but no one watches them — detection takes weeks [CWE-778]
- **Log tampering**: logs stored in a location the attacker can modify [CWE-117]
- Missing incident response plan
- Missing breach notification process (required by HIPAA: 60 days, CCPA: expeditiously)
- Insufficient log retention for forensics [CWE-779]
- No correlation between security events across services (missing distributed tracing for security)
- Auth events not logged explicitly: login, logout, MFA challenge, failed attempts, token refresh, privilege changes — all must be logged with context (user, IP, device, result)
- No access logging for sensitive data: who queried what PII/PHI/NPI records, when, from which service — required for compliance and incident forensics
- No security-specific metrics: auth failure rate (brute force detection), authorization denial rate (privilege escalation attempts), token anomalies (same token from different IPs/devices)

See `../../zero-trust/cross-cutting.md` §1 (Visibility & Analytics) for the full zero trust perspective.

### 5.10 API-Specific Security

For REST, gRPC, GraphQL APIs.

- **BOLA / IDOR** — the #1 API vulnerability: accessing resources by manipulating IDs [CWE-639] [OWASP API #1]
- Broken authentication on API endpoints (missing token validation, weak API keys) [OWASP API #2]
- **Excessive data exposure**: returning full objects instead of projections [OWASP API #3]
- **Unrestricted resource consumption**: no rate limiting, no pagination limits, no query depth limits (GraphQL) [OWASP API #4]
- Broken function-level authorization: accessing admin APIs without proper role [OWASP API #5]
- **Mass assignment**: auto-binding all request fields to internal models [CWE-915] [OWASP API #6]
- **SSRF (Server-Side Request Forgery)**: the API makes requests to URLs controlled by the attacker [CWE-918]
- **Unsafe consumption of third-party APIs**: trusting external API responses without validation [OWASP API #10]
- Missing API versioning leading to breaking changes in security controls
- No API gateway / no centralized auth enforcement. See §5.13 for gateway security patterns.

### 5.11 Concurrency & Memory Safety

Specific to Go, Rust, Java, Python (async).

- **Race conditions (TOCTOU)**: time-of-check vs time-of-use — checking a condition then acting on it without atomicity [CWE-367]
- **Double-spend / double-submit**: missing idempotency keys on financial or state-changing operations [CWE-367]
- **Data races**: shared mutable state accessed from multiple goroutines/threads without synchronization [CWE-362]
- **Deadlocks**: circular lock dependencies [CWE-833]
- **Buffer overflow / out-of-bounds writes**: primarily C/C++, but Go's `unsafe` package and Rust's `unsafe` blocks can introduce these [CWE-120]
- **Goroutine / thread leaks**: spawning without proper lifecycle management [CWE-401]
- Missing mutex/lock on shared resources in concurrent handlers [CWE-362]

### 5.12 Data Privacy & Compliance

The legal framework — covered in depth in `../data-privacy/README.md`.

- **HIPAA**: health data — encryption, access controls, audit trails, BAA, breach notification
- **GLBA**: financial data — safeguards rule, encryption, incident response
- **CCPA/CPRA**: personal data — right to delete, export, opt-out, consent management
- **FERPA**: education data — access controls, consent for disclosure
- **COPPA**: children's data — parental consent, data minimization
- Data classification (public, internal, confidential, restricted)
- Data retention policies enforced programmatically
- Data inventory — know where PII lives across all systems

### 5.13 CORS & API Gateway Security

How to protect your API from unauthorized clients — server-side enforcement.

#### CORS Configuration (Server-Side)

CORS is not just browser headers — the server should actively validate and reject:

- **Whitelist allowed origins** — explicit list (`https://myapp.com`), never wildcard `*` with credentials
- **Validate Origin header in middleware** — reject requests with wrong or missing Origin BEFORE processing (don't just send CORS response headers and hope the browser enforces)
- **Don't reflect Origin blindly** — some implementations echo back whatever Origin the client sends. This is equivalent to `*`.
- **Separate CORS config per environment** — dev allows `localhost`, production only allows your domain(s)
- **Preflight caching** — set `Access-Control-Max-Age` to reduce OPTIONS requests (86400s / 24h)

#### API Gateway as Security Layer

The gateway is the single entry point — enforce security here, not in each backend service:

| Layer | What it enforces |
|---|---|
| **Origin validation** | Reject requests from unknown origins (active, not just CORS headers) |
| **Authentication** | Validate JWT / session before forwarding to backend |
| **Rate limiting** | Per API key, per user, per IP — prevent abuse |
| **Client identification** | API key identifies which client (web, mobile, partner) — not a secret, just identity |
| **Request validation** | Reject malformed requests before they reach backend |

#### Defense in Depth (no single layer is enough)

```
1. CORS + Origin validation    → blocks other websites in browsers
2. JWT / session auth          → blocks unauthenticated requests
3. Rate limiting               → blocks volume-based abuse
4. Client API key              → identifies and tracks callers
5. Monitoring + anomaly detection → detects what the other layers miss
```

#### What each layer does NOT protect against

| Layer | Limitation |
|---|---|
| **CORS / Origin** | Bypasseable outside browser (curl, scripts can fake Origin header) |
| **JWT** | If stolen (XSS), attacker has full access until expiry |
| **Rate limiting** | Distributed attack from many IPs can circumvent per-IP limits |
| **Client API key** | Public — anyone can extract it from the frontend bundle |

No single layer is sufficient. Combined, they make unauthorized access expensive and detectable.

#### Anti-patterns
- CORS with `Access-Control-Allow-Origin: *` and `Access-Control-Allow-Credentials: true` (allows any site to make authenticated requests) [CWE-942]
- Origin validation only via CORS headers (server processes the request anyway — just hopes browser blocks the response)
- No API gateway (every backend service implements its own auth, rate limiting, CORS — inconsistent)
- API key as sole authentication (keys are public in frontend — not a security boundary)
- Gateway without rate limiting (one client can exhaust backend resources)
- No monitoring on gateway (abuse happens undetected for days)

---

## 6. Security Compliance Checklist

Questions every team should answer before going to production:

### Data Protection
- Is all sensitive data encrypted both **in transit** (TLS) and **at rest**?
- Are secrets, keys, and credentials stored only in approved secret-management services and **never** in code, logs, or config files?

### Secure Infrastructure
- Are base images hardened and vulnerability-scanned (CIS benchmarks)?
- Are network ports limited to only those required? Are exceptions documented?

### Identity and Access
- Is authentication using industry standards (OAuth 2.0, OIDC, JWT)?
- Is access governed by least privilege and role-based access control (RBAC)?
- Are service accounts scoped to minimum required permissions?

### Monitoring and Recovery
- Are application and security logs routed to a centralized logging system?
- Does the application have a Disaster Recovery plan (multi-zone/multi-region)?
- Are alerts configured for security events?

### Vulnerability Management
- Has the environment been scanned for vulnerabilities and misconfigurations?
- Are scan results triaged and remediated on a defined timeline?
- Are dependencies regularly audited for known CVEs?

---

## 7. Security Assessment Before Production

Before deploying to production, validate security through a structured assessment:

1. **Request Intake** — Submit application profile early in design: data classification, architecture diagrams, environments, system owners.
2. **Control Attestation** — Complete attestations with evidence: encryption, key management, IAM, logging, DR patterns, network restrictions.
3. **Kickoff / Alignment** — Review submitted materials, confirm scope, align on control interpretations.
4. **Review and Scanning** — Perform vulnerability and configuration scanning. Validate findings, remediate as needed.
5. **Final Report** — Critical and high findings must be remediated before production. Once verified, authorize for production.

---

## 8. Security Tooling Categories

| Category | Purpose | Example Tools |
|---|---|---|
| **SAST** (Static Analysis) | Identify insecure code patterns at build time | SonarQube, Semgrep, gosec (Go), Bandit (Python), SpotBugs (Java), clippy (Rust) |
| **SCA** (Software Composition Analysis) | Find vulnerable dependencies | Trivy, govulncheck (Go), cargo-audit (Rust), pip-audit (Python), npm audit (JS/TS) |
| **DAST** (Dynamic Analysis) | Test running applications for vulnerabilities | OWASP ZAP, Burp Suite, Invicti |
| **Secret Scanning** | Detect hardcoded secrets in code and git history | Gitleaks, TruffleHog |
| **Container Scanning** | Scan container images for CVEs | Trivy, Grype |
| **IaC Scanning** | Find misconfigurations in Terraform, K8s, Dockerfiles | Trivy, Checkov, tfsec |
| **CI/CD Pipeline Security** | Scan pipeline configs (GitHub Actions, CircleCI, GitLab CI) for misconfigs and injection risks | Orca, Checkov, StepSecurity, Harden-Runner |
| **Shell / Script Analysis** | Detect issues in bash/shell scripts embedded in repos | ShellCheck, Semgrep |
| **Dependency Policy** | Enforce license and ban rules on dependencies | cargo-deny (Rust), OWASP dependency-check (Java) |
| **Fuzzing** | Discover crashes and edge cases via random input | cargo-fuzz (Rust), go-fuzz (Go) |
| **Bug Bounty / VDP** | External vulnerability disclosure | HackerOne, Bugcrowd |

---

## References

- [OWASP Top 10 (2025)](https://owasp.org/Top10/2025/)
- [OWASP API Security Top 10](https://owasp.org/API-Security/)
- [CWE Top 25 Most Dangerous Software Weaknesses (2025)](https://cwe.mitre.org/top25/archive/2025/2025_cwe_top25.html)
- [OWASP Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- [NIST Secure Software Development Framework](https://csrc.nist.gov/projects/ssdf)

For the well-architected perspective on security, see [`../../well-architected/security.md`](../../well-architected/security.md). For the zero trust perspective, see [`../../zero-trust/`](../../zero-trust/README.md).
