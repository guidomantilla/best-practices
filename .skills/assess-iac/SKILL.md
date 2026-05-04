---
name: assess-iac
description: Review infrastructure as code and Dockerfiles for misconfigurations, security gaps, and best practice violations. Use when the user asks to review Terraform, Pulumi, CloudFormation, Kubernetes manifests, Helm charts, or Dockerfiles. Triggers on requests like "review my Terraform", "check my Dockerfile", "is my K8s config secure", "review infrastructure code", or "/assess-iac".
---

# IaC & Container Review

Review infrastructure code and Dockerfiles for misconfigurations, security gaps, and reliability issues. Produce actionable findings — not generic "follow CIS benchmarks" advice.

## Context Files

Before reviewing, read this reference document for the full rule set:

- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/iac/README.md` — 11 areas: networking, encryption, IAM, logging, backup, secrets, K8s, general security, conventions, supply chain, Dockerfile

## Review Process

1. **Detect IaC tool and cloud provider**: identify from file extensions and syntax (`.tf`, `.yaml`, `Pulumi.*`, `template.yaml`, `Dockerfile`).
2. **Detect deployment target**: AWS, GCP, Azure, Kubernetes, Docker-only.
3. **Identify what's being provisioned**: databases, networking, compute, storage, K8s workloads, containers.
4. **Scan against the 11 areas**: review against each applicable area from the iac reference.
5. **Report findings**: list each issue with impact, location, and fix.
6. **Recommend scanning tooling**: based on detected IaC tool, suggest applicable scanners.
7. **Offer capabilities**: based on findings, offer additional deliverables.

## Review Areas

1. **Networking** — security groups, subnets, ingress/egress, no 0.0.0.0/0, network segmentation
2. **Encryption** — at rest and in transit enabled, KMS, TLS enforced, state encrypted
3. **IAM & Access Control** — least privilege, no wildcards, scoped roles, no root usage
4. **Logging & Audit** — audit trails, flow logs, access logs, retention, tamper-resistant storage
5. **Backup & Recovery** — automated backups, retention, multi-AZ, deletion protection, tested
6. **Secrets in IaC** — no hardcoded secrets, sensitive variables marked, state encrypted
7. **Kubernetes resources** — no privileged, non-root, resource limits, probes, network policies
8. **General security** — public access disabled, versioning, deletion protection, no defaults
9. **Convention & Tagging** — consistent naming, required tags, enforced by policy
10. **Supply chain & Versioning** — pinned providers/modules, state locking, plan-before-apply, drift detection
11. **Dockerfile** — multi-stage, minimal base, non-root, no secrets, pinned versions, healthcheck

These 11 areas are the minimum review scope. Flag additional infrastructure issues beyond these based on the detected provider, compliance requirements, or deployment complexity.

## Impact Assessment

| Impact | Criteria |
|---|---|
| **High** | Security exposure (public access, no encryption, wildcard IAM, privileged containers), data loss risk (no backups, no deletion protection) |
| **Medium** | Reliability gaps (no probes, no resource limits, single-AZ), operational risk (no logging, no tagging, no state locking) |
| **Low** | Convention issues (naming, tagging inconsistency), minor optimization (image size, layer ordering) |

## Detection Patterns

### Wide-open security group
```hcl
# BAD — open to the world
resource "aws_security_group_rule" "allow_all" {
  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # ← everything from everywhere
}
```

### Wildcard IAM
```hcl
# BAD — god policy
resource "aws_iam_policy" "admin" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = "*"       # ← all actions
      Resource = "*"       # ← on all resources
    }]
  })
}
```

### Privileged container
```yaml
# BAD — full host access
containers:
  - name: app
    securityContext:
      privileged: true       # ← container escape = host access
      runAsUser: 0           # ← running as root
```

### Dockerfile anti-patterns
```dockerfile
# BAD — multiple issues
FROM ubuntu:latest              # ← unpinned, large base
COPY . .                        # ← includes .env, .git, everything
ENV API_KEY=sk-1234567890       # ← secret in image
RUN apt-get install -y curl     # ← unpinned package version
USER root                       # ← running as root (or not setting USER at all)
```

## Tooling

### IaC Scanning
| Tool | What it scans | Install |
|---|---|---|
| **Checkov** | Terraform, CF, K8s, Helm, Dockerfile, ARM | `pip install checkov` |
| **Trivy** | Terraform, CF, K8s, Dockerfile + CVEs + secrets | `brew install trivy` |
| **KICS** | Terraform, CF, K8s, Docker, Ansible | Docker or binary |
| **OPA / Conftest** | Any structured config (custom policies in Rego) | `brew install conftest` |

### Dockerfile
| Tool | What it does | Install |
|---|---|---|
| **hadolint** | Dockerfile linter (rules + ShellCheck) | `brew install hadolint` |
| **Trivy** | Image CVE scanning | `brew install trivy` |
| **Grype** | Image vulnerability scanner | `brew install grype` |
| **dive** | Analyze image layers and waste | `brew install dive` |

### Drift Detection
| Tool | What it does | Install |
|---|---|---|
| **driftctl** | Detect unmanaged cloud resources | `brew install driftctl` |
| **terraform plan** (scheduled) | Compare state to real infrastructure | built-in |

## Output Format

### Findings

For each finding:

```
### [IMPACT] — Short description
- **File**: main.tf:42 (or Dockerfile:12, deployment.yaml:30)
- **Area**: which of the 11 IaC areas
- **Issue**: what's wrong
- **Fix**: specific action to take (with code snippet if applicable)
- **Tool**: which scanner would catch this automatically
```

### Summary

```
## Summary
- High: N
- Medium: N
- Low: N
- IaC tool: [Terraform | OpenTofu | Pulumi | CloudFormation | K8s manifests | Helm | Dockerfile]
- Cloud provider: [AWS | GCP | Azure | multi-cloud]
- Resources reviewed: [list of resource types found]
- Dockerfile present: [yes/no]
- K8s manifests present: [yes/no]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable:

```
## What I Can Generate

Based on this review, I can also:
- [ ] Generate a Checkov/Trivy scanning config for CI integration
- [ ] Create a hardened Dockerfile (multi-stage, non-root, minimal base)
- [ ] Generate K8s Pod Security Standards (restricted) manifests
- [ ] Create IAM policies scoped to minimum required permissions
- [ ] Generate tagging enforcement policies (OPA/Sentinel)
- [ ] Design network segmentation (VPC/subnet layout)
- [ ] Create a .dockerignore for this project

Select which ones you'd like me to generate.
```

Only list capabilities that are relevant to the findings and context.

## What NOT to Do

- Don't prescribe a specific IaC tool (Terraform vs Pulumi vs CDK) — that's a team decision
- Don't flag cloud-provider-specific features as "wrong" if they're intentional (not everything needs to be multi-cloud)
- Don't recommend K8s checks on a project that doesn't use K8s
- Don't recommend Dockerfile fixes on a project without containers
- Don't flag development/sandbox environments for production-grade standards (unless asked)
- Don't assume AWS — check the actual provider before flagging
- Don't flag code you haven't read
- Don't recommend OPA custom policies when Checkov built-in rules cover the case

## Invocation examples

These cover the most useful patterns for this skill. The full list (7 patterns + bonus on context formats) is in the [Invocation patterns section of the README](../../README.md#invocation-patterns).

- **Scoped** — `/assess-iac terraform/`
- **Deterministic** — `/assess-iac y dame un script con tfsec + checkov + trivy`
- **Narrative** — `/assess-iac stack: Terraform AWS + Helm chart, foco compliance HIPAA`
