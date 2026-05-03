# Well-Architected Framework

Reference guide for building well-architected systems. Synthesized from AWS Well-Architected Framework, Azure Well-Architected Framework, Google Cloud Architecture Framework, and the academic foundations of Bass/Clements/Kazman (*Software Architecture in Practice*) and Richards/Ford (*Fundamentals of Software Architecture*).

Cloud-agnostic — the principles are universal. Vendor-specific implementation details are noted where relevant but not the focus.

---

## What is "Well-Architected"

A system is well-architected when it explicitly addresses the quality attributes that matter for its context — and the trade-offs between them are documented and intentional.

There is no universally "well-architected" system. A startup MVP and a banking platform have different quality requirements. What makes both well-architected is that the decisions are **conscious, documented, and validated**.

---

## The Converging Pillars

Three major cloud providers independently arrived at the same pillars:

| Pillar | AWS | Azure | GCP |
|---|---|---|---|
| **Operational Excellence** | ✅ | ✅ | ✅ |
| **Security** | ✅ | ✅ | ✅ (+ Privacy & Compliance) |
| **Reliability** | ✅ | ✅ | ✅ |
| **Performance** | Performance Efficiency | Performance Efficiency | Performance |
| **Cost** | Cost Optimization | Cost Optimization | Cost Optimization |
| **Sustainability** | ✅ | — | — |

Sustainability is AWS-only and out of scope for this repo.

---

## Scope

### Pillars (what to build for)

| File | What it covers |
|---|---|
| [operational-excellence.md](operational-excellence.md) | CI/CD, IaC, observability, runbooks, incident response, continuous improvement |
| [security.md](security.md) | Defense in depth, identity, data protection, incident detection |
| [reliability.md](reliability.md) | Fault tolerance, recovery, redundancy, DR, chaos testing |
| [performance.md](performance.md) | Resource optimization, scaling, caching, monitoring, bottleneck analysis |
| [cost-optimization.md](cost-optimization.md) | Right-sizing, compute waste, query efficiency, storage tiers |
| [ai-workloads.md](ai-workloads.md) | How the 5 pillars manifest with AI/LLM components (probabilistic systems) |

### Methodology (how to think about architecture)

| File | What it covers |
|---|---|
| [quality-attributes.md](quality-attributes.md) | The -ilities, QA scenarios, specifying non-functional requirements |
| [tactics.md](tactics.md) | Catalog of architectural tactics per quality attribute |
| [adrs.md](adrs.md) | Architecture Decision Records — documenting decisions |
| [fitness-functions.md](fitness-functions.md) | Automated tests that validate architecture in CI |
| [trade-off-analysis.md](trade-off-analysis.md) | Every decision has a cost — how to evaluate trade-offs |

---

## The Academic Foundations

| Source | Contribution |
|---|---|
| **Bass, Clements, Kazman** — *Software Architecture in Practice* (4th ed, 2021) | Quality attribute scenarios, tactics catalog, ATAM evaluation method |
| **Richards, Ford** — *Fundamentals of Software Architecture* (2nd ed, 2024) | Architecture characteristics (-ilities), fitness functions, trade-off analysis, component analysis |
| **AWS/Azure/GCP WAFs** | Practical pillar frameworks with cloud-specific checklists |

The books provide the **theory** (how to think). The cloud frameworks provide the **practice** (what to check). This folder synthesizes both.

---

## Where This Maps in the Repo

| Pillar | Primary location in backend-engineering/ |
|---|---|
| Operational Excellence | `ci-cd/`, `observability/`, `configuration/`, `iac/` |
| Security | `secure-coding/`, `../zero-trust/` |
| Reliability | `system-design/resilience.md` |
| Performance | `system-design/scalability.md`, `observability/` (RED/USE), `data-design/` (queries, indexing, caching) |
| Cost Optimization | `observability/` §12 (cost), + gaps to fill |

| Methodology | Primary location in backend-engineering/ |
|---|---|
| Quality Attributes | Distributed across all folders (not centralized as concept) |
| Tactics | Distributed (patterns in system-design/, testing/, secure-coding/) |
| ADRs | Not yet covered — new content |
| Fitness Functions | Partially in testing/ and ci-cd/ (not as unified concept) |
| Trade-off Analysis | `system-design/README.md` §4 (principle, not method) |

---

## References

### Cloud Frameworks
- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/)
- [Google Cloud Architecture Framework](https://cloud.google.com/architecture/framework)

### Books
- [Bass, Clements, Kazman — Software Architecture in Practice (4th ed, 2021)](https://www.sei.cmu.edu/library/software-architecture-in-practice-fourth-edition/)
- [Richards, Ford — Fundamentals of Software Architecture (2nd ed, 2024)](https://www.oreilly.com/library/view/fundamentals-of-software/9781098175504/)
