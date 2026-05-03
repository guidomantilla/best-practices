# Infrastructure as Code & Container Best Practices

Principles for writing infrastructure code and building container images. Tool-agnostic where possible — the "what to validate" applies regardless of whether you use Terraform, OpenTofu, Pulumi, or CloudFormation. Docker-specific section included as the de facto standard for containers.

---

## 1. Networking

Validate that network configurations follow least-exposure principles.

- No 0.0.0.0/0 ingress on security groups (except intentional public load balancers)
- Restrict egress to only necessary destinations
- Use private subnets for databases, caches, internal services
- Public subnets only for load balancers and bastion hosts (if any)
- VPC peering/service mesh for inter-service communication, not public internet
- No SSH/RDP open to the internet (use bastion, SSM, or Tailscale)
- Network policies in Kubernetes (default deny, explicit allow)
- Separate security groups per service (not one shared "allow all internal")

### Anti-patterns
- Wide-open security groups "for development" that reach production
- All services in one public subnet
- No network segmentation between environments (dev can reach prod DB)

---

## 2. Encryption

Validate that data is protected at rest and in transit.

- Encryption at rest enabled on all storage (S3, RDS, EBS, GCS, disks)
- KMS/CMK for encryption keys (not provider-managed where compliance requires it)
- TLS enforced on all endpoints (no HTTP, only HTTPS)
- TLS 1.2+ minimum (no TLS 1.0/1.1)
- Database connections encrypted (SSL mode = require/verify-full)
- Encrypted backups (same standard as primary data)
- No unencrypted secrets in state files (encrypt remote state)

### Overlap
Encryption requirements also covered from the security angle in `../secure-coding/README.md` §5.4 (Data Protection & Cryptography).

---

## 3. IAM & Access Control

Validate that permissions follow least privilege.

- No wildcard actions (`*`) in IAM policies
- No wildcard resources (`*`) — scope to specific ARNs/resources
- No root account usage for operational tasks
- MFA enforced on privileged accounts
- Service accounts scoped to minimum required permissions
- Separate IAM roles per service (not one shared role)
- No inline policies — use managed/reusable policies
- Assume-role for cross-account access (not shared credentials)
- Time-limited credentials where possible (STS, workload identity)

### Anti-patterns
- `"Effect": "Allow", "Action": "*", "Resource": "*"` — the "god policy"
- One IAM role shared by 10 services (blast radius of compromise)
- Long-lived access keys instead of role-based auth

---

## 4. Logging & Audit

Validate that infrastructure events are observable.

- Cloud audit trail enabled (CloudTrail, GCP Audit Logs, Azure Activity Log)
- VPC flow logs enabled on production VPCs
- Access logs enabled on load balancers, API gateways, S3 buckets
- Log storage in a separate account/project (tamper-resistant)
- Log retention policies defined (not indefinite, not too short)
- Deletion protection on log storage

### Overlap
Logging practices for application code covered in `../observability/README.md`. This section covers infrastructure-level audit logging.

---

## 5. Backup & Recovery

Validate that data can be recovered after failure.

- Automated backups enabled on databases and critical storage
- Backup retention period defined (matches compliance requirements)
- Multi-AZ / multi-region for critical services
- Point-in-time recovery enabled where available (RDS, DynamoDB)
- Backup restoration tested on a regular schedule (not just "enabled")
- Deletion protection on production databases and storage

