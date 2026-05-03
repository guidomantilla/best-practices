# Zero Trust — CISA Maturity Model v2

Reference guide for zero trust architecture based on CISA's Zero Trust Maturity Model v2.0 (2023) and NIST SP 800-207. Written for developers — deep on what devs own, lighter on what infra/platform teams own.

---

## What is Zero Trust

**"Never trust, always verify."**

Zero trust is a security model that eliminates implicit trust. No user, device, network, or service is trusted by default — every access request is authenticated, authorized, and encrypted regardless of where it comes from.

### The shift

| Traditional (perimeter) | Zero Trust |
|---|---|
| Inside the network = trusted | No network location is trusted |
| Authenticate once at login | Verify every request, every time |
| Flat internal network | Microsegmented, least privilege per resource |
| VPN = access to everything | Access only to what you need, when you need it |
| Trust the client | Verify the client continuously |

---

## NIST SP 800-207 — The 7 Tenets

The foundational principles. Everything else builds on these.

1. **All data sources and computing services are resources** — not just servers. APIs, databases, SaaS tools, containers.
2. **All communication is secured regardless of network location** — internal network doesn't mean safe. Encrypt everything.
3. **Access to resources is granted per-session** — authenticate and authorize each request. Don't grant blanket access.
4. **Access is determined by dynamic policy** — not static rules. Consider identity, device, behavior, time, location, risk score.
5. **The enterprise monitors all owned and associated assets** — continuous monitoring, not annual audits.
6. **Authentication and authorization are dynamic and strictly enforced** — MFA, re-auth on sensitive operations, continuous validation.
7. **Collect as much information as possible to improve security posture** — telemetry, analytics, behavior analysis feed back into policy.

---

## CISA Zero Trust Maturity Model v2.0

The practical framework for implementation and assessment. Organized into **5 pillars** + **3 cross-cutting capabilities**, each with **4 maturity levels**.

### Structure

```
                    ┌──────────────────────────────────────────────────────┐
                    │              Cross-Cutting Capabilities              │
                    │   Visibility & Analytics                            │
                    │   Automation & Orchestration                        │
                    │   Governance                                        │
                    ├──────────┬──────────┬──────────┬──────────┬─────────┤
                    │ Identity │ Devices  │ Networks │ Apps &   │  Data   │
                    │          │          │          │ Workloads│         │
                    ├──────────┼──────────┼──────────┼──────────┼─────────┤
                    │ Traditional → Initial → Advanced → Optimal          │
                    └──────────────────────────────────────────────────────┘
```

### Maturity Levels

| Level | What it means |
|---|---|
| **Traditional** | Perimeter-based, static credentials, manual processes, implicit trust by network location |
| **Initial** | MFA implemented, asset inventory started, some encryption, first steps toward zero trust |
| **Advanced** | Phishing-resistant MFA, automated responses, cross-pillar signal correlation, continuous verification |
| **Optimal** | Full automation, real-time risk assessment, dynamic policy enforcement, continuous validation across all pillars |

---

## Scope

| File | Pillar/Capability | Dev relevance |
|---|---|---|
| [identity.md](identity.md) | Identity | **High** — auth, MFA, session management, JWT, RBAC, service identity |
| [devices.md](devices.md) | Devices | **Low** — mostly infra/platform (endpoint compliance, EDR). Dev touchpoint: device posture checks in auth flows |
| [networks.md](networks.md) | Networks | **Medium** — microsegmentation, mTLS, encrypted traffic. Dev owns: service-to-service auth, TLS config |
| [applications.md](applications.md) | Applications & Workloads | **High** — application access control, secure dev lifecycle, API auth, runtime protection |
| [data.md](data.md) | Data | **High** — data classification, encryption, access control, lifecycle, DLP |
| [cross-cutting.md](cross-cutting.md) | Visibility, Automation, Governance | **Medium** — observability, automated enforcement, policy as code |

---

## How Zero Trust Maps to Existing Best Practices

This repo already covers many zero trust requirements. This section maps CISA pillars to existing content.

| CISA Pillar/Area | Already covered in |
|---|---|
| Identity — auth, MFA, session | `backend-engineering/secure-coding/` §5.2 (Authentication & Identity) |
| Identity — RBAC, authorization | `backend-engineering/secure-coding/` §5.3 (Authorization & Access Control) |
| Networks — CORS, gateway | `backend-engineering/secure-coding/` §5.13 (CORS & API Gateway Security) |
| Networks — TLS, encryption | `backend-engineering/secure-coding/` §5.4 (Data Protection & Cryptography) |
| Applications — secure SDLC | `backend-engineering/secure-coding/` §1-§4 (Shift-Left, Pipeline, Process) |
| Applications — API security | `backend-engineering/secure-coding/` §5.10 (API-Specific Security) |
| Data — encryption | `backend-engineering/secure-coding/` §5.4 + `backend-engineering/iac/` §2 |
| Data — classification, lifecycle | `backend-engineering/data-design/lifecycle.md` |
| Data — privacy, compliance | `backend-engineering/data-privacy/` |
| Visibility — logging, monitoring | `backend-engineering/observability/` |
| Governance — IaC, config as code | `backend-engineering/iac/` + `backend-engineering/configuration/` §7 |
| Frontend — client limitations | `frontend-engineering/secure-coding/` §8 + `frontend-engineering/configuration/` §6 |

### What's NOT yet covered (gaps this folder fills)
- Service-to-service authentication (mTLS, service mesh, workload identity)
- Device posture in auth decisions
- Microsegmentation from the application perspective
- Continuous verification / re-authentication
- Dynamic policy (risk-based access, not just RBAC)
- Assume breach as a design principle

---

## References

- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final)
- [CISA Zero Trust Maturity Model v2.0](https://www.cisa.gov/resources-tools/resources/zero-trust-maturity-model)
- [CISA ZTMM v2.0 PDF](https://www.cisa.gov/sites/default/files/2023-04/zero_trust_maturity_model_v2_508.pdf)
- [NIST SP 800-207A — Zero Trust for Cloud-Native Applications](https://csrc.nist.gov/pubs/sp/800/207/a/final)
- [CISA Zero Trust Implementation Guidance (2025)](https://www.dhs.gov/sites/default/files/2025-04/2025_0129_cisa_zero_trust_architecture_implementation.pdf)
