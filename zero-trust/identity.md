# Identity Pillar

**Dev relevance: HIGH** — developers build authentication, authorization, session management, and service identity.

---

## What CISA Requires

The Identity pillar ensures the right users and entities access the right resources at the right time with the right privileges.

### Functions
- Authentication
- Identity stores / user management
- Risk assessment for identity decisions
- Access management (authorization)
- Identity lifecycle (provisioning, deprovisioning)

---

## Maturity Levels

### Traditional
- Password-based or basic MFA
- Static roles and permissions
- Manual user provisioning/deprovisioning
- Limited identity risk assessment
- Separate identity stores per application (no SSO)

### Initial
- MFA on all user-facing systems
- Centralized identity provider (IdP) — SSO
- Basic RBAC implemented
- Some automated provisioning
- Identity inventory started

### Advanced
- Phishing-resistant MFA (FIDO2/WebAuthn, hardware keys) — no SMS/email OTP for sensitive systems
- Context-aware access (device, location, time, behavior influence access decisions)
- Automated provisioning and deprovisioning (SCIM)
- Service accounts identified and scoped
- Privileged access management (PAM) for admin accounts
- Session re-validation on sensitive operations (step-up auth)

### Optimal
- Continuous identity validation (not just at login — re-evaluate risk throughout session)
- User and Entity Behavior Analytics (UEBA) — detect anomalies in real-time
- Just-in-time / just-enough access (JIT/JEA) — privileges granted only when needed, revoked automatically
- Dynamic group membership based on context
- Full lifecycle automation — onboard, role change, offboard without manual intervention
- Passwordless authentication as default

---

## What Developers Own

### Authentication (who you are)

| Practice | Traditional | Zero Trust |
|---|---|---|
| Password only | ✅ common | ❌ never sufficient |
| MFA (SMS/email OTP) | — | ✅ initial, but phishable |
| MFA (TOTP app) | — | ✅ better |
| MFA (FIDO2/WebAuthn) | — | ✅ optimal — phishing-resistant |
| Passwordless (passkeys) | — | ✅ optimal |

**Dev actions:**
- Integrate with IdP (Auth0, Cognito, Keycloak, Okta) — don't build auth from scratch
- Implement MFA at the application level (or delegate to IdP)
- Support phishing-resistant methods (WebAuthn) for sensitive operations
- Step-up authentication: re-prompt MFA for sensitive actions (change password, payment, delete account)

### Authorization (what you can do)

| Practice | Traditional | Zero Trust |
|---|---|---|
| Static RBAC (admin/user) | ✅ common | ✅ starting point |
| Attribute-Based Access Control (ABAC) | — | ✅ advanced (role + context) |
| Policy-as-code (OPA, Cedar) | — | ✅ advanced/optimal |
| Just-in-time access (JIT) | — | ✅ optimal |

**Dev actions:**
- Implement RBAC at minimum — every endpoint checks permissions
- Move toward ABAC for complex scenarios (role + department + resource owner + time)
- Evaluate policy engines (OPA/Rego, AWS Cedar, Casbin) for centralized authorization
- Never hardcode roles in business logic (`if user.role == "admin"`) — use a policy layer

### Session Management

| Practice | Traditional | Zero Trust |
|---|---|---|
| Long-lived sessions (days/weeks) | ✅ common | ❌ reduce to hours |
| Session rotation on auth state change | — | ✅ (login, MFA, privilege change) |
| Continuous session validation | — | ✅ optimal (re-check context periodically) |
| Token binding to device/IP | — | ✅ advanced |

**Dev actions:**
- Short session TTL (hours, not days) with refresh tokens
- Invalidate sessions on: password change, MFA enrollment, role change, suspicious activity
- Bind tokens to context where possible (IP, user agent — detect stolen tokens)
- Implement session revocation (user clicks "sign out all devices" → all tokens invalid immediately)

### Service Identity (service-to-service)

| Practice | Traditional | Zero Trust |
|---|---|---|
| No auth between internal services | ✅ common ("it's internal") | ❌ biggest zero trust gap |
| Shared API key for all services | — | ❌ no granularity |
| JWT/mTLS per service | — | ✅ advanced |
| Workload identity (SPIFFE/SPIRE) | — | ✅ optimal |

**Dev actions:**
- Every service-to-service call is authenticated (JWT, mTLS, or workload identity)
- Each service has its own identity (not one shared key)
- Scoped permissions per service (service A can call service B's endpoint X, not everything)
- Service mesh (Istio, Linkerd) can handle mTLS transparently — dev doesn't add code, infra configures

### Non-Person Entities (NPE)

API keys, service accounts, CI/CD tokens, automated processes — all need identity management:
- Scoped to minimum permissions
- Short-lived where possible (OIDC tokens for CI/CD, not long-lived PATs)
- Rotated on schedule
- Inventoried and owned (who is responsible for this service account?)

---

## Anti-patterns

- No MFA on production systems (single factor = compromised by phishing)
- Internal services trust each other implicitly ("it's behind the VPN")
- Admin accounts without PAM/MFA (lateral movement is trivial)
- Service accounts with admin permissions and no rotation
- Users provisioned but never deprovisioned (former employees still have access)
- Static tokens that never expire (CI/CD PATs from 3 years ago still active)
- Authorization logic duplicated across services (inconsistent enforcement)
- No step-up auth for sensitive operations (changing email and deleting account use same auth level as viewing profile)

---

## Tooling

| Tool | What it does |
|---|---|
| **Auth0 / Okta / Cognito / Keycloak** | Identity provider (SSO, MFA, social login) |
| **FIDO2 / WebAuthn** | Phishing-resistant authentication standard |
| **OPA (Open Policy Agent)** | Policy-as-code authorization engine |
| **AWS Cedar** | Policy-as-code for fine-grained authorization |
| **Casbin** | Authorization library (RBAC, ABAC, multi-language) |
| **SPIFFE / SPIRE** | Workload identity for service-to-service |
| **Vault** | Dynamic secrets, service identity, PKI |

---

## References

- [CISA ZTMM — Identity Pillar](https://learn.microsoft.com/en-us/security/zero-trust/cisa-zero-trust-maturity-model-identity)
- [NIST SP 800-63 — Digital Identity Guidelines](https://pages.nist.gov/800-63-4/)
- [FIDO Alliance — WebAuthn](https://fidoalliance.org/fido2/fido2-web-authentication-webauthn/)
- [SPIFFE — Secure Production Identity Framework](https://spiffe.io/)
