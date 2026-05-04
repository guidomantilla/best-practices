# Testing Best Practices

Principles for validating that a system works correctly at every level — from integration between components to full end-to-end flows. Language-agnostic.

Note: unit testing as a design tool (TDD, testability, design feedback) is covered in `../software-principles/README.md`. This document covers **system validation** — how to verify the system works as a whole.

---

## 1. Test Pyramid

A model for balancing test types by cost, speed, and confidence.

```
         /   E2E   \         Few — slow, expensive, highest confidence
        /------------\
       /  API Tests   \      Moderate — service running, real HTTP, real deps
      /----------------\
     /  Integration     \    Moderate — in-process, real dependencies
    /--------------------\
   /       Unit           \  Many — fast, cheap, isolated
  /------------------------\
```

| Level | What it tests | Speed | Dependencies | Confidence |
|---|---|---|---|---|
| **Unit** | Single function/class in isolation | ms | None (mocked) | Low (doesn't prove integration) |
| **Integration** | Components working together in-process (service + DB) | seconds | Real (DB, cache, queues) | Medium |
| **API** | Your service's HTTP/gRPC interface with full stack running | seconds | Real (service running + deps) | Medium-High |
| **E2E** | Full user journey across multiple services | seconds-minutes | Everything (full stack) | High (but fragile) |

### The key insight
- Unit tests prove your logic is correct
- Integration tests prove your components talk to each other correctly
- API tests prove your service behaves correctly over the network (as clients see it)
- E2E tests prove the system delivers value to the user

### Where they live and when they run

| Level | Where it lives | Runs on PR? | Trigger |
|---|---|---|---|
| **Unit** | Same repo, next to the code (`*_test.go`, `tests/`) | Always — mandatory gate | Every PR, every push |
| **Integration** | Same repo, next to the code | Always — mandatory gate | Every PR, every push |
| **API** | Same repo OR separate repo (depends on ownership) | Optional | PR, cron, on-demand (QA) |
| **E2E** | Separate repo OR monorepo top-level (`/e2e/`) | Optional (often too slow) | Post-deploy, cron, on-demand (QA) |
| **Contract** | Each side in its own repo (contract published to broker) | Always — mandatory gate | Every PR (both consumer and provider) |
| **Performance** | Same repo OR separate repo | No | Scheduled (weekly/per release), on-demand |

### Monorepo vs polyrepo

| Structure | Unit + Integration | API | E2E | Contract |
|---|---|---|---|---|
| **Monorepo** | `/services/foo/tests/` | `/services/foo/api-tests/` or `/tests/api/` | `/e2e/` at repo root | Each service has its own contract tests |
| **Polyrepo** | Same repo as the service | Same repo or separate | Separate repo (crosses service boundaries) | Each repo has its own contract tests |

### Ownership

Unit and integration tests are **non-negotiable in the codebase** — they run on every PR and block merge if they fail. They are developer-owned.

API, E2E, and performance tests may live elsewhere (separate repo, QA-owned suite, CI scheduled job) and run at different cadences depending on cost, speed, and ownership.

| Level | Typically owned by |
|---|---|
| **Unit** | Developer who wrote the code |
| **Integration** | Developer who wrote the code |
| **API** | Developer or QA — depends on team structure |
| **E2E** | QA/QE or full team — depends on team structure |
| **Contract** | Developer (each side owns their contract) |
| **Performance** | SRE, platform team, or developers — depends on org |

### Anti-patterns
- **Ice cream cone**: mostly E2E, few unit tests — slow, flaky, expensive
- **All unit, no integration**: 100% unit coverage but the system doesn't work when assembled
- **Dogmatic ratios**: "70/20/10" applied blindly regardless of project type. The right ratio depends on where risk lives.

---

## 2. Unit Tests

Tests that verify a single function, method, or class in isolation.

### What qualifies as unit
- A single function with defined inputs and outputs
- A class/struct method with dependencies mocked or stubbed
- A pure calculation, transformation, or decision

### Principles
- **Fast**: milliseconds per test. If it's slow, it's not a unit test.
- **Isolated**: no database, no network, no filesystem, no shared state between tests
- **Deterministic**: same input → same output, every time. No randomness, no time dependency.
- **Test behavior, not implementation**: assert on what the function returns or produces, not how it does it internally

### What to unit test
- Business logic: calculations, rules, state machines, validations
- Edge cases: boundaries, empty inputs, overflow, nil/null handling
- Error paths: what happens when inputs are invalid
- Complex conditionals: branches that are easy to get wrong

### What NOT to unit test
- Trivial code: getters, setters, constructors with no logic
- Framework behavior: that your ORM maps fields, that your HTTP framework parses JSON
- Third-party libraries: that `json.Marshal` works
- Private methods: if you need to test a private method, it's a sign the class is doing too much — extract it
- Generated code: protobuf stubs, OpenAPI clients, GraphQL resolvers

### Anti-patterns
- **Over-mocking**: mocking everything until the test verifies nothing — only that mocks were called in order
- **Testing implementation**: asserting on internal method calls, field assignments, or call sequences instead of outcomes
- **Fragile tests**: test breaks when you refactor internals but behavior doesn't change
- **Coverage-driven tests**: writing tests to hit a number, not to catch bugs. 100% coverage ≠ well-tested.
- **One assertion per test (dogmatic)**: sometimes multiple assertions on the same behavior are clearer than 5 tests with 90% shared setup
- **Giant setup**: if setup is 40 lines and assertion is 1, the unit under test has too many dependencies (see `../software-principles/README.md` §7)

### Tooling
| Language | Framework | Assertion/Mocking |
|---|---|---|
| Go | `go test` (stdlib) | `testify` (assertions + mocks) |
| Rust | `cargo test` (built-in) | Built-in `assert!` macros |
| Java | JUnit 5 | Mockito, AssertJ |
| Python | `pytest` | `pytest-mock`, built-in `assert` |
| TypeScript | `vitest` / `jest` | Built-in mocks + assertions |

### Relationship to design
Unit tests are also a design feedback tool — hard-to-test code signals design problems. For that angle, see `../software-principles/README.md` §7 (Testing as Design Feedback).

---

## 3. Integration Tests

Tests that verify components work together with real dependencies.

### How it's coded

There is no separate "integration test framework". You use **the same test framework as unit tests** — the difference is what dependencies are real vs mocked:

| | Unit test | Integration test |
|---|---|---|
| Framework | `go test` / `pytest` / `vitest` / JUnit | Same |
| Dependencies | Mocked/stubbed | Real (via testcontainers) |
| DB | `mock_db` | Actual PostgreSQL container |
| Cache | `mock_cache` | Actual Redis container |
| Speed | Milliseconds | Seconds (container startup) |

```go
// Go — same "go test" framework, real DB via testcontainers
func TestCreateUser(t *testing.T) {
    ctx := context.Background()
    pgContainer, _ := postgres.Run(ctx, "postgres:16")
    defer pgContainer.Terminate(ctx)

    db := connectTo(pgContainer.ConnectionString())
    repo := NewUserRepo(db)

    user, err := repo.Create(ctx, "test@example.com")

    assert.NoError(t, err)
    assert.Equal(t, "test@example.com", user.Email)
}
```

```python
# Python — same pytest framework, real DB via testcontainers
def test_create_user(postgres_container):
    db = connect(postgres_container.get_connection_url())
    repo = UserRepo(db)

    user = repo.create("test@example.com")

    assert user.email == "test@example.com"
```

The test code looks almost identical to a unit test. What changes is the setup: a real container instead of a mock.

### What qualifies as integration
- Service + database (real queries against a real schema)
- Service + external API (or a contract-verified fake)
- Service + message queue (real publish/consume)
- Multiple internal modules assembled together

### Principles
- Use **real dependencies** — the point is to test the integration, not mock it away
- Use **testcontainers** or equivalent to spin up ephemeral databases, Redis, Kafka, etc.
- Each test is **self-contained**: creates its data, runs the test, cleans up
- Tests run in **isolation** — no shared mutable state between tests (no shared DB rows)
- Integration tests should be runnable locally, not only in CI

### Test boundaries
- Test the **behavior at the boundary** (HTTP endpoint, queue consumer), not internal wiring
- Assert on **observable output** (HTTP response, DB state, published message), not implementation details

### Anti-patterns
- Mocking the database in "integration" tests (that's a unit test with extra steps)
- Shared test database with persistent state between tests (order-dependent, flaky)
- Integration tests that depend on external services being up (use testcontainers or contract testing)
- Testing internal function calls instead of the boundary behavior
- No cleanup — tests leave data that affects subsequent tests

### Tooling patterns
| Pattern | What it does | Examples |
|---|---|---|
| **Testcontainers** | Ephemeral real dependencies via Docker | testcontainers-go, testcontainers-python, testcontainers-java, testcontainers (node) |
| **Database per test** | Each test gets a fresh schema/database | CREATE DATABASE per test, or transaction rollback |
| **Fixtures / Factories** | Generate test data programmatically | factory_boy (Python), go-faker, fishery (TS) |

---

## 4. API Tests (Component Tests)

Tests that hit your running service over HTTP/gRPC — like load testing without the load.

### How it differs from integration tests

| | Integration test | API test |
|---|---|---|
| **Execution** | Test framework calls functions in-process | Test sends HTTP requests to a running server |
| **What's tested** | Logic + real dependencies | Full stack: routing, middleware, auth, serialization, status codes, headers, response shape |
| **Service running?** | Not necessarily (in-process) | Yes — running as it would in production |
| **Catches** | Logic bugs, DB interaction issues | Misconfigured routes, broken middleware, wrong status codes, serialization issues, auth enforcement |

### What it proves that integration tests don't
- The HTTP layer works end-to-end (routing, method handling, content-type negotiation)
- Middleware chain executes correctly (auth, rate limiting, CORS, tracing)
- Error responses have the right shape and status codes
- Request validation rejects bad input with proper error messages
- Serialization/deserialization works (what the client actually sees)

### Principles
- **Service is running**: start the service (docker-compose, binary, or in CI) and hit it from outside
- **Real dependencies**: use testcontainers or docker-compose for DB, cache, queues
- **Test the contract AND the behavior**: not just "200 OK" — verify response body, headers, error formats
- **One service at a time**: test YOUR service's API, mock/stub external services it depends on
- **Portable tests**: the test suite should work against local, staging, or production (with appropriate data)

### Patterns

```bash
# Hurl example — declarative API test
GET http://localhost:8080/api/users/123
Authorization: Bearer {{token}}

HTTP 200
[Asserts]
jsonpath "$.id" == 123
jsonpath "$.email" isString
header "Content-Type" == "application/json"

# Error case
GET http://localhost:8080/api/users/999

HTTP 404
[Asserts]
jsonpath "$.error" == "user not found"
```

### Anti-patterns
- Testing business logic at the API level when a unit test would suffice (slow, redundant)
- Not testing error paths (only happy path 200s — never testing 400, 401, 403, 404, 500)
- Hardcoded URLs/ports that break in CI
- No assertions on response shape (just checking status code, not body)
- Skipping auth in tests (testing without auth middleware = testing a different service than production)

### Tooling
| Tool | Language | What it does |
|---|---|---|
| **Hurl** | Language-agnostic | Plain text HTTP tests, CI-native, assertions on headers/body/status |
| **Bruno** | Language-agnostic | Git-friendly API client, collection runner for CI |
| **Playwright** (API mode) | JS/TS | HTTP requests without browser, fixtures, parallelism, retries |
| **supertest** | JS/TS | HTTP assertions against Express/Fastify (in-process, fast) |
| **httptest** | Go | Built-in HTTP test server |
| **pytest + httpx** | Python | Async HTTP client for testing running services |
| **k6** (functional mode) | JS | Can run as functional API test suite, not just load |

### Choosing tooling — team context matters

The choice depends on who owns these tests and team structure:

- **QA/QE-owned, roles separated**: QA often uses Playwright (API mode + E2E in one framework). Backend devs use Hurl/Bruno for quick validation.
- **Full-stack team, everyone owns quality**: minimize technologies — pick one tool that covers API + E2E (Playwright) or keep it language-native (supertest, httptest, httpx).
- **No dedicated QA**: keep API tests in the same language/framework as the service code, so devs maintain them naturally.

---

## 5. End-to-End Tests

Tests that exercise the full system as a user would.

### When E2E adds value
- Critical user journeys (signup, checkout, payment)
- Flows that cross multiple services
- Smoke tests after deployment (does the system work at all?)

### When E2E is more cost than value
- Testing business logic that can be covered by unit/integration tests
- Testing every permutation of a feature
- Flows that rarely break at the integration level

### Principles
- **Few and focused**: test the critical paths, not everything
- **Stable selectors**: use data-testid, ARIA roles, or API contracts — not CSS classes or DOM structure
- **Independent**: each test runs in isolation, creates its own data, doesn't depend on other tests
- **Retriable**: E2E tests may need retries due to timing — that's OK if controlled (1 retry, not infinite)
- **Fast feedback**: if E2E takes > 15 minutes, it won't be run often enough to matter

### Anti-patterns
- **Flaky tests kept alive**: failing intermittently, team ignores them, confidence erodes
- **Testing UI details via E2E**: button color, layout, text content — use visual regression or unit tests
- **Shared state across tests**: test B depends on data created by test A
- **No parallelization**: running sequentially when tests are independent
- **Screenshot/recording only on failure**: capture always in CI, invaluable for debugging

### Tooling
| Tool | What it does | Use case |
|---|---|---|
| **Playwright** | Multi-browser E2E, auto-waits, tracing, screenshots, video | Full UI flows, API flows, modern default |
| **Cypress** | Browser E2E, developer-friendly, time-travel debugging | Frontend-heavy teams, simpler setup |
| **Selenium** | Multi-browser, multi-language bindings | Legacy projects, cross-browser matrix |
| **Maestro** | Mobile E2E (iOS, Android, React Native, Flutter) | Mobile app testing |
| **k6** (browser mode) | Browser-based load + functional testing | Performance of UI flows |

For API-only E2E (no browser), see §4 tooling (Hurl, Playwright API mode, k6 functional).

---

## 6. Contract Testing

Verify that two services agree on their interface without deploying both together. In a microservices world it is arguably the most important cross-team test — it catches integration drift at PR time instead of at production incident time.

### When to use
- Multiple teams own different services that talk to each other
- You can't run the full stack locally
- Deploy cadences differ between services (consumer deploys daily, provider deploys weekly)
- You want to catch breaking API changes before deployment

### How it works
```
Consumer writes contract → Contract stored centrally (broker) → Provider verifies against contract on every PR
```

### Types and when each fits

| Type | Who defines the contract | When it fits | When it doesn't |
|---|---|---|---|
| **Consumer-driven** | The consumer declares what it actually uses (subset of the provider's surface) | Microservices with clear consumer/provider relationship; consumers know what they depend on; breaking changes should fail fast at the provider | Public APIs with unknown consumers; provider can't enumerate who depends on which fields |
| **Provider-driven** | The provider publishes its full schema/spec; consumers conform | Public APIs, OpenAPI-first or proto-first development; provider is the source of truth | Internal services where consumers want more freedom and the provider isn't sure what's used |
| **Bi-directional** | Both sides define expectations, verified independently against the spec | Mature platforms with schema registries; cross-organizational contracts | Small teams — overhead exceeds value |

In practice most internal microservices benefit from **consumer-driven** because it answers the most actionable question: *"can the provider remove this field without breaking the consumer?"*

### Tool comparison

| Tool | Approach | When it shines | Trade-offs |
|---|---|---|---|
| **Pact** | Consumer-driven; consumer records mock interactions, provider replays them | Polyglot teams; HTTP/gRPC; service-to-service | Requires a Pact Broker (self-hosted or PactFlow); learning curve for the mock-then-replay model |
| **Spring Cloud Contract** | Provider-driven on the JVM; provider publishes contracts as Groovy/YAML/Java; consumer generates stubs | JVM-heavy stacks (Spring Boot ecosystem); when the provider should be source of truth | Less polyglot; tighter coupling to Spring tooling |
| **Schemathesis** | Property-based testing from an OpenAPI spec; generates inputs to find inconsistencies | Provider-driven validation of OpenAPI compliance; finding cases the spec missed | Doesn't validate consumer expectations; not consumer-driven |
| **OpenAPI diff / buf breaking** | Spec-level breaking-change detection between versions | Cheap CI gate that catches removed fields, narrowed types, renamed paths | Doesn't validate runtime behavior — only catches changes the spec describes |
| **Protovalidate** | Schema-level constraints inside protobuf | gRPC services where you want runtime validation embedded in the schema | Validation, not contract testing per se — pairs with Pact or Spring Cloud Contract |

### Where it fits in CI

The deterministic flow most teams converge to:

1. **Consumer side** — consumer test suite runs the contract test, generates a contract artifact, publishes it to the broker (Pact Broker, or git-tracked file in monorepos) tagged with the consumer version.
2. **Provider side** — on every provider PR, fetch all consumer contracts from the broker, replay them against the provider build, fail the PR if any contract no longer holds.
3. **Provider deploy gate** — before promoting a provider build to production, check `can-i-deploy` (or equivalent) against the broker: *"have all consumers I'm pinned for verified against this version?"* If not, block the deploy.

Result: a provider can never accidentally remove a field a consumer uses, and a consumer can never silently expect a field the provider doesn't return.

### Versioning contracts with consumers

Contracts must be versioned alongside both consumer and provider. Patterns:

- **Tag contracts with consumer version + branch** so the broker knows which contract corresponds to which deployed consumer.
- **Pact Broker matrix view** (or equivalent) shows compatibility: *which provider versions are compatible with which consumer versions in which environments?*
- **Pending contracts** allow new consumer expectations to land without immediately breaking the provider — the contract is published but doesn't fail the provider build until "promoted". Useful for staggered rollouts.

### Principles
- Contracts test the **interface** (request shape, response shape, status codes), not behavior — behavior lives in unit/integration tests.
- Contracts run in CI on **both sides** — breaking changes are caught before merge, not after deploy.
- Contracts are versioned and centrally stored (Pact Broker, schema registry).
- The broker is part of the deploy gate, not a passive archive.

### Anti-patterns
- Using E2E tests to verify contracts (slow, fragile, requires full deployment).
- Contracts that test implementation details (field ordering, exact timestamps, full body match for partial reads).
- Consumer contracts that are too strict — break on additive changes that shouldn't be breaking (extra optional fields).
- No CI integration — contracts exist but aren't enforced on every PR.
- Provider not consulting the broker before deploys (`can-i-deploy` skipped) — contracts catch nothing if the provider ships before consumers verify.
- One-shot contracts not tied to consumer versions — broker forgets which contract belongs to which deployed code.

### Tooling
| Tool | Type | Languages |
|---|---|---|
| **Pact** | Consumer-driven contracts | Go, Java, Python, JS/TS, Rust, .NET |
| **Spring Cloud Contract** | Provider-driven (JVM) | Java, Kotlin, Groovy |
| **Schemathesis** | Property-based API testing from OpenAPI | Python, CLI |
| **Protovalidate** | Schema-level (gRPC/protobuf) | Any protobuf language |
| **OpenAPI diff / buf breaking** | Spec breaking-change detection | Language-agnostic |
| **Pact Broker / PactFlow** | Contract storage + `can-i-deploy` gate | Language-agnostic |

---

## 7. Performance Testing

Validate that the system meets performance requirements under load.

### Types

| Type | What it answers | How |
|---|---|---|
| **Load test** | Can the system handle expected traffic? | Simulate normal production load |
| **Stress test** | Where does the system break? | Increase load until failure |
| **Soak test** | Are there leaks or degradation over time? | Normal load sustained for hours/days |
| **Spike test** | Can the system handle sudden bursts? | Sudden traffic increase, then drop |

### Principles
- **Define baselines first**: you can't know if performance is "bad" without knowing what "normal" is
- **Test with realistic data**: empty databases perform differently than databases with millions of rows
- **Test in production-like environments**: local laptop results don't predict production behavior
- **Measure what matters**: p50, p90, p95, p99 latency. Throughput (RPS). Error rate under load. Resource utilization.
- **Automate**: performance tests should run in CI on a schedule (weekly or per release), not ad-hoc

### What to measure

| Metric | Why |
|---|---|
| **Latency distribution** (p50/p90/p99) | Averages hide tail latency |
| **Throughput** (requests/sec) | Capacity ceiling |
| **Error rate** under load | System stability |
| **Resource usage** (CPU, memory, connections) | Saturation points |
| **Degradation curve** | How gracefully does performance degrade? |

### Anti-patterns
- Testing performance only once before launch (never again)
- Testing against an empty database
- Testing from the same machine running the service (resource contention)
- Using averages instead of percentiles
- No baseline — "is 200ms good?" depends on context
- Load testing production without warning (accidental DDoS of yourself)

### Tooling
| Tool | Type | Use case |
|---|---|---|
| **k6** | Load testing | Script-based, developer-friendly, CI-native |
| **Locust** | Load testing | Python-based, distributed |
| **Gatling** | Load testing | Scala/Java, detailed reports |
| **wrk / wrk2** | HTTP benchmarking | Quick latency/throughput measurement |
| **vegeta** | HTTP load testing | Go, constant-rate attacks |

---

## 8. Test Environments

Where tests run and how they're managed.

### Principles
- **Parity**: test environment should mirror production as closely as possible (same versions, same config structure, same infrastructure)
- **Isolation**: tests don't affect each other, teams don't block each other
- **Reproducibility**: given the same code and data, tests produce the same result
- **Ephemeral over persistent**: prefer environments spun up per test/PR/deploy over long-lived shared environments

### Environment strategies

| Strategy | When to use | Trade-off |
|---|---|---|
| **Local (testcontainers)** | Integration tests, fast feedback | Limited to what Docker can run |
| **PR environments** | Full stack per PR, E2E against isolated deploy | Expensive, complex to set up |
| **Shared staging** | Single staging environment for all teams | Cheap, but conflicts between teams |
| **Production (with flags)** | Testing in prod behind feature flags or with synthetic users | Highest fidelity, highest risk |

### Anti-patterns
- Shared staging where teams overwrite each other's data
- Test environments with different versions than production
- Tests that require manual environment setup (undocumented, breaks on new hire)
- No way to reset/recreate the environment (snowflake environments)
- Tests dependent on external third-party sandboxes being available

---

## 9. Test Data Management

How to create, manage, and clean up data for tests.

### Strategies

| Strategy | How it works | Best for |
|---|---|---|
| **Factories** | Generate data programmatically with sensible defaults, override what matters | Unit + integration tests |
| **Fixtures** | Pre-defined static data loaded before tests | Simple, stable scenarios |
| **Snapshots** | Captured from production (anonymized) | Performance tests, realistic data shapes |
| **Seeding scripts** | Scripts that populate a fresh environment | Staging, demos, new developer onboarding |

### Principles
- Each test creates its own data — don't rely on data from other tests or pre-existing state
- Use factories with defaults — only specify fields relevant to the test being written
- Anonymize production data before using in tests (PII, PHI, NPI — see `../data-privacy/README.md`)
- Clean up after tests — or better, use transactions/ephemeral DBs so cleanup is automatic

### Anti-patterns
- **Shared test data**: "user_1" exists in the DB and 50 tests depend on it — change it and everything breaks
- **Production data in tests without anonymization**: PII in test environments violates privacy laws
- **Over-specified factories**: every test creates data with 30 fields when only 2 matter
- **No cleanup**: test data accumulates, environment degrades, tests start failing randomly
- **Sequential dependency**: test B needs data created by test A — if A fails or runs out of order, B fails

---

## 10. Flaky Tests

Tests that pass and fail intermittently without code changes.

### Common causes

| Cause | Why it happens | Fix |
|---|---|---|
| **Timing / async** | Test doesn't wait for async operation to complete | Explicit waits, polling with timeout, deterministic signals |
| **Shared state** | Tests pollute each other's data | Isolation (fresh DB, transactions, unique identifiers) |
| **Date/time** | Test assumes current date/time | Inject clock, freeze time in tests |
| **Network** | External service intermittently unavailable | Mock external calls, use contract testing |
| **Resource contention** | CI machine overloaded, port collisions | Randomize ports, resource limits, dedicated CI |
| **Order dependency** | Tests pass only when run in a specific order | Randomize test order, each test is self-contained |

### Policy
- **Quarantine immediately**: a flaky test is worse than no test (erodes confidence in the entire suite)
- **Track flakiness**: monitor which tests are flaky and how often (CI tools often provide this)
- **Fix or delete**: a quarantined test has a deadline — fix it within N days or delete it
- **Never retry to green**: retrying until a test passes hides the problem. One retry is acceptable for E2E with known timing issues. More than that = the test is broken.

### Anti-patterns
- Ignoring flaky tests (team learns to "just re-run CI")
- `sleep(5)` as a fix for timing issues (fragile, slows down the suite)
- Disabling tests instead of fixing them (accumulated disabled tests = untested code)
- No investigation — marking as flaky without understanding the root cause

---

## 11. What NOT to Test

Tests have a maintenance cost. Not everything deserves a test.

### Don't test
- **Trivial code**: getters, setters, constructors with no logic
- **Framework behavior**: that your ORM saves to the DB, that your HTTP framework parses JSON
- **Third-party libraries**: that `json.Marshal` works correctly
- **Implementation details**: private methods, internal state, call order between collaborators
- **Generated code**: protobuf stubs, GraphQL resolvers, OpenAPI clients

### Do test
- **Business logic**: domain rules, calculations, state machines
- **Edge cases**: boundaries, empty inputs, overflow, null handling
- **Integration boundaries**: your code talks to external systems correctly
- **Error paths**: what happens when things fail
- **Critical paths**: anything where a bug = revenue loss, data corruption, or security breach

### The heuristic
Ask: "if this test fails, does it mean a real bug exists?" If the answer is "no, it probably means the implementation changed but behavior didn't", the test is testing the wrong thing.

---

## Tooling

### Test Frameworks
| Language | Framework | Use case |
|---|---|---|
| Go | `testing` (stdlib) | Unit + integration (with testcontainers-go) |
| Go | `testify` | Assertions, mocks, suites |
| Rust | `#[test]` + `cargo test` | Built-in, unit + integration |
| Rust | `proptest` | Property-based testing |
| Java | JUnit 5 | Unit + integration |
| Java | Mockito | Mocking |
| Python | `pytest` | Unit + integration + fixtures |
| Python | `hypothesis` | Property-based testing |
| TypeScript | `vitest` / `jest` | Unit + integration |
| TypeScript | `playwright` | E2E (browser) |

### Integration / E2E
| Tool | What it does |
|---|---|
| **Testcontainers** | Ephemeral Docker containers for real dependencies (DB, Redis, Kafka) |
| **Playwright** | Browser E2E testing (multi-browser) |
| **Cypress** | Browser E2E testing (developer-friendly) |
| **Hurl** | HTTP integration testing via plain text files |
| **Bruno** | API testing (Postman alternative, git-friendly) |

### Performance
| Tool | What it does |
|---|---|
| **k6** | Developer-friendly load testing, JS scripting, CI-native |
| **Locust** | Python-based distributed load testing |
| **vegeta** | Constant-rate HTTP load testing (Go) |

### Contract
| Tool | What it does |
|---|---|
| **Pact** | Consumer-driven contract testing |
| **Schemathesis** | Property-based API testing from OpenAPI spec |

---

## References

- [Martin Fowler — Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html)
- [Martin Fowler — Contract Testing](https://martinfowler.com/bliki/ContractTest.html)
- [Google Testing Blog — Testing on the Toilet](https://testing.googleblog.com/)
- [Ham Vocke — The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
- [Testcontainers Documentation](https://testcontainers.com/)
- [Pact Documentation](https://docs.pact.io/)
- [k6 Documentation](https://k6.io/docs/)
