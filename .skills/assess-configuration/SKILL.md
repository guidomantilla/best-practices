---
name: assess-configuration
description: Review code for configuration management issues — scattered env var reads, missing validation, hardcoded secrets, stale feature flags, and environment anti-patterns. Use when the user asks to review configuration practices, check secret handling, assess feature flag hygiene, or validate config structure. Triggers on requests like "review configuration", "check my config", "are secrets handled correctly", "review feature flags", or "/assess-configuration".
category: tool-backed
---

# Configuration Review

Review code for configuration management issues. Produce actionable findings — not generic "use a secret manager" advice.

## Invocation modes

How to interpret the user's prompt and adapt behavior. These rules apply BEFORE running Domain Detection.

### Scope hint (positional path)

If the first non-flag argument after the slash command looks like a path or glob (e.g., `/assess-configuration src/auth/` or `/assess-configuration terraform/`), restrict the autoexplore to that path. Treat everything else in the prompt as additional context.

If no path is provided AND intake is not triggered, after the first short response include a one-liner reminder: *"I'm reviewing the entire codebase. You can scope a future run with `/assess-configuration <path>`."*

### Intake mode

Trigger if the prompt contains either:

- The flag `--ask` (anywhere in the invocation), or
- A natural-language equivalent: *"preguntame"*, *"ask me first"*, *"ask me before"*, *"necesito que me preguntes"*, *"intake first"*, or any phrase clearly requesting questions before the review.

When triggered, BEFORE reading any files, ask these questions in a single message and wait for answers:

**General context (always ask):**

   1. ¿En qué etapa está el proyecto? (early-MVP, growth, production, maintenance)
   2. ¿Cuál es el foco o preocupación principal hoy?
   3. ¿Hay áreas que prefieras que ignore o que ya sabes que no aplican?
   4. ¿Hay algún constraint inmediato? (deadline, regulación, costos, scaling)

**Specific to this skill:**

   5. ¿Cómo se manejan los secretos hoy? (secret manager, env vars, archivos `.env`, hardcoded)

After receiving answers, run the autoexplore scoped/biased by the answers. If the user already provided a path (scope hint), do not re-ask about scope — only ask the questions whose answers aren't already implied by the prompt.

### Progress reporting

During execution, announce progress at two levels so the user can see the skill is alive and roughly where it is. Keep messages short — one line each, no decoration.

**Stage announcements** (3 top-level, in this order):

1. *"Exploring codebase..."*
2. *"Cross-referencing knowledge base..."*
3. *"Compiling findings..."*

**Area announcements** (within each stage, only when the area is non-trivial):

- *"  - Reading auth handlers (3 files)..."*
- *"  - Loading backend-engineering/secure-coding/..."*
- *"  - Aggregating findings by severity..."*

Don't announce every individual file. Group by area and emit one line per area as you enter it.

## Domain Detection

| Signal | Domain | Context files to read |
|---|---|---|
| Go, Rust, Java, Python backend, viper, envconfig, pydantic-settings | **Backend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/configuration/README.md` (8 areas) |
| React, Vue, Angular, VITE_*, NEXT_PUBLIC_*, REACT_APP_*, window.__CONFIG__ | **Frontend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/configuration/README.md` (base) + `https://raw.githubusercontent.com/guidomantilla/best-practices/main/frontend-engineering/configuration/README.md` (no secrets in client, build/runtime/server-only, tamper-able config) |

| LLM SDK, model configs, temperature, prompt templates, Langfuse | **AI** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/configuration/README.md` (base) + `https://raw.githubusercontent.com/guidomantilla/best-practices/main/ai-engineering/configuration/README.md` (model versions, prompts as config, hyperparams, multi-provider) |

Data engineering references backend configuration directly (same patterns).

## Review Process

1. **Detect domain and config approach**: backend (env vars, secret manager, config structs) or frontend (build-time vs runtime vs server-only, public prefixes).
2. **Map config sources**: identify where configuration comes from (env vars, files, remote, hardcoded).
3. **Identify secrets**: find anything that looks like a credential, key, token, or connection string. In frontend: check if secrets are in client-exposed vars (VITE_*, NEXT_PUBLIC_*).
4. **Scan against applicable areas**: backend (8 areas: sources, environments, secrets, flags, validation, config-as-code, runtime vs static). Frontend (additionally: no secrets in client, build/runtime/server-only distinction, API keys safe for client, tamper-able config, env detection).
5. **Report findings**: list each issue with impact, location, and fix.
6. **Recommend tooling**: based on detected domain and stack, suggest applicable tools.
7. **Offer capabilities**: based on findings, offer additional deliverables.

## Review Areas

1. **Config sources and precedence** — is there a clear, documented precedence? Are sources consolidated in one place?
2. **Environment management** — is there environment parity? Are there `if env == "prod"` code paths?
3. **Local development** — direnv/.envrc vs dotenv/.env? Is local config simulating production correctly?
4. **Secrets management** — are secrets in code, git, config files, or properly managed? Is there rotation?
5. **Config validation** — does the app validate all config at startup? Does it fail fast on missing/invalid values?
6. **Scattered config reads** — are there `os.Getenv()` / `process.env` calls scattered throughout business logic instead of a single entry point?
7. **Feature flags** — are there stale flags? Nested flags? Flags without defaults? Flags deep in domain logic?
8. **Config as code** — are config changes versioned and reviewable? Or manual edits on servers/dashboards?

These 8 areas are the minimum review scope. Flag additional configuration issues beyond these based on the detected architecture or deployment model.

## Impact Assessment