### Anti-patterns
- Backups "enabled" but never tested (find out they're corrupt during an incident)
- Single-AZ production database (AZ failure = downtime)
- No deletion protection (accidental `terraform destroy` deletes prod DB)

---

## 6. Secrets in IaC

Validate that secrets are not embedded in infrastructure code.

- No hardcoded secrets in `.tf`, `.yaml`, `.json`, or any IaC definition files
- No secrets in Terraform variables without `sensitive = true`
- No secrets in plain-text environment variables in IaC definitions
- Use secret references (Vault, AWS Secrets Manager, GCP Secret Manager) — not values
- State file encrypted and access-controlled (remote state contains resolved secrets)
- No secrets in CI/CD logs from plan/apply output

### Overlap
Secrets management practices covered in `../configuration/README.md` §4 and `../secure-coding/README.md` §5.4. This section covers the IaC-specific manifestation.

---

## 7. Kubernetes Resources

Validate that K8s workloads follow security and reliability best practices.

### Security
- No privileged containers (`privileged: false`)
- No root user (`runAsNonRoot: true`)
- Read-only root filesystem where possible (`readOnlyRootFilesystem: true`)
- No host network/PID/IPC sharing
- Drop all capabilities, add only what's needed (`drop: ALL`)
- Pod security standards enforced (restricted or baseline)

### Reliability
- Resource requests AND limits defined (CPU, memory)
- Liveness probes (is the process alive?)
- Readiness probes (can it serve traffic?)
- Startup probes for slow-starting apps
- Pod Disruption Budgets for critical services
- Topology spread constraints for high availability

### Networking (Zero Trust)
- Network policies defined — **default deny** ingress AND egress, explicit allow per service (zero trust microsegmentation)
- No `LoadBalancer` type services exposed directly (use Ingress/Gateway)
- Service mesh for mTLS between services (Istio, Linkerd, Cilium) — see `../system-design/integration-level.md` §13
- Every pod declares what it needs to talk to — anything not declared is denied

### Workload Identity
- Use workload identity (GKE Workload Identity, EKS IRSA, Azure Workload Identity) instead of static service account keys
- Each pod gets a short-lived, auto-rotated identity — no long-lived credentials
- SPIFFE/SPIRE for cross-cluster/cross-cloud workload identity
- See `../../zero-trust/identity.md` for the full zero trust perspective on service identity

### Anti-patterns
- No resource limits (one pod consumes all node memory, crashes neighbors)
- No probes (K8s can't tell if the app is healthy, sends traffic to broken pods)
- `privileged: true` for convenience (full host access if compromised)
- No network policies (any pod can talk to any pod — lateral movement is trivial)
- Static service account keys mounted in pods (long-lived, not rotated, shared across pods)
- No workload identity (pods use node-level permissions — over-privileged)

---

## 8. General Security

Validate broad security posture of infrastructure resources.

- Public access disabled by default on storage (S3, GCS, Azure Blob)
- Versioning enabled on object storage (recover from accidental deletion/overwrite)
- Deletion protection on production resources (databases, storage, DNS zones)
- No default credentials on any managed service
- Managed service endpoints not publicly exposed (use VPC endpoints/private link)
- WAF/DDoS protection on public-facing services

---

## 9. Convention & Tagging

Validate that resources are identifiable and manageable.

- All resources tagged with: `environment`, `service`, `team`/`owner`, `cost-center`
- Consistent naming convention across all resources
- Tags enforced by policy (can't create untagged resources)
- Used for cost allocation, ownership identification, and automated operations (e.g., auto-shutdown dev resources)

### Anti-patterns
- 200 resources with no tags (who owns this? what environment? nobody knows)
- Inconsistent naming (`my-service-prod` vs `prod_myservice` vs `MyServiceProduction`)
- Tags defined but not enforced (policy exists but isn't blocking)

---

## 10. Supply Chain & Versioning

Validate that infrastructure dependencies are controlled.

- Provider/module versions pinned (not `>= 1.0` — use exact or range with ceiling)
- Module sources pinned to specific versions or commits (not `main` branch)
- Remote state backend configured with locking (prevent concurrent modifications)
- State file encrypted at rest
- `terraform plan` / `pulumi preview` required before apply (no blind applies)
- Plan approval in CI/CD before production changes
- Drift detection on a schedule (detect manual changes outside IaC)

### Anti-patterns
- No lockfile (`.terraform.lock.hcl`) committed — builds aren't reproducible
- Unpinned module versions (upstream breaking change surprises you)
- No state locking (two people apply simultaneously, state corrupted)
- Manual changes in console/dashboard that IaC doesn't know about (drift)

---

## 11. Dockerfile Best Practices

Docker is the de facto container standard. These apply regardless of orchestrator.

### Image Design
- **Multi-stage builds**: separate build stage from runtime. Final image has no compilers, no source code, no dev dependencies.
- **Minimal base image**: Alpine, distroless, or scratch. Not `ubuntu:latest` (700MB+ of unused packages).
- **Pin base image**: use SHA digest or exact version (`node:20.11.1-alpine`), never `:latest`
- **Layer ordering**: dependencies first (`COPY package.json` → `RUN npm install`), code last. Maximizes cache hits.
- **Specific COPY**: `COPY src/ ./src/` not `COPY . .` (avoids including .env, .git, node_modules, secrets)
- **.dockerignore**: exclude `.git`, `node_modules`, `.env`, test files, docs

### Security
- **Non-root user**: `USER nonroot` or `USER 1000`. Never run as root.
- **No secrets in image**: not in `ENV`, not in `COPY`, not in `ARG` (ARGs are visible in image history)
- **Read-only filesystem**: set `--read-only` at runtime where possible
- **No `latest` tag for base images**: pinned versions prevent supply chain surprises
- **Scan before push**: run Trivy/Grype in CI before publishing to registry

### Reliability
- **HEALTHCHECK**: define in Dockerfile so orchestrators know when the container is healthy
- **Graceful shutdown**: handle SIGTERM (stop accepting traffic, finish in-flight, exit)
- **Single process per container**: don't run supervisord with 5 processes. One responsibility per container.
- **No state in container**: containers are ephemeral. State belongs in external storage.

### Anti-patterns
- `COPY . .` as first instruction (busts cache on every code change, includes everything)
- `RUN apt-get update && apt-get install` without pinned versions (non-reproducible)
- `latest` base image tag (different image on every build)
- Running as root (container escape = host access)
- Secrets baked into the image (visible to anyone with `docker history`)
- 2GB images in production (slow pulls, large attack surface)

### Tooling
| Tool | What it does |
|---|---|
| **hadolint** | Dockerfile linter (rules + ShellCheck for RUN instructions) |
| **Trivy** | Scan images for CVEs before/after push |
| **Grype** | Container image vulnerability scanner |
| **dive** | Analyze image layers and wasted space |
| **docker-slim** | Automatically minimize image size |

---

## IaC Scanning Tooling

| Tool | What it scans | Approach |
|---|---|---|
| **Checkov** | Terraform, CloudFormation, K8s, Helm, Dockerfile, ARM, Bicep | 1000+ built-in rules, graph-based cross-resource analysis |
| **Trivy** | Terraform, CloudFormation, K8s, Dockerfile, Helm | Common misconfigs, fewer rules but broader scope (also does CVEs, secrets) |
| **tfsec** (now part of Trivy) | Terraform | Terraform-specific, fast |
| **OPA / Conftest** | Any structured config (JSON, YAML, HCL) | Custom policy-as-code (Rego), no built-in rules — you write them |
| **KICS** | Terraform, CloudFormation, K8s, Docker, Ansible | Open-source, 2000+ queries |
| **Hadolint** | Dockerfile | Dockerfile-specific linting |

---

## References

- [Checkov Policy Index](https://www.checkov.io/5.Policy%20Index/all.html)
- [CIS Benchmarks for Cloud](https://www.cisecurity.org/cis-benchmarks)
- [Docker — Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Sysdig — Dockerfile Best Practices](https://www.sysdig.com/learn-cloud-native/dockerfile-best-practices)
- [SLSA Framework](https://slsa.dev/)
- [NSA/CISA Kubernetes Hardening Guide](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)

For the well-architected perspective on operational excellence (CI/CD + IaC + observability as a unified pillar), see [`../../well-architected/operational-excellence.md`](../../well-architected/operational-excellence.md).
