# Cost Optimization

How to avoid unnecessary costs, right-size resources, and maximize the value of what you spend.

---

## Principles

- **Adopt a consumption model**: pay for what you use, not what you provision
- **Measure overall efficiency**: cost per transaction, cost per user, cost per request — not just total spend
- **Stop spending money on undifferentiated heavy lifting**: use managed services for things that aren't your competitive advantage
- **Analyze and attribute costs**: know where money goes (per team, per service, per environment)
- **Cost is a quality attribute**: treat it like performance or reliability — measure, budget, alert

---

## Design Principles (Converged AWS/Azure/GCP)

### 1. Right-Sizing

Match resources to actual workload — not to worst-case projections:

| Over-provisioned (waste) | Right-sized |
|---|---|
| 16-core instance running at 5% CPU | 4-core instance running at 40% CPU |
| 64GB RAM, using 8GB | 16GB RAM, using 12GB |
| 3 replicas for 10 req/min | 1 instance + auto-scale |
| Production-sized staging environment running 24/7 | Staging scaled down or scheduled (up during work hours, down overnight) |

**Dev action**: monitor actual resource usage, downsize idle resources, auto-scale instead of over-provision.

### 2. Compute Cost Patterns

| Pattern | When | Savings |
|---|---|---|
| **Reserved/Committed use** | Predictable baseline load (DB, core services) | 30-70% vs on-demand |
| **Spot/Preemptible** | Stateless, fault-tolerant workloads (batch processing, CI runners) | 60-90% vs on-demand |
| **Scale-to-zero** | Sporadic traffic (serverless, Cloud Run, Fargate) | Pay only when invoked |
| **Auto-scaling** | Variable traffic | Match capacity to demand, not peak |
| **Scheduled scaling** | Predictable patterns (business hours, weekends) | Scale down during off-hours |

### 3. Data & Storage Cost

| Practice | Why |
|---|---|
| **Storage tiering** | Hot (SSD) → Warm (HDD) → Cold (archive/Glacier) based on access frequency |
| **Data retention policies** | Delete/archive what you don't need — don't pay to store data nobody queries |
| **Compression** | Compress stored data, logs, backups — smaller = cheaper |
| **Object lifecycle policies** | Automate transition to cheaper tiers after N days |
| **Query optimization** | Inefficient queries in data warehouses cost money per byte scanned (BigQuery, Athena) |
| **Right storage type** | Don't use a relational DB for blob storage (S3 is 10-100x cheaper per GB) |

### 4. Observability Cost

The #1 surprise cost for many teams:

| Cost driver | Control |
|---|---|
| **Log volume** | Log levels (warn+error in prod), drop noise at collector, sample verbose logs |
| **Metric cardinality** | No unbounded labels (user_id, request_id as metric label = cost explosion) |
| **Trace sampling** | 1-10% in production (tail-based for errors/slow), not 100% |
| **Retention** | Hot: 7-30 days, warm: 90 days, cold: 1 year. Not everything at hot tier. |
| **Vendor pricing** | Same data, 10-20x price difference between vendors (Datadog vs Grafana Cloud vs self-hosted) |

**Dev action**: every log line, metric, and trace has a cost. Ask: "would I pay $X/month to keep this?"

### 5. Network Cost

| Practice | Why |
|---|---|
| **Data transfer awareness** | Cross-AZ, cross-region, internet egress all cost money |
| **Keep traffic local** | Services that talk frequently should be in the same AZ/region |
| **CDN for static assets** | Egress from CDN is cheaper than from origin |
| **Compress API responses** | Less data transferred = less cost |
| **Avoid unnecessary cross-region** | Multi-region is for reliability — don't do it for services that don't need it |

### 6. Dev/Test Environment Cost

| Practice | Savings |
|---|---|
| **Scale down non-prod** | Staging doesn't need production-sized instances |
| **Scheduled environments** | Dev/staging up during work hours, down overnight and weekends |
| **Ephemeral environments** | PR environments that spin up and destroy automatically |
| **Shared dev databases** | One dev DB instance for the team, not one per developer (for non-conflicting work) |
| **Spot instances for CI** | CI runners are stateless and fault-tolerant — perfect for spot |

### 7. Architecture-Level Cost Decisions

| Decision | Cost implication |
|---|---|
| **Monolith vs microservices** | Microservices = more instances, more networking, more observability. Don't split unless you need to. |
| **Managed vs self-hosted** | Trade-off depends on scale and team. See table below. |