| Impact | Criteria |
|---|---|
| **High** | Security risk (secret exposed), production crash risk (missing config not validated), or data loss |
| **Medium** | Operational friction (can't rotate secrets without redeploy), environment divergence, stale flags creating dead code |
| **Low** | Suboptimal structure, minor inconsistencies, config that works but isn't clean |

## Detection Patterns

### Scattered config reads (High impact)
```go
// BAD — os.Getenv deep in business logic
func ProcessPayment(amount float64) error {
    apiKey := os.Getenv("PAYMENT_API_KEY")  // ← scattered read
    // ...
}
```
```python
# BAD — os.environ in service layer
def send_notification(user_id: str):
    token = os.environ["SLACK_TOKEN"]  # ← scattered read
    # ...
```

**What to flag:** any `os.Getenv`, `os.environ`, `process.env`, `System.getenv`, `env::var` outside of the config initialization module.

### Missing validation
```go
// BAD — no validation, silent default
port := os.Getenv("PORT")
if port == "" {
    port = "8080"  // ← silent default for potentially critical config
}
```

**What to flag:** config reads without validation, string-typed values used without parsing, silent defaults for values that should be explicit.

### Secrets in code
```python
# BAD — hardcoded secret
API_KEY = "sk-1234567890abcdef"

# BAD — secret in default value
db_url = os.getenv("DATABASE_URL", "postgres://admin:password123@prod-db:5432/app")
```

**What to flag:** string literals that look like keys/tokens/passwords, secrets as default values, `.env` files with real credentials committed.

## Tooling by Language

### Go
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Config | `viper` | Multi-source config with precedence | `go get github.com/spf13/viper` |
| Config | `envconfig` | Struct-based env var parsing + validation | `go get github.com/kelseyhightower/envconfig` |
| Config | `koanf` | Composable config providers | `go get github.com/knadh/koanf` |
| Secrets | `gitleaks` | Hardcoded secrets in code and git history | `brew install gitleaks` |

### Rust
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Config | `config-rs` | Layered config from files, env, defaults | `cargo add config` |
| Secrets | `gitleaks` | Hardcoded secrets in code and git history | `brew install gitleaks` |

### Python
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Config | `pydantic-settings` | Typed env var parsing + validation | `pip install pydantic-settings` |
| Config | `dynaconf` | Multi-source, environment-aware | `pip install dynaconf` |
| Secrets | `gitleaks` | Hardcoded secrets in code and git history | `brew install gitleaks` |
| Secrets | `detect-secrets` | Secrets in current code | `pip install detect-secrets` |

### TypeScript / JavaScript
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Config | `zod` | Schema validation for config at startup | `npm install zod` |
| Config | `convict` | Schema-based config management | `npm install convict` |
| Secrets | `gitleaks` | Hardcoded secrets in code and git history | `brew install gitleaks` |

### Cross-Language
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Secrets | `gitleaks` | Hardcoded secrets in code and git history | `brew install gitleaks` |
| Secrets | `trufflehog` | Deep secret scanning (git history) | `brew install trufflehog` |
| Feature flags | `grep` for stale flags | Flags set to 100% for > N days | manual review |
| Local dev | `direnv` | Env var management per directory | `brew install direnv` |

## Output Format

### Findings

For each finding:

```
### [IMPACT] — Short description
- **File**: path/to/file.go:42
- **Area**: which of the 8 configuration areas
- **Issue**: what's wrong
- **Fix**: specific action to take (with code sketch if applicable)
- **Tool**: which tool from the toolbox helps here
```

### Summary

```
## Summary
- High: N
- Medium: N
- Low: N
- Language(s): [detected]
- Config library: [detected or missing]
- Config validation: [present | partial | absent]
- Secrets handling: [secret manager | env vars only | hardcoded | mixed]
- Feature flags: [managed service | env vars | hardcoded | none detected]
- Scattered config reads: [count of reads outside config module]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable:

```
## What I Can Generate

Based on this review, I can also:

### For reproducibility (deterministic, CI-ready)
- [ ] **Generate a configuration validation script** for CI (typed schema validation + pre-commit secret detection). Catches drift and leaked credentials deterministically.

### For deeper exploration (LLM, non-deterministic)
- [ ] Generate a config module scaffold (typed struct + validation + fail-fast startup)
- [ ] Create a .envrc.example documenting all required configuration
- [ ] Identify all env vars the service needs (audit scattered reads)
- [ ] Propose a secrets migration plan (from hardcoded/env to secret manager)
- [ ] Identify stale feature flags and generate cleanup tasks
- [ ] Design a config precedence diagram for this service

Select which ones you'd like me to generate.

## What NOT to Do

- Don't recommend switching config libraries unless the current approach is fundamentally broken
- Don't flag every use of `os.Getenv` if it's in the config module (that's where it belongs)
- Don't prescribe a specific secret manager (Vault vs AWS SM vs GCP SM) — that's an infrastructure decision
- Don't flag config you haven't read — verify it's actually problematic
- Don't recommend runtime config for things that don't need it
- Don't flag feature flags as "stale" without evidence of when they reached 100%
- Don't assume the project needs a config library — for simple services with 3 env vars, a manual struct is fine

## Invocation examples

These cover the most useful patterns for this skill. The full list (7 patterns + bonus on context formats) is in the [Invocation patterns section of the README](../../README.md#invocation-patterns).

- **Blind** — `/assess-configuration`
- **Scoped** — `/assess-configuration config/ deploy/`
- **Deterministic** — `/assess-configuration y dame un script con gitleaks + validators custom`
