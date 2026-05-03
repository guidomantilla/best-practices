# Cross-Cutting Capabilities

Three capabilities that span all 5 pillars. Without these, zero trust policies exist but can't be measured, enforced, or adapted.

**Dev relevance: MEDIUM** — developers build the observability, implement policy enforcement, and contribute to governance through code.

---

## 1. Visibility & Analytics

**"You can't protect what you can't see."**

Knowing who accessed what, when, from where, using what device — and whether that behavior is normal.

### Maturity Levels

| Level | What it means |
|---|---|
| **Traditional** | Siloed logs per system, manual review, no correlation |
| **Initial** | Centralized logging (SIEM), basic alerting |
| **Advanced** | Cross-pillar correlation (identity + network + app events), anomaly detection |
| **Optimal** | Real-time analytics, ML-based behavior analysis (UEBA), automated threat detection across all pillars |

### What Developers Own

**Structured logging with security context:**
- Every log includes: who (user_id, service_id), what (action), when (timestamp), where (IP, endpoint), result (success/failure)
- Auth events logged: login, logout, MFA challenge, failed attempts, token refresh, privilege escalation
- Data access logged: who accessed sensitive data, which records, when
- See `../backend-engineering/observability/` for full logging/metrics/tracing reference

**Security-relevant metrics:**
- Authentication failure rate (brute force detection)
- Authorization denial rate (privilege escalation attempts)
- Token refresh rate anomalies (stolen token being used from different locations)
- API error rate by user (one user generating 90% of 403s = suspicious)

**Distributed tracing for security:**
- Trace ID must propagate across all services (correlate one request's journey)
- When an incident occurs, trace shows exactly which services were involved
- See `../backend-engineering/observability/` §8 (Distributed Tracing)

### Anti-patterns
- No centralized logging (logs on individual servers, impossible to correlate)
- Auth events not logged (can't detect brute force, credential stuffing)
- No correlation between identity and application events (know someone logged in, but not what they did)
- Logging PII in plaintext (see `../backend-engineering/observability/` §5)
- No alerting on security events (logs exist but nobody watches)

---

## 2. Automation & Orchestration

**"Zero trust at scale requires automation — manual enforcement breaks."**

Transform static policies into dynamic enforcement. Automate responses across pillars.

### Maturity Levels

| Level | What it means |
|---|---|
| **Traditional** | Manual processes, static rules, human-driven incident response |
| **Initial** | Some automated provisioning, basic automated responses (lock account after N failures) |
| **Advanced** | Policy-as-code, automated incident response, cross-pillar orchestration (device non-compliant → revoke access) |
| **Optimal** | Fully automated, real-time policy enforcement, self-healing, AI-assisted response |

### What Developers Own

**Policy-as-code:**
- Authorization policies defined in code, not in dashboards — see [identity.md](identity.md) (OPA, Cedar, Casbin)
- Infrastructure policies in code — see `../backend-engineering/iac/` (Checkov, OPA/Conftest)
- CI/CD policies in code — see `../backend-engineering/ci-cd/` §7 (Pipeline Security)
- Config as code — see `../backend-engineering/configuration/` §7

**Automated security responses (in application code):**
- Account lockout after N failed auth attempts
- Token revocation on suspicious activity
- Rate limiting escalation (progressive: warn → throttle → block)
- Circuit breaker on compromised dependency — see `../backend-engineering/system-design/integration-level.md` §3
- Automated rollback on security scan failure — see `../backend-engineering/ci-cd/` §6

**Infrastructure automation:**
- Security scanning in CI/CD pipeline (build fails on critical findings)
- Automated dependency updates (Dependabot, Renovate) with security-only auto-merge
- Automated certificate rotation
- See `../backend-engineering/ci-cd/` §7 and `../backend-engineering/iac/` §10

### Anti-patterns
- Policies in wiki documents instead of code (not enforced, not versioned, not tested)
- Manual incident response (takes hours when automated would take seconds)
- No automated lockout (brute force runs indefinitely)
- Security scan results reviewed manually once a month (should block builds immediately)
- Manual certificate management (certs expire, outage at 2am)

---

## 3. Governance

**"Security decisions driven by policy and accountability, not by gut instinct."**

Structure, compliance, and oversight across all pillars.

### Maturity Levels

| Level | What it means |
|---|---|
| **Traditional** | Ad-hoc policies, manual compliance checks, no formal risk management |
| **Initial** | Documented security policies, basic compliance framework, annual audits |
| **Advanced** | Continuous compliance monitoring, risk-based decision making, policies enforced by tooling |
| **Optimal** | Adaptive governance, real-time compliance dashboards, automated policy enforcement and auditing |

### What Developers Own

**Compliance as code:**
- Security requirements encoded in CI/CD pipeline (not just documented)
- Policy gates that prevent non-compliant code from deploying
- Automated compliance evidence generation (audit logs, scan results, access records)
- See `../backend-engineering/secure-coding/` §6 (Security Compliance Checklist)

**Documentation that matters:**
- ADRs (Architecture Decision Records) for security decisions — why we chose X over Y
- Threat models documented and reviewed — see `../backend-engineering/secure-coding/` §3
- Data flow diagrams showing where sensitive data lives and moves
- Incident response playbooks — see `../backend-engineering/secure-coding/` §5.9

**Data governance (dev-relevant):**
- Data classification enforced in code — see [data.md](data.md)
- Data retention policies automated — see `../backend-engineering/data-design/lifecycle.md`
- Privacy compliance implemented — see `../backend-engineering/data-privacy/`
- Data access audit trail — see `../backend-engineering/observability/`

### Anti-patterns
- Compliance is a checkbox exercise once a year (real compliance is continuous)
- Security policies in documents nobody reads (enforce in code or it doesn't exist)
- No threat modeling (security decisions made reactively after incidents)
- No data flow documentation (can't answer "where does PII go?" during an audit)
- Audit evidence gathered manually before audits (should be continuously generated)

---

## How the Three Capabilities Connect

```
Visibility generates signals
  → Automation acts on signals
    → Governance defines the policies that Automation enforces
      → Visibility measures if policies are working
        → cycle repeats
```

Example:
1. **Visibility**: detects user logging in from a new country
2. **Governance**: policy says "new location requires step-up auth"
3. **Automation**: triggers MFA re-challenge automatically
4. **Visibility**: logs the re-auth event, updates risk score

Without all three, zero trust is incomplete:
- Visibility without automation = you see the threat but respond too slowly
- Automation without governance = automated enforcement without clear policies (chaos)
- Governance without visibility = policies exist but you can't tell if they're followed

---

## References

- [CISA ZTMM — Cross-Cutting Capabilities](https://www.cisa.gov/sites/default/files/2023-04/zero_trust_maturity_model_v2_508.pdf)
- [NSA/CISA — Visibility and Analytics Pillar Guidance](https://media.defense.gov/2024/May/30/2003475230/-1/-1/0/CSI-VISIBILITY-AND-ANALYTICS-PILLAR.PDF)
