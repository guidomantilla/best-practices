# Networks Pillar

**Dev relevance: MEDIUM** — network architecture is infra/platform, but developers own service-to-service communication, TLS configuration, and need to understand microsegmentation.

---

## What CISA Requires

Manage internal and external network traffic with zero implicit trust based on network location.

### Functions
- Network segmentation (macro → micro)
- Traffic encryption
- Network visibility and threat protection
- Network resilience

---

## Maturity Levels

### Traditional
- Large perimeter / macro-segmentation (inside = trusted, outside = untrusted)
- Minimal internal traffic encryption
- Static traffic filtering (IP-based firewall rules)
- VPN for remote access

### Initial
- Some internal segmentation (VPC, subnets)
- TLS on external traffic, beginning on internal
- Basic network monitoring

### Advanced
- Micro-perimeters around applications/workloads
- All internal traffic encrypted (mTLS or TLS between services)
- Advanced threat detection (behavioral analytics on traffic)
- DNS encryption (DoH/DoT)

### Optimal
- Full microsegmentation based on application workflows (not just network zones)
- All traffic encrypted (internal and external) — zero exceptions
- ML-based threat detection on network traffic
- Software-defined perimeters — access to individual resources, not network segments
- DNS fully encrypted and monitored

---

## What Developers Own

### Service-to-Service Communication (dev-owned)

| Practice | Traditional | Zero Trust |
|---|---|---|
| HTTP between internal services | ✅ common | ❌ always TLS/mTLS |
| No auth between internal services | ✅ common | ❌ see identity.md (service identity) |
| Trust based on "same network/VPC" | ✅ common | ❌ verify every call |

**Dev actions:**
- All inter-service communication over TLS — no plaintext HTTP even internally
- Authenticate service-to-service calls — see [identity.md](identity.md) (Service Identity section)
- If using service mesh (Istio/Linkerd), mTLS is handled by the sidecar — dev doesn't add TLS code, but must understand the trust model
- Don't hardcode service URLs — use service discovery (DNS, K8s services, Consul)

### TLS Configuration (dev touches)

**Dev actions:**
- TLS 1.2+ minimum — disable TLS 1.0/1.1
- Strong cipher suites (no RC4, DES, 3DES, export ciphers)
- Certificate validation — don't skip verification (`InsecureSkipVerify: true` in Go = bypass all trust)
- Certificate rotation automated — don't let certs expire manually
- See `../backend-engineering/secure-coding/` §5.4 and `../backend-engineering/iac/` §2

### Microsegmentation (understand, even if infra implements)

The concept: instead of "inside the network = trusted", each workload only communicates with explicitly allowed peers.

```
Traditional:
  All services in VPC → can talk to anything in VPC

Zero Trust:
  Order Service → can call Payment Service and Inventory Service
  Order Service → CANNOT call User Admin API
  (enforced by network policy, not by "it just doesn't")
```

**Dev relevance:**
- Kubernetes NetworkPolicies — dev may define what their service can talk to
- Service mesh policies — dev declares allowed ingress/egress per service
- If microsegmentation breaks your service, you need to request explicit access — that's the point

### DNS Security (awareness)

- DNS queries are unencrypted by default — ISPs and attackers can see/modify them
- Encrypted DNS (DoH, DoT) prevents interception
- Mostly infra-owned, but devs should understand: custom DNS resolution in code should use encrypted channels

---

## What Infra/Platform Owns (summary only)

- VPC/subnet architecture and segmentation
- Firewall rules and security groups
- Service mesh deployment and configuration
- Network monitoring and threat detection (NDR)
- DNS infrastructure and encryption
- VPN replacement with zero trust network access (ZTNA)
- DDoS protection (CloudFlare, AWS Shield)

---

## Anti-patterns

- "It's internal, no need for TLS" (attacker inside the network sees everything in plaintext)
- No service-to-service auth (compromised service = full lateral movement)
- Flat network with no segmentation (one compromised container → access to everything)
- `InsecureSkipVerify: true` in production (disables all TLS trust — man-in-the-middle trivial)
- VPN as the security model (VPN in = access to everything — not zero trust)
- DNS queries in plaintext (DNS spoofing, monitoring)

---

## References

- [CISA ZTMM — Networks Pillar](https://learn.microsoft.com/en-us/security/zero-trust/cisa-zero-trust-maturity-model-networks)
- [CISA — Microsegmentation Guidance](https://www.cisa.gov/sites/default/files/2025-07/ZT-Microsegmentation-Guidance-Part-One_508c.pdf)
- [CISA — Encrypted DNS Implementation Guidance](https://www.cisa.gov/resources-tools/resources/encrypted-dns-implementation-guidance)
