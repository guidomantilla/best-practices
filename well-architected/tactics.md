# Architectural Tactics

A catalog of proven approaches to achieve each quality attribute. Based on Bass/Clements/Kazman (*Software Architecture in Practice*).

A **tactic** is a design decision that influences a quality attribute. Tactics are the building blocks — patterns combine multiple tactics.

---

## Availability Tactics

Goal: keep the system operational, detect and recover from faults.

### Detect Faults

| Tactic | What it does |
|---|---|
| **Health checks (ping/echo)** | Periodic check if component is alive |
| **Heartbeat** | Component sends periodic "I'm alive" signal — absence = failure |
| **Timestamp monitoring** | Detect stale data/processes by checking timestamps |
| **Voting / consensus** | Multiple instances agree on result — detect Byzantine failures |
| **Exception detection** | Catch and handle exceptions before they propagate |
| **Self-test** | Component validates its own state on startup or periodically |

### Recover from Faults

| Tactic | What it does |
|---|---|
| **Redundancy (active/passive)** | Multiple instances — failover to standby on failure |
| **Retry** | Retry transient failures with exponential backoff + jitter |
| **Rollback** | Revert to previous known-good state |
| **Circuit breaker** | Stop calling a failing service, use fallback |
| **Graceful degradation** | Offer reduced functionality instead of total failure |
| **State resynchronization** | After recovery, sync state from primary/replicas |
| **Checkpoint/restart** | Save progress, restart from checkpoint on failure |

### Prevent Faults

| Tactic | What it does |
|---|---|
| **Transactions** | Ensure atomicity — all-or-nothing operations |
| **Removal from service** | Take unhealthy instance out of rotation for maintenance |
| **Predictive modeling** | Detect trends that lead to failure (disk filling, memory leaking) |
| **Rate limiting** | Prevent overload from causing cascading failure |

---

## Performance Tactics

Goal: respond within time and throughput constraints.

### Control Resource Demand

| Tactic | What it does |
|---|---|
| **Manage work rate** | Queue, throttle, shed load — don't accept more than you can handle |
| **Prioritize events** | Critical requests processed before non-critical |
| **Reduce overhead** | Eliminate unnecessary computation, middleware, serialization |
| **Bound execution time** | Timeouts, query limits, pagination — cap expensive operations |
| **Reduce frequency** | Batch, debounce, sample — process less often when real-time isn't needed |

### Manage Resources

| Tactic | What it does |
|---|---|
| **Caching** | Store results of expensive operations for reuse |
| **Replication** | Multiple copies of data/services — distribute read load |
| **Concurrency** | Parallel processing — use multiple cores/threads/goroutines |
| **Connection pooling** | Reuse expensive connections instead of creating per request |
| **Data partitioning** | Split data across shards — parallelize access |
| **CDN / Edge** | Serve from closer to user — reduce network latency |

---

## Security Tactics

Goal: protect against unauthorized access, data breach, and misuse.

### Detect Attacks

| Tactic | What it does |
|---|---|
| **Intrusion detection** | Monitor for known attack patterns |
| **Anomaly detection** | Detect deviations from normal behavior (UEBA) |
| **Audit trail** | Log all security-relevant events for forensics |
| **Input validation** | Reject malformed/malicious input at the boundary |

### Resist Attacks

| Tactic | What it does |
|---|---|
| **Authenticate** | Verify identity (MFA, certificates, tokens) |
| **Authorize** | Verify permissions per request (RBAC, ABAC, FGA) |
| **Encrypt** | Protect data in transit (TLS) and at rest (AES) |
| **Limit access** | Least privilege, network segmentation, microsegmentation |
| **Limit exposure** | Minimize attack surface (close ports, remove unnecessary services) |

### React to Attacks

| Tactic | What it does |
|---|---|
| **Revoke access** | Disable compromised credentials immediately |
| **Lock account** | Block after N failed attempts |
| **Notify** | Alert security team, notify affected users |
| **Isolate** | Quarantine affected component to prevent lateral movement |

### Recover from Attacks

| Tactic | What it does |
|---|---|
| **Restore** | Recover from clean backup |
| **Audit** | Forensic analysis of what happened |
| **Patch** | Fix the vulnerability that was exploited |
| **Rotate** | Change all potentially compromised credentials |

---

## Modifiability Tactics

Goal: make changes easy, localized, and low-risk.

### Reduce Coupling

| Tactic | What it does |
|---|---|
| **Encapsulation** | Hide internals behind interfaces |
| **Use an intermediary** | Adapter, facade, middleware — decouple producer from consumer |
| **Abstract common services** | Shared functionality extracted (auth, logging, config) |
| **Restrict dependencies** | Dependency rules (domain doesn't import infrastructure) |

### Increase Cohesion

| Tactic | What it does |
|---|---|
| **Single responsibility** | Each module has one reason to change |
| **Semantic coherence** | Related functionality lives together |
| **Split modules** | When a module does too much, split by responsibility |

### Defer Binding

| Tactic | What it does |
|---|---|
| **Configuration files** | Change behavior without recompiling |
| **Feature flags** | Enable/disable features at runtime |
| **Plugin architecture** | Add behavior by adding modules, not modifying existing ones |
| **Dependency injection** | Swap implementations without changing consumers |

---

## Testability Tactics

Goal: make the system easy to test at all levels.

| Tactic | What it does |
|---|---|
| **Dependency injection** | Inject mocks/stubs in tests — decouple from real infrastructure |
| **Interface segregation** | Test against small, focused interfaces |
| **Separate concerns** | Business logic testable without HTTP/DB — pure functions where possible |
| **Record/playback** | Capture real traffic, replay in tests |
| **Sandbox environment** | Isolated test environment that mirrors production |
| **Test hooks** | Entry points designed for testing (not just the public API) |
| **Localize state** | Minimize shared mutable state — easier to set up and verify test conditions |

---

## Deployability Tactics

Goal: deploy frequently with low risk.

| Tactic | What it does |
|---|---|
| **Immutable artifacts** | Build once, deploy same artifact everywhere |
| **Blue-green deployment** | Two environments, switch traffic |
| **Canary release** | Gradual rollout to subset of users |
| **Feature flags** | Deploy code without activating it |
| **Automated rollback** | Revert on health check failure |
| **Infrastructure as code** | Environment provisioning is repeatable and version-controlled |
| **Pipeline as code** | CI/CD definition lives in the repo |
| **Contract testing** | Verify API compatibility before deploy |

---

## How Tactics Combine into Patterns

Patterns are compositions of multiple tactics:

| Pattern | Tactics combined |
|---|---|
| **Circuit Breaker** | Detect faults (monitoring) + Prevent faults (removal from service) + Recover (fallback) |
| **CQRS** | Manage resources (replication, partitioning) + Increase cohesion (separate read/write) |
| **Saga** | Recover from faults (rollback/compensate) + Transactions (per-step atomicity) |
| **API Gateway** | Resist attacks (authenticate, authorize) + Manage resources (rate limiting, caching) |
| **Clean Architecture** | Reduce coupling (encapsulation, restrict dependencies) + Increase cohesion (single responsibility) |

---

## Anti-patterns

- Applying tactics without understanding the quality attribute they serve (adding cache without measuring if reads are the bottleneck)
- Over-applying one category of tactics (all security, no performance — or vice versa)
- Tactics without measurement (deployed a circuit breaker but don't monitor if it opens)
- Copy-pasting tactics from another system without analyzing your own quality attribute needs

---

## References

- [Bass, Clements, Kazman — Tactics chapters (Part II)](https://www.sei.cmu.edu/library/software-architecture-in-practice-fourth-edition/)
