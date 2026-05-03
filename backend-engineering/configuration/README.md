# Configuration Best Practices

Principles for managing application configuration, secrets, feature flags, and environment differences. Language-agnostic — applicable to any service, regardless of stack.

---

## 1. Configuration Sources and Precedence

Configuration comes from multiple sources. Define a clear precedence order so behavior is predictable.

### Standard precedence (highest wins)

```
1. Command-line flags / arguments       (highest — explicit override)
2. Environment variables                 (injected by orchestrator or shell)
3. Remote config service                 (runtime changes without restart)
4. Config file (per environment)         (versioned, reviewable)
5. Defaults in code                      (lowest — fallback)
```

### 12-Factor App principle
- Config that varies between environments (dev/staging/prod) belongs in environment variables, not in code or config files
- Config that is the same across environments (timeouts, retry counts, internal URLs) can be in code or config files

### Anti-patterns
- No defined precedence — unclear which source wins when values conflict
- Config files committed with environment-specific values (forces branching per environment)
- Mixing sources without documentation (some in env vars, some in files, some hardcoded — nobody knows which is where)
- Reading config from multiple sources without a single entry point that resolves precedence

**Source:** Heroku, *The Twelve-Factor App* — III. Config (2011)

---

## 2. Environment Management

### Principles
- **Environment parity**: dev, staging, and production should be as similar as possible in structure
- **What differs between environments**: connection strings, hostnames, credentials, feature flags, log levels
- **What should NOT differ**: code, dependency versions, schema, application behavior (aside from feature flags)

### Anti-patterns
- "Works on my machine" caused by undocumented environment differences
- Staging with different dependency versions or schema than production
- Environment-specific code paths (`if env == "prod"` in business logic)
- No staging environment at all — deploying directly to production

### Environment variable naming convention
```
SERVICE_NAME_CONFIG_KEY=value

# Examples:
APP_DATABASE_URL=postgres://...
APP_REDIS_URL=redis://...
APP_LOG_LEVEL=info
APP_FEATURE_NEW_CHECKOUT=true
```

Prefix with service/app name to avoid collisions when multiple services run on the same host.

---

## 3. Local Development Configuration

### Recommended: direnv (.envrc)

```bash
# .envrc (gitignored)
export APP_DATABASE_URL="postgres://localhost:5432/myapp_dev"
export APP_REDIS_URL="redis://localhost:6379"
export APP_LOG_LEVEL="debug"
export APP_SOME_SECRET="dev-only-secret"
```

Why direnv:
- Exports real env vars to the shell — identical to how they arrive in production
- Activates automatically when entering the directory
- Can execute logic (read from local secret manager, generate tokens, run scripts)
- Your code sees env vars from the OS — no library needed to load config files
- Simulates production behavior exactly

### .envrc.example (committed)

```bash
# .envrc.example — copy to .envrc and fill in values
export APP_DATABASE_URL="postgres://localhost:5432/myapp_dev"
export APP_REDIS_URL="redis://localhost:6379"
export APP_LOG_LEVEL="debug"
export APP_SOME_SECRET=""  # get from vault / team shared secrets
```

Committed to document what config the service needs. Not the actual values.

### Anti-patterns: dotenv / .env files
- `.env` files require a library (`dotenv`) to load — adds a dependency that doesn't exist in production
- Creates a divergence: in dev config comes from a file, in production from env vars — different code paths
- Easy to accidentally commit with real values
- No execution logic — can't dynamically resolve secrets
- Multiple `.env` variants (`.env.local`, `.env.development`, `.env.production`) create confusion

### Gitignore
```
.envrc
.env
.env.*
!.envrc.example
!.env.example
```

---

## 4. Secrets Management

The operational side of handling secrets. What qualifies as a secret is covered in `../secure-coding/README.md` (§5.4). This section covers **how to manage them**.

### Principles
- Secrets come from a **secret manager** in production (Vault, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault)
- Secrets are injected as environment variables or mounted files by the orchestrator — the application does not fetch them
- Secrets are **rotated** on a defined schedule without requiring redeployment
- Secrets have **access controls** — only the services that need them can read them
- Secrets have **audit trails** — who accessed what, when

### Injection patterns

| Pattern | How it works | When to use |
|---|---|---|
| **Env var injection** | Orchestrator (K8s, ECS, systemd) sets env vars from secret store at container/process start | Most common, simplest |
| **Mounted file** | Secret mounted as a file in the container (K8s Secrets as volumes) | Certificates, multi-line secrets |
| **Sidecar/init container** | Sidecar fetches secrets and writes them before app starts (Vault Agent, External Secrets Operator) | Complex rotation, dynamic secrets |
| **Direct SDK call** | Application calls secret manager API at startup | When you need dynamic/short-lived secrets (DB credentials rotated per instance) |

