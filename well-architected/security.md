# Security

How to protect information, systems, and assets while delivering business value.

---

## Principles

- **Defense in depth**: multiple layers of security — no single layer is sufficient
- **Least privilege**: minimum permissions needed, for the minimum time needed
- **Automate security**: security checks in CI/CD, automated response, policy-as-code
- **Prepare for incidents**: assume breach, have a plan, practice it
- **Protect data at all layers**: in transit, at rest, in use, in logs, in backups

---

## Design Principles (Converged AWS/Azure/GCP)

### 1. Identity & Access Management

- Strong authentication on everything (MFA, phishing-resistant where possible)
- Authorization per request, not per session (zero trust principle)
- Least privilege — scoped to specific resources and actions
- Service-to-service authentication (no "trusted internal network")
- Progression: RBAC → ABAC → FGA (Fine-Grained Authorization)
- Short-lived credentials over long-lived (rotate, use dynamic secrets)

### 2. Detection & Monitoring

- Log all security-relevant events (auth, access to sensitive data, permission changes)
- Centralize security logs in SIEM
- Alert on anomalies (unusual access patterns, impossible travel, privilege escalation)
- Automate detection where possible (UEBA, ML-based anomaly detection at optimal maturity)
- Monitor configuration drift (detect unauthorized changes)

### 3. Infrastructure Protection

- Network segmentation / microsegmentation
- Encrypt all traffic (internal and external)
- Patch management automated
- Container/workload security (non-root, read-only, resource limits)
- WAF on public endpoints
- DDoS protection

### 4. Data Protection

- Classify data (public, internal, confidential, restricted)
- Encrypt at rest and in transit — no exceptions
- Field-level encryption for sensitive data (beyond disk-level)
- Access controls on data stores (per-service credentials, row-level security)
- Data inventory — know where sensitive data lives
- Retention policies enforced — delete what you don't need

### 5. Application Security

- Secure development lifecycle (SAST, SCA, DAST in pipeline)
- Input validation at every boundary
- Output encoding (prevent injection)
- Dependency scanning and patching
- Signed artifacts, SBOM
- Immutable deployments

### 6. Incident Response

- Plan exists and is documented
- Team knows their roles (who does what during an incident)
- Runbooks for common scenarios
- Communication plan (internal + external + regulatory notification)
- Regular practice (tabletop exercises, game days)
- Post-incident review with action items tracked to completion

---

## Checklist

```
[ ] MFA enabled on all user and admin accounts
[ ] Service-to-service communication is authenticated
[ ] Least privilege enforced (no wildcard IAM policies)
[ ] Secrets managed in secret manager (not in code or env files)
[ ] All data encrypted in transit (TLS 1.2+) and at rest
[ ] Security scanning in CI/CD (SAST, SCA, container scanning)
[ ] Security events logged and monitored
[ ] Incident response plan exists and has been practiced
[ ] Dependencies audited for known vulnerabilities regularly
[ ] Network segmentation implemented (no flat internal network)
[ ] Public endpoints protected by WAF
[ ] Data classified and retention policies enforced
```

---

## Anti-patterns

- Security as afterthought ("we'll add it before launch")
- Perimeter-only security (VPN = trusted, no internal controls)
- Shared credentials between services
- No security monitoring (breach detected months later by a third party)
- Compliance checkbox without real controls (audit passes but system is vulnerable)
- Security team as bottleneck (one team reviews all code — doesn't scale)
- Over-privileged service accounts "because it's easier"

---

## References

- [AWS — Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)
- [Azure — Security](https://learn.microsoft.com/en-us/azure/well-architected/security/)
- [Google — Security, Privacy, and Compliance](https://cloud.google.com/architecture/framework/security)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