**Managed vs Self-Hosted (honest trade-off, not vendor recommendation):**

| | Managed (RDS, ElastiCache, SQS) | Self-hosted (VPS, bare metal, self-managed) |
|---|---|---|
| **Cheaper when** | You have zero ops knowledge AND no willingness to learn | Almost always — at any scale. A $5-20/mo VPS runs PostgreSQL, Redis, and your app. Managed equivalent costs 5-20x more. |
| **More control when** | Never — you're limited to what the vendor exposes | Always — you own the machine, the config, the data |
| **Justifiable when** | Compliance requires it (managed = vendor handles patching/certs), or team genuinely has zero capacity for ops | You (or your team) can handle basic ops: deploy, monitor, update, backup |
| **Hidden costs** | Vendor lock-in, pricing tiers, egress fees, pricing changes you can't control | Your time for ops (but tooling — IaC, CI/CD, AI assistants — reduces this dramatically) |

**The reality in 2026:**
- A dev with IaC knowledge + CI/CD + AI coding assistants can operate self-hosted infrastructure that previously required a dedicated ops team
- Self-hosted is cheaper at EVERY scale — the variable is whether you have the competence (or willingness to learn) to operate it
- Managed services sell convenience, not capability — you're paying a premium for someone else to run `apt update` and configure backups
- At large scale the gap is enormous (Basecamp/DHH saved millions leaving AWS)
- At small scale the gap is still significant ($5 VPS vs $50+ for equivalent managed services)

**When managed genuinely makes sense:**
- Regulatory requirement that vendor handles security patching (healthcare, finance with specific audit needs)
- Team with zero ops background AND no time/willingness to learn
- Truly complex managed services that are hard to replicate (global CDN, DDoS protection, ML training clusters)

Note: cloud WAFs (AWS, Azure, GCP) are written BY cloud vendors. Their recommendation to "use managed services" is marketing, not engineering advice. Always calculate total cost of ownership for YOUR context.
| **Synchronous vs async** | Async decouples, but adds messaging infra cost. Worth it for scale, not for 100 req/day. |
| **Multi-region** | 2x infrastructure cost (minimum). Only for services that require it. |
| **Cache layer** | Redis costs money. Only add if it reduces enough load on the DB to justify. |

### 8. Cost Governance

- **Tagging**: every resource tagged with team, service, environment — enables cost attribution
- **Budgets and alerts**: set monthly budget per team/service, alert at 80% and 100%
- **Regular review**: monthly cost review — what grew, why, is it justified?
- **FinOps practice**: someone owns cost optimization (not just "everyone should be careful")
- **Cost in architecture decisions**: "how much will this cost at 10x scale?" is a valid architecture question

---

## Checklist

```
[ ] Resources right-sized based on actual usage (not worst-case guess)
[ ] Auto-scaling configured instead of over-provisioning
[ ] Non-production environments scaled down or scheduled
[ ] Storage lifecycle policies configured (tier transitions, expiration)
[ ] Observability costs controlled (log levels, sampling, cardinality discipline)
[ ] All resources tagged for cost attribution
[ ] Budget alerts configured per team/service
[ ] Monthly cost review conducted
[ ] Reserved/committed use for predictable workloads
[ ] Spot/preemptible for fault-tolerant workloads
[ ] Data retention policies enforced (delete what you don't need)
[ ] Cost considered in architecture decisions (documented in ADRs)
```

---

## Anti-patterns

- "We'll optimize costs later" (later never comes — costs grow silently)
- Over-provisioned "just in case" with no auto-scaling (paying for 10x peak 24/7)
- Every developer has their own full-stack environment running 24/7
- No tagging (impossible to attribute costs — nobody owns the spend)
- 100% trace sampling in production (cost grows linearly with traffic, insight doesn't)
- Logs at debug level in production, never turned down
- Multi-region deployment for a service with 100 users in one country
- Self-hosting what a managed service does better (unless scale justifies it)
- Ignoring data transfer costs (cross-AZ traffic adds up fast at scale)
- No budget alerts (surprise $50K bill at end of month)

---

## References

- [AWS — Cost Optimization Pillar](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/)
- [Azure — Cost Optimization](https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/)
- [Google — Cost Optimization](https://cloud.google.com/architecture/framework/cost-optimization)
- [FinOps Foundation](https://www.finops.org/)