### Rotation
- Secrets should be rotatable without downtime
- Design for dual-read: during rotation window, both old and new secret are valid
- Short-lived secrets (token expiry, temporary credentials) are better than long-lived ones
- Automate rotation — manual rotation = rotation never happens

### Anti-patterns
- Secrets in git (even in "private" repos — they get cloned, forked, backed up)
- Secrets in `.env` files deployed to servers
- Secrets passed as command-line arguments (visible in `ps aux`)
- Same secret across all environments (compromising dev = compromising prod)
- No rotation policy — secrets unchanged for years
- Application fetching secrets on every request (performance hit, rate limiting) — fetch once at startup, cache in memory
- Long-lived static secrets when dynamic/short-lived are available: Vault can generate per-instance DB credentials that expire in hours — no shared password that lives forever
- Standing privileges on service accounts: service accounts with permanent access to everything. Use zero standing privileges — grant access just-in-time (JIT), revoke automatically after use.
- Service identity via shared API keys: all services use the same key. Each service should have its own identity (SPIFFE/SPIRE, workload identity, per-service JWT) — see `../../zero-trust/identity.md`

See `../../zero-trust/identity.md` for the full zero trust perspective on service identity and credentials.

---

## 5. Configuration Validation

Validate all configuration at startup. Fail fast if anything is missing or invalid.

### Principles
- Read all config from sources at process start — one place, one time
- Parse into a typed struct/object — not raw strings everywhere
- Validate required fields, formats, ranges before the application accepts traffic
- Crash immediately with a clear error message listing what's missing/invalid
- The application should never read env vars or config sources outside of the startup phase

### The pattern

```
Startup:
  1. Read all config sources (env vars, files, remote)
  2. Resolve precedence
  3. Parse into typed struct
  4. Validate (required, format, range)
  5. If invalid → crash with clear error listing all problems
  6. If valid → inject struct into application (DI)
  7. Application code uses the struct, never reads env vars directly
```

### Anti-patterns
- **Scattered os.Getenv / process.env reads**: config accessed ad-hoc throughout the codebase. Impossible to know what config the service needs without reading all the code. Untestable — can't inject config in tests.
- **String-typed config**: port number as string, boolean as string that's compared with `== "true"`. Parse to proper types at startup.
- **Silent defaults for required values**: database URL defaults to localhost in production because the env var was missing. Should have crashed.
- **Partial validation**: some fields checked, others assumed present. First request fails 30 seconds after startup because a config was missing.
- **Config validation in request handlers**: finding out config is broken only when a user hits a specific endpoint.
- **Late failure**: service starts, passes health checks, takes traffic, then crashes when the missing config is first accessed.

---

## 6. Feature Flags

Runtime switches that control behavior without deploying new code.

### Types

| Type | Purpose | Lifetime | Example |
|---|---|---|---|
| **Release** | Gate incomplete features in main branch | Short — remove after launch | `new_checkout_enabled` |
| **Experiment** | A/B testing, gradual rollout by percentage or cohort | Medium — remove after decision | `experiment_pricing_v2` |
| **Ops** | Circuit breakers, kill switches, load shedding | Permanent — part of operational toolkit | `disable_heavy_report`, `maintenance_mode` |
| **Permission** | Feature access by user/role/plan | Permanent — tied to authorization | `feature_premium_export` |

### Lifecycle
1. **Create**: define the flag with a clear name, type, default value, and owner
2. **Use**: reference in code with a clear if/else (both paths must work)
3. **Rollout**: enable gradually (%, cohort, region)
4. **Decide**: flag becomes 100% on or 100% off
5. **Cleanup**: remove the flag, remove the dead code path, remove the conditional

### Anti-patterns
- **Stale flags**: flags that reached 100% months/years ago but the conditional is still in code — tech debt that accumulates silently
- **Nested flags**: behavior depends on flag A AND flag B AND flag C — combinatorial explosion, impossible to test
- **No default**: flag evaluation fails when the service can't reach the flag provider — always define a safe default (usually: feature off)
- **Flags in domain logic**: feature flags belong at the boundary (handler, controller, middleware), not deep in business logic
- **No ownership**: nobody knows who created the flag or when to clean it up
- **Using flags as permanent config**: if it never changes, it's not a flag — it's config
- **Client-side flags as access control**: a flag that hides a button in the UI does NOT protect the endpoint. The backend must enforce authorization independently of any client-side flag state — clients can be tampered with

### Flag hygiene
- Every flag has an **owner** and an **expiration date**
- Review stale flags on a regular cadence (monthly / per sprint)
- Automate detection of flags that have been 100% on for > N days
- The code path for "flag off" should be deletable — if both paths must coexist permanently, it's not a feature flag

