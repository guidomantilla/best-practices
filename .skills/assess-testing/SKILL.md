---
name: assess-testing
description: Review a project's testing strategy and test code for gaps, anti-patterns, and improvement opportunities. Use when the user asks to review test coverage strategy, assess test quality, check for flaky tests, evaluate test architecture, or identify missing test levels. Triggers on requests like "review my tests", "is my testing strategy solid", "check test quality", "are there testing gaps", or "/assess-testing".
category: hybrid
---

# Testing Strategy Review

Review a project's testing approach for gaps, anti-patterns, and structural issues. Produce actionable findings — not generic "write more tests" advice.

## Domain Detection

| Signal | Domain | Context files to read |
|---|---|---|
| Go, Rust, Java, Python with HTTP/gRPC, testcontainers | **Backend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/testing/README.md` (11 areas) |
| React, Vue, Angular, Svelte, Playwright, Cypress, vitest/jest | **Frontend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/testing/README.md` (base) + `https://raw.githubusercontent.com/guidomantilla/best-practices/main/frontend-engineering/testing/README.md` (component, visual regression, a11y, fitness functions) |
| dbt, Airflow, Dagster, Spark, Great Expectations, Soda | **Data** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/data-engineering/testing/README.md` (data testing pyramid, quality, contracts, pipeline E2E) |
| LLM SDK, promptfoo, RAGAS, DeepEval, eval datasets | **AI** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/ai-engineering/testing/README.md` (AI testing pyramid, AI-as-judge, adversarial, regression on model change) |

## Review Process

1. **Detect domain and test framework**: backend (go test, pytest, JUnit), frontend (vitest, Playwright), or data (dbt tests, Great Expectations).
2. **Detect repo structure**: monorepo or polyrepo? Where do tests live?
3. **Map the test structure**: backend (unit, integration, API, E2E, contract, performance). Frontend (unit, component, visual regression, a11y, E2E, fitness functions). Data (unit, data quality, schema validation, data contracts, pipeline E2E).
4. **Identify ownership**: who owns which tests? Developer-maintained? QA-owned? Shared?
5. **Identify critical paths**: backend (business logic, integrations). Frontend (user journeys, interactions). Data (data correctness, freshness, completeness).
6. **Scan against applicable areas**: domain-specific test areas from the relevant context file.
7. **Report findings**: list each issue with impact, location, and fix.
8. **Recommend tooling**: based on detected domain and stack, suggest applicable tools.
9. **Offer capabilities**: based on findings, offer additional deliverables.

## Review Areas

1. **Test pyramid balance** — distribution across unit/integration/API/E2E. Are critical paths covered at the right level?
2. **Unit test quality** — testing behavior or implementation? Over-mocking? Coverage-driven noise?
3. **Integration test quality** — real dependencies or mocked? Isolated or shared state? Self-contained?
4. **API test coverage** — is the service's HTTP/gRPC interface tested with the server running? Error paths, auth, response shapes?
5. **E2E coverage** — critical paths covered? Stable selectors? Independent tests?
6. **Contract testing** — multi-service project without contracts? Breaking changes caught?
7. **Performance testing** — any load/stress tests? Baselines defined? Automated or ad-hoc?
8. **Test environments** — parity with production? Reproducible? Ephemeral or snowflake?
9. **Test data management** — factories or shared fixtures? Cleanup? Anonymized prod data?
10. **Flaky tests** — known flaky tests? Quarantine policy? Root causes addressed?
11. **Over-testing** — tests on trivial code, framework behavior, or implementation details?

These 11 areas are the minimum review scope. Flag additional testing issues beyond these based on the detected project type, scale, or team structure.

## Impact Assessment

| Impact | Criteria |
|---|---|
| **High** | Critical business path untested, test suite can't catch real regressions, or tests give false confidence (pass when bugs exist) |
| **Medium** | Coverage gap at wrong pyramid level, flaky tests eroding confidence, test data issues causing intermittent failures |
| **Low** | Over-testing (maintenance cost without value), suboptimal structure, minor anti-patterns |

## Detection Patterns

### Wrong pyramid level
```
# BAD — E2E test for business logic that could be a unit test
def test_discount_calculation_e2e():
    browser.goto("/products/1")
    browser.click("Add to cart")
    browser.click("Apply coupon SAVE20")
    assert browser.text(".total") == "$80.00"

# BETTER — unit test for the calculation, E2E only for the flow
def test_discount_calculation():
    assert apply_discount(100.00, "SAVE20") == 80.00
```

### Shared mutable state
```go
// BAD — tests share a database row
func TestGetUser(t *testing.T) {
    // depends on user_id=1 existing from TestCreateUser
    user, err := repo.GetUser(1)
    // ...
}
```

### Flaky timing
```javascript
// BAD — arbitrary sleep
test("notification appears", async () => {
    await clickButton("submit");
    await sleep(2000);  // ← hoping the notification is there by now
    expect(screen.getByText("Success")).toBeVisible();
});

// BETTER — explicit wait
test("notification appears", async () => {
    await clickButton("submit");
    await waitFor(() => expect(screen.getByText("Success")).toBeVisible());
});
```

### Over-mocking in "integration" tests
```python
# BAD — this is a unit test pretending to be integration
def test_create_order(mock_db, mock_queue, mock_cache, mock_email):
    # everything is mocked — what integration is being tested?
    service = OrderService(mock_db, mock_queue, mock_cache, mock_email)
    service.create_order(order_data)
    mock_db.save.assert_called_once()
```

## Tooling by Language

