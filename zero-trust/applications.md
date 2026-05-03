# Applications & Workloads Pillar

**Dev relevance: HIGH** — developers build, secure, and deploy applications. This pillar is almost entirely dev-owned.

---

## What CISA Requires

Manage and secure applications with granular access controls, integrated threat protections, and secure development practices.

### Functions
- Application access (authorization per request)
- Application threat protections (runtime security)
- Accessible applications (secure by default, internally and externally)
- Application security testing (SAST, DAST, SCA in pipeline)
- Secure development and deployment workflow (immutable workloads, CI/CD security)

---

## Maturity Levels

### Traditional
- Coarse-grained access control (all-or-nothing per application)
- No runtime threat protection
- Applications accessible via VPN (network location = access)
- Ad-hoc security testing (manual, before release)
- No standardized development/deployment workflow

### Initial
- Application-level authentication and basic authorization
- Some security testing integrated in CI/CD (SAST or SCA)
- Applications accessible without VPN (identity-based, not network-based)
- Basic WAF on public-facing applications
- Standardized deployment pipeline

### Advanced
- Granular authorization per resource/action (RBAC/ABAC per endpoint)
- SAST, SCA, and DAST integrated in CI/CD pipeline
- Runtime application protection (RASP or WAF with custom rules)
- Immutable deployments (containers, no SSH to production)
- API gateway with centralized auth enforcement
- Service-to-service authentication

### Optimal
- Continuous authorization (real-time risk evaluation per request)
- Automated security testing with policy gates (build fails on critical findings)
- Full immutable workloads (no manual changes in any environment)
- Application behavior analytics (detect anomalous API usage patterns)
- Software supply chain security (signed artifacts, SBOM, provenance)
- Zero standing privileges for applications (just-in-time access to resources)

---

## What Developers Own

### Application Access Control

Every API endpoint / application route must enforce authorization independently.

| Practice | Traditional | Zero Trust |
|---|---|---|
| No auth on internal endpoints | ✅ common | ❌ every endpoint checks auth |
| Auth at gateway only, backend trusts | — | ❌ both must validate |
| Auth per endpoint, checked server-side | — | ✅ minimum |
| Context-aware auth (user + device + time + risk) | — | ✅ advanced/optimal |

**Dev actions:**
- Implement authorization middleware — every route has an auth check (no exceptions)
- Gateway validates JWT/token. Backend ALSO validates and checks fine-grained permissions
- Don't trust headers from the gateway blindly (`X-User-Id` can be spoofed if gateway is bypassed)
- Verify the token cryptographically in the backend, don't just read claims

### Secure Development Lifecycle

| Practice | Traditional | Zero Trust |
|---|---|---|
| Manual security review before release | ✅ common | ❌ too late, too slow |
| SAST in CI/CD | — | ✅ initial |
| SAST + SCA + secret scanning in CI/CD | — | ✅ advanced |
| SAST + SCA + DAST + signed artifacts + SBOM | — | ✅ optimal |
| Policy gates (build fails on critical) | — | ✅ advanced/optimal |

**Dev actions:**
- Integrate security scanning in pipeline — see `../backend-engineering/ci-cd/` §7 (Pipeline Security)
- Generate SBOM (Software Bill of Materials) — `syft`, `trivy sbom`
- Sign container images — `cosign`
- Fail the build on critical/high vulnerabilities (not just report)
- See `../backend-engineering/secure-coding/` for the full 12-area security reference

### Immutable Workloads

| Practice | Traditional | Zero Trust |
|---|---|---|
| SSH to production to patch/configure | ✅ common | ❌ no manual changes |
| Mutable servers (snowflakes) | ✅ common | ❌ no two servers should differ |
| Container image built once, deployed everywhere | — | ✅ advanced |
| No SSH/exec into production containers | — | ✅ optimal |
| All changes go through CI/CD — no exceptions | — | ✅ optimal |

**Dev actions:**
- No `kubectl exec` in production (debug via logs, traces, not shell access)
- No config changes outside of IaC/CI/CD
- Containers are immutable — rebuild and redeploy, don't patch in place
- See `../backend-engineering/iac/` §11 (Dockerfile) and `../backend-engineering/ci-cd/` §3 (Build Artifacts)

### API Security (Zero Trust Perspective)

Beyond what's in `../backend-engineering/secure-coding/` §5.10 and §5.13:

- **Every API is "internet-accessible" by default** — treat internal APIs with the same security posture as public ones
- **No implicit trust between services** — service A calling service B must authenticate (see identity.md — Service Identity)
- **Input validation at every boundary** — even between internal services (compromised service A shouldn't be able to inject into service B)
- **Rate limiting per service, not just per user** — one compromised service shouldn't be able to DoS another

### Supply Chain Security

| Practice | Traditional | Zero Trust |
|---|---|---|
| `npm install` without audit | ✅ common | ❌ scan dependencies |
| Base images unpinned (`:latest`) | ✅ common | ❌ pin + scan |
| No artifact signing | ✅ common | ❌ sign everything |
| No SBOM | ✅ common | ❌ generate and store |

**Dev actions:**
- Pin dependencies (lockfiles committed)
- Scan dependencies in CI (SCA) — see `../backend-engineering/secure-coding/` §5.6
- Pin and scan base images — see `../backend-engineering/iac/` §11
- Sign artifacts (cosign) and verify before deploy
- Generate SBOM per release
- See `../backend-engineering/ci-cd/` §7 (Pipeline Security) for SLSA framework

---

## Anti-patterns

- Internal APIs without authentication ("it's behind the firewall")
- Gateway does auth, backend trusts blindly (gateway bypass = full access)
- SSH into production to "fix something quick" (mutable, untracked, unreproducible)
- Security testing only before major releases (should be every PR)
- No SBOM (can't answer "are we affected?" when a CVE drops)
- Unsigned artifacts (can't verify what's actually running in production)
- Standing admin access to all applications (should be JIT/JEA)

---

## References

- [CISA ZTMM — Applications & Workloads](https://learn.microsoft.com/en-us/security/zero-trust/cisa-zero-trust-maturity-model-apps)
- [SLSA Framework](https://slsa.dev/)
- [Sigstore / cosign](https://www.sigstore.dev/)
- [OWASP SAMM — Software Assurance Maturity Model](https://owaspsamm.org/)