---

## 7. Configuration as Code

Configuration changes should be versioned, reviewable, and auditable — like code.

### Principles
- Config lives in version control (git) — not in dashboards, admin panels, or manual edits on servers
- Config changes go through the same review process as code (PR, review, merge)
- Config has history — you can see what changed, when, and by whom
- Rollback = revert the commit

### What qualifies as "config as code"
- Kubernetes manifests (Helm, Kustomize, raw YAML)
- Terraform / OpenTofu / Pulumi definitions
- CI/CD pipeline definitions
- Feature flag definitions (if the flag service supports file-based config)
- Monitoring/alerting rules (Prometheus rules, Grafana dashboards as JSON)

### Anti-patterns
- Config changes via SSH into a server and editing files
- Config managed only in a vendor dashboard (Datadog, LaunchDarkly, AWS Console) with no git trail
- "Snowflake" servers where config has drifted from what's in git
- Manual database migrations run ad-hoc instead of versioned migration files

---

## 8. Runtime vs Static Configuration

### Static config
- Set at startup, doesn't change until restart/redeploy
- Connection strings, ports, service URLs, log level (base), timeouts, retry counts
- Simpler to reason about — the process behavior is deterministic for its lifetime

### Runtime config
- Can change without restart — takes effect immediately or on next evaluation
- Feature flags, circuit breaker thresholds, rate limits, maintenance mode
- Requires: polling mechanism or push notification, safe defaults if source is unreachable

### When to use runtime config
- You need to react faster than a deploy cycle allows (kill switch, circuit breaker)
- You're doing gradual rollout or A/B testing
- Operational knobs that SRE/ops need to adjust without developer intervention

### When NOT to use runtime config
- Database connection strings (changing mid-flight = connection pool chaos)
- Service ports or bind addresses
- Anything that requires process restart to take effect anyway
- If you can deploy in < 5 minutes, most things don't need runtime config

### Anti-patterns
- Everything is runtime config (over-engineering — most config never changes between deploys)
- Runtime config with no fallback (config service down = feature broken)
- No notification when runtime config changes (invisible behavior change, hard to debug)
- Caching runtime config forever (defeats the purpose)

---

## Tooling

### Secret Managers
| Tool | Type | Use case |
|---|---|---|
| **HashiCorp Vault** | Self-hosted / Cloud | Dynamic secrets, rotation, PKI, multi-cloud |
| **AWS Secrets Manager** | Managed | AWS-native, rotation built-in, ECS/EKS integration |
| **GCP Secret Manager** | Managed | GCP-native, IAM-integrated, Cloud Run/GKE injection |
| **Azure Key Vault** | Managed | Azure-native, certificate management |
| **1Password (Connect)** | SaaS | Team secrets sharing + service injection |
| **SOPS** | File encryption | Encrypt secrets in git (with KMS), decrypt at deploy |

### Feature Flags
| Tool | Type | Use case |
|---|---|---|
| **LaunchDarkly** | SaaS | Enterprise flag management, targeting, experiments |
| **Unleash** | Self-hosted / Cloud | Open-source, flexible targeting |
| **Flipt** | Self-hosted | Lightweight, gRPC-native, GitOps-friendly |
| **PostHog** | SaaS | Flags + product analytics combined |
| **Environment variables** | N/A | Simple on/off flags for small services (no targeting needed) |

### Configuration Libraries
| Language | Tool | What it does |
|---|---|---|
| Go | `viper` | Multi-source config (env, files, remote), precedence, typing |
| Go | `envconfig` | Struct-based env var parsing with validation |
| Go | `koanf` | Lightweight alternative to viper, composable providers |
| Rust | `config-rs` | Layered config from files, env, defaults |
| Python | `pydantic-settings` | Typed config from env vars with validation |
| Python | `dynaconf` | Multi-source, environment-aware, secrets support |
| TypeScript | `zod` + `process.env` | Schema validation for env vars at startup |
| Java | Spring Config | Profiles, property sources, validation |

### Local Development
| Tool | What it does | Install |
|---|---|---|
| **direnv** | Auto-loads .envrc per directory, exports real env vars | `brew install direnv` |

---

## References

- [The Twelve-Factor App — III. Config](https://12factor.net/config)
- [HashiCorp Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Martin Fowler — Feature Toggles](https://martinfowler.com/articles/feature-toggles.html)
- [CNCF — Secrets Management](https://www.cncf.io/blog/2021/04/12/secrets-management/)
- [Pete Hodgson — Feature Toggles (Feature Flags)](https://martinfowler.com/articles/feature-toggles.html)