### Go
| Category | Tool | What it does | Install |
|---|---|---|---|
| Framework | `testing` (stdlib) | Built-in test framework | stdlib |
| Assertions | `testify` | Rich assertions, mocks, suites | `go get github.com/stretchr/testify` |
| Integration | `testcontainers-go` | Ephemeral Docker dependencies | `go get github.com/testcontainers/testcontainers-go` |
| Coverage | `go test -cover` | Coverage reporting | stdlib |
| Performance | `vegeta` | HTTP load testing | `go install github.com/tsenart/vegeta@latest` |

### Rust
| Category | Tool | What it does | Install |
|---|---|---|---|
| Framework | `cargo test` | Built-in test framework | stdlib |
| Property | `proptest` | Property-based testing | `cargo add proptest --dev` |
| Integration | `testcontainers-rs` | Ephemeral Docker dependencies | `cargo add testcontainers --dev` |
| Performance | `criterion` | Benchmarking | `cargo add criterion --dev` |

### Python
| Category | Tool | What it does | Install |
|---|---|---|---|
| Framework | `pytest` | Test framework + fixtures + plugins | `pip install pytest` |
| Factories | `factory_boy` | Test data factories | `pip install factory-boy` |
| Integration | `testcontainers-python` | Ephemeral Docker dependencies | `pip install testcontainers` |
| Property | `hypothesis` | Property-based testing | `pip install hypothesis` |
| Coverage | `pytest-cov` | Coverage reporting | `pip install pytest-cov` |
| Performance | `locust` | Load testing | `pip install locust` |

### TypeScript / JavaScript
| Category | Tool | What it does | Install |
|---|---|---|---|
| Framework | `vitest` / `jest` | Unit + integration testing | `npm install vitest` |
| E2E | `playwright` | Browser E2E testing | `npm install @playwright/test` |
| Integration | `testcontainers` | Ephemeral Docker dependencies | `npm install testcontainers` |
| API testing | `hurl` | HTTP integration tests as plain text | `brew install hurl` |
| Performance | `k6` | Load testing (JS scripting) | `brew install k6` |

### Java
| Category | Tool | What it does | Install |
|---|---|---|---|
| Framework | JUnit 5 | Test framework | Maven/Gradle dependency |
| Mocking | Mockito | Mocking framework | Maven/Gradle dependency |
| Integration | Testcontainers | Ephemeral Docker dependencies | Maven/Gradle dependency |
| Contract | Pact JVM | Consumer-driven contracts | Maven/Gradle dependency |
| Performance | Gatling | Load testing | Maven/Gradle plugin |

### Cross-Language
| Category | Tool | What it does | Install |
|---|---|---|---|
| Contract | `pact` | Consumer-driven contract testing | Language-specific packages |
| API testing | `schemathesis` | Property-based API testing from OpenAPI | `pip install schemathesis` |
| E2E | `playwright` | Multi-browser E2E | npm or pip |
| Performance | `k6` | Load testing with JS scripting | `brew install k6` |
| API | `hurl` | HTTP test runner (plain text format) | `brew install hurl` |

## Output Format

### Findings

For each finding:

```
### [IMPACT] — Short description
- **File**: path/to/file_test.go:42 (or project-level if structural)
- **Area**: which of the 11 testing areas
- **Issue**: what's wrong or missing
- **Fix**: specific action to take
- **Tool**: which tool from the toolbox helps here
```

### Summary

```
## Summary
- High: N
- Medium: N
- Low: N
- Language(s): [detected]
- Test framework: [detected]
- Repo structure: [monorepo | polyrepo]
- Test levels present: [Unit | Integration | API | E2E | Contract | Performance]
- Test levels missing: [which are absent]
- Estimated pyramid shape: [healthy pyramid | ice cream cone | diamond | all-unit]
- Test ownership: [developer-owned | QA-owned | shared | unclear]
- Flaky tests detected: [yes/no/unknown]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable:

```
## What I Can Generate

Based on this review, I can also:

### For reproducibility (deterministic, CI-ready)
- [ ] **Generate a CI workflow** that runs tests with coverage thresholds and flake-detection rules (quarantine + retry policy from §10). Deterministic — this is what you want as the pre-merge gate.

### For deeper exploration (LLM, non-deterministic)
- [ ] Propose a testing strategy for the critical paths identified
- [ ] Generate integration test scaffolds using testcontainers for detected dependencies
- [ ] Generate API test suite (Hurl/Playwright) for detected endpoints
- [ ] Create a contract testing setup between detected services
- [ ] Design a performance test plan with baselines and targets
- [ ] Identify and classify flaky tests with root cause analysis
- [ ] Generate a test data factory for the detected domain models
- [ ] Propose test environment architecture (local, CI, staging)
- [ ] Recommend test ownership model based on detected team structure

Select which ones you'd like me to generate.

## What NOT to Do

- Don't recommend "increase coverage to 80%" — coverage targets without context are meaningless
- Don't flag missing unit tests for trivial code (getters, constructors, generated code)
- Don't recommend E2E tests for logic that can be tested at lower levels
- Don't prescribe a specific test framework unless the current one is fundamentally unsuitable
- Don't flag test code for violating DRY — repetition in tests is often clarity
- Don't assume the project needs contract testing (only if multi-team microservices)
- Don't assume the project needs performance testing (only if scale/latency requirements exist)
- Don't flag code you haven't read
- Don't count tests — assess whether the important things are tested, not how many tests exist

## Invocation examples

These cover the most useful patterns for this skill. The full list (7 patterns + bonus on context formats) is in the [Invocation patterns section of the README](../../README.md#invocation-patterns).

- **Roadmap** — `/assess-testing proyecto naciente, foco data-api, dame roadmap con días estimados`
- **Plan-first** — `/assess-testing confirma cómo procederás antes de arrancar`
- **Scoped** — `/assess-testing tests/integration/`
