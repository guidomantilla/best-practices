# Devices Pillar

**Dev relevance: LOW** — device management is infra/platform/IT. Developer touchpoints are limited to understanding device posture in auth flows.

---

## What CISA Requires

Assess, manage, and monitor the security posture of all devices (laptops, servers, mobile, IoT) before granting access.

### Functions
- Asset management and compliance
- Device threat protection (EDR)
- Device posture assessment before access
- Patch management

---

## Maturity Levels (Summary)

| Level | What it means |
|---|---|
| **Traditional** | Limited device visibility, manual inventory, no posture checks |
| **Initial** | Asset inventory started, basic compliance checks, some endpoint protection |
| **Advanced** | Automated asset management, real-time compliance monitoring, EDR deployed, non-compliant devices isolated |
| **Optimal** | Continuous posture assessment, automated remediation, device health feeds into access decisions in real-time |

---

## What Developers Should Know

### Device Posture in Auth Decisions

In zero trust, authentication considers not just "who are you" but "is your device secure":

```
User authenticates with valid JWT
  + Device has latest OS patches → access granted
  + Device has no disk encryption → access denied or limited
  + Device has compromised EDR status → access denied
```

**Dev touchpoint:** if your auth flow integrates device posture signals (from MDM/EDR), the application may receive device compliance status as part of the auth context (token claims, headers from gateway). Handle "non-compliant device" as a deny/degraded access case.

### Server/Container as "Devices"

Servers, VMs, and containers are also "devices" in CISA's definition:
- Container images should be scanned and compliant — see `../backend-engineering/iac/` §11
- Server/VM patches managed automatically — see `../backend-engineering/iac/` §10
- Runtime compliance monitoring (no drift from baseline)

### Developer Workstations

Your laptop is a device too:
- Full disk encryption (FileVault, BitLocker, LUKS)
- OS and tools up to date
- MFA on all development accounts (GitHub, cloud, CI/CD)
- Don't store production credentials locally (use `direnv` + short-lived tokens)
- Screen lock on idle

---

## What Infra/Platform/IT Owns

- MDM (Mobile Device Management) — Jamf, Intune, Kandji
- EDR (Endpoint Detection and Response) — CrowdStrike, SentinelOne, Carbon Black
- Patch management automation
- Device compliance policies and enforcement
- Certificate deployment to devices
- BYOD policies and controls
- Asset inventory and tracking

---

## Anti-patterns

- No device posture checks (any device with valid credentials gets full access)
- Unpatched development machines with production access
- No disk encryption on laptops (stolen laptop = data breach)
- Production credentials stored permanently on developer machines
- No MFA on developer accounts (compromised GitHub/cloud account = supply chain attack)

---

## References

- [CISA ZTMM — Devices Pillar](https://learn.microsoft.com/en-us/security/zero-trust/cisa-zero-trust-maturity-model-devices)
