# Architecture Fitness Functions

Automated tests that validate architecture characteristics are maintained over time. Concept from Richards/Ford (*Fundamentals of Software Architecture*).

---

## What is a Fitness Function

A fitness function is an automated, objective test that validates an architecture characteristic (quality attribute). Instead of saying "the system should be maintainable", you define a test that fails if maintainability degrades.

The analogy: unit tests validate behavior, fitness functions validate architecture.

---

## Why Fitness Functions Matter

Architecture degrades over time — not intentionally, but through thousands of small decisions:
- "Just this once, I'll import the DB package from the domain layer"
- "This function is only 200 lines, it's fine"
- "We'll fix the performance later"
- "Let's add one more dependency, it's small"

Without automated enforcement, architectural rules become suggestions that erode under deadline pressure. Fitness functions make architecture rules **tests** — they fail in CI, they block merges.

---

## Categories

### 1. Structural Fitness Functions

Validate code structure and dependency rules.

| What it validates | Example | Tools |
|---|---|---|
| **Dependency direction** | Domain layer doesn't import infrastructure packages | ArchUnit (Java), go-arch-lint (Go), dependency-cruiser (TS) |
| **Layer violations** | HTTP handlers don't access database directly | ArchUnit, go-arch-lint |
| **Circular dependencies** | No package A → B → C → A cycles | dependency-cruiser, madge (JS), go vet |
| **Naming conventions** | Repositories end with `Repository`, handlers with `Handler` | ArchUnit, custom lint rules |
| **Import restrictions** | Service A doesn't import Service B's internal packages | depguard (Go), eslint-plugin-import |

**Example (ArchUnit — Java):**
```java
@Test
void domainShouldNotDependOnInfrastructure() {
    noClasses().that().resideInAPackage("..domain..")
        .should().dependOnClassesThat().resideInAPackage("..infrastructure..")
        .check(importedClasses);
}
```

**Example (dependency-cruiser — TypeScript):**
```json
{
  "forbidden": [{
    "name": "domain-no-infra",
    "from": { "path": "^src/domain" },
    "to": { "path": "^src/infrastructure" }
  }]
}
```

### 2. Performance Fitness Functions

Validate that performance doesn't degrade.

| What it validates | Example | Tools |
|---|---|---|
| **Response time** | p99 latency < 200ms for /api/orders | k6, vegeta (in CI on schedule) |
| **Bundle size** | Frontend JS bundle < 200KB gzipped | size-limit, bundlesize |
| **Page load** | LCP < 2.5s | Lighthouse CI |
| **Query performance** | No query > 100ms without explicit exception | pg_stat_statements + alert, custom test |
| **Startup time** | Service starts in < 5 seconds | Custom test in CI |

**Example (size-limit):**
```json
[
  { "path": "dist/index.js", "limit": "200 KB" },
  { "path": "dist/vendor.js", "limit": "150 KB" }
]
```

### 3. Security Fitness Functions

Validate that security rules are enforced.

| What it validates | Example | Tools |
|---|---|---|
| **No endpoint without auth** | Every route has auth middleware | Custom test that scans routes |
| **No critical vulnerabilities** | Dependencies have no critical CVEs | Trivy, npm audit, govulncheck (in CI) |
| **No secrets in code** | No hardcoded credentials | Gitleaks, TruffleHog (in CI) |
| **CSP headers present** | Every response includes Content-Security-Policy | Custom integration test |
| **TLS only** | No HTTP endpoints (only HTTPS) | Custom test or IaC check |

**Example (custom — Go):**
```go
func TestAllRoutesRequireAuth(t *testing.T) {
    router := setupRouter()
    for _, route := range router.Routes() {
        if route.Path == "/health" || route.Path == "/metrics" {
            continue
        }
        assert.Contains(t, route.Middleware, "AuthMiddleware",
            "Route %s %s has no auth middleware", route.Method, route.Path)
    }
}
```

### 4. Reliability Fitness Functions

Validate that reliability characteristics hold.

| What it validates | Example | Tools |
|---|---|---|
| **Health check responds** | /health returns 200 within 1s | Synthetic monitoring (Checkly, k6) |
| **Failover works** | Kill primary → secondary serves traffic | Chaos engineering (Litmus, Toxiproxy) |
| **No single points of failure** | Every critical service has 2+ instances | IaC check (Checkov custom policy) |
| **Backup exists** | Database backup ran in last 24h | Custom check / cloud audit |

### 5. Maintainability Fitness Functions

Validate that code stays maintainable.

| What it validates | Example | Tools |
|---|---|---|
| **Cyclomatic complexity** | No function > complexity 15 | golangci-lint (cyclop), ESLint (complexity) |
| **Function length** | No function > 50 lines | golangci-lint (funlen), ESLint (max-lines-per-function) |
| **File length** | No file > 500 lines | Custom lint rule |
| **Duplication** | No copy-paste blocks > 10 lines | jscpd, CPD |
| **Test coverage on critical paths** | Business logic modules > 80% coverage | go test -cover, pytest-cov |

### 6. Operational Fitness Functions

Validate that operational concerns are addressed.

| What it validates | Example | Tools |
|---|---|---|
| **All resources tagged** | Every cloud resource has team + environment tags | Checkov, OPA policy |
| **IaC drift** | Infrastructure matches IaC definition | terraform plan (scheduled), driftctl |
| **Dockerfile best practices** | No root user, pinned base image, multi-stage | Hadolint (in CI) |
| **Pipeline has security stages** | CI includes SAST, SCA, secret scanning | Custom check on pipeline config |

---

## How to Implement

### In CI/CD Pipeline

```
Lint + Fitness Functions → Test → Build → Scan → Deploy
         ↑
   Fail the build if architecture degrades
```

Fitness functions run as part of the pipeline — same as tests. Architecture violations block merge.

### Start Small

Don't try to add 50 fitness functions at once:

1. **Identify the top 3 architecture rules your team cares about** (dependency direction, no N+1, bundle size)
2. **Write automated checks for those 3**
3. **Run in CI, fail the build on violation**
4. **Add more as architecture evolves**

### Ongoing Maintenance

- Fitness functions need maintenance like tests — update when architecture evolves
- A fitness function that always passes is useless — it should fail when the rule is violated
- A fitness function that always fails is noise — fix the violation or adjust the threshold
- Review fitness functions periodically — are they still relevant?

---

## Anti-patterns

- Fitness functions that nobody looks at (warnings, not failures — ignored)
- Too many fitness functions at once (team rebels, disables them all)
- Fitness functions without buy-in (architect adds them, team doesn't understand why)
- Static thresholds that never evolve ("complexity < 15" was set 3 years ago, codebase has changed)
- Fitness functions as punishment (should be guardrails, not gotchas)
- No fitness functions at all (architecture erodes by default)

---

## References

- [Richards, Ford — Fitness Functions (Ch. 6)](https://www.oreilly.com/library/view/fundamentals-of-software/9781098175504/)
- [Neal Ford — Building Evolutionary Architectures (2017)](https://www.oreilly.com/library/view/building-evolutionary-architectures/9781491986356/)
- [ArchUnit Documentation](https://www.archunit.org/)
- [dependency-cruiser](https://github.com/sverweij/dependency-cruiser)
