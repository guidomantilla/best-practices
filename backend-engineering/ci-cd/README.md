# CI/CD Best Practices

Principles for continuous integration and continuous delivery/deployment. How to build, test, and ship software reliably and frequently. Platform-agnostic — applicable to any CI/CD system.

---

## 1. CI Fundamentals

Continuous Integration is not "having a pipeline". It's **integrating code frequently** into a shared branch with automated verification.

### Principles
- **Integrate frequently**: at least daily. Long-lived branches are the enemy of CI.
- **Trunk-based development**: short-lived feature branches (hours/days, not weeks), merge to main often
- **Automated verification**: every push triggers lint, test, build — no manual gates for basic quality
- **Fix broken builds immediately**: a broken main branch blocks the entire team. Revert or fix within minutes, not hours.
- **Everyone commits to main**: CI only works if the whole team participates. One person on a 3-week branch is not doing CI.

### Anti-patterns
- Feature branches that live for weeks/months (integration hell when merging)
- "CI" that only runs on the main branch (too late — you already merged broken code)
- Manual "please review and merge" that takes days (defeats the purpose of frequent integration)
- Green builds that don't actually test anything meaningful (false confidence)
- Builds that take 30+ minutes (feedback too slow, developers context-switch)

### What CI is NOT
- CI is not a tool (Jenkins, GitHub Actions, GitLab CI are tools that enable CI)
- CI is not "run tests on PR" — that's a prerequisite, not the practice
- CI is not optional for some team members

**Source:** Martin Fowler, *Continuous Integration* (2006); Jez Humble & David Farley, *Continuous Delivery* (2010)

---

## 2. Pipeline Design

A well-designed pipeline is fast, reliable, and gives clear feedback.

### Stages (typical order)

```
Lint → Test → Build → Scan → Publish → Deploy
```

| Stage | What it does | Fails on |
|---|---|---|
| **Lint** | Code formatting, style rules, static checks | Style violations, import errors |
| **Test** | Unit + integration tests | Test failures |
| **Build** | Compile, bundle, create artifact | Compilation errors, missing dependencies |
| **Scan** | Security (SAST, SCA, secrets), license checks | Vulnerabilities, leaked secrets |
| **Publish** | Push artifact to registry (container, package) | Registry auth failures |
| **Deploy** | Release to target environment | Failed health checks, rollback triggered |

### Principles
- **Fail fast**: cheapest checks first (lint before test, test before build). Don't wait 10 minutes for a build to find out a linter fails.
- **Parallelize independent stages**: lint and test can run in parallel. Build depends on test passing.
- **Cache aggressively**: dependencies (node_modules, go mod cache, pip cache), Docker layers, build outputs
- **Immutable artifacts**: build once, deploy the same artifact to every environment. Never rebuild per environment.
- **Pipeline as code**: pipeline definition lives in the repo (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`), versioned with the code.
- **Idempotent**: running the same pipeline twice on the same commit produces the same result.

### Anti-patterns
- Sequential stages that could be parallel (wasted time)
- No caching (installing 500MB of dependencies on every run)
- Rebuilding per environment (dev build ≠ prod build = bugs that only appear in prod)
- Pipeline config not in version control (managed via UI, no history, no review)
- Silent failures (stage fails but pipeline continues)
- One monolithic stage that does everything (can't identify what failed)

---

## 3. Build Artifacts

What the pipeline produces and how to manage it.

### Principles
- **Immutability**: once an artifact is built, it never changes. Same SHA, same binary, same image.
- **Versioning**: every artifact has a unique, traceable version (git SHA, semver tag, or both)
- **Reproducibility**: given the same commit, the build produces the same artifact (pin dependencies, use lockfiles, pin base images)
- **Single artifact, multiple environments**: build once → promote through dev → staging → prod. Config differs, artifact doesn't.

### Versioning strategies

| Strategy | Format | When to use |
|---|---|---|
| **Git SHA** | `myapp:a1b2c3d` | Continuous deployment, every commit is deployable |
| **Semver** | `myapp:1.2.3` | Libraries, packages, APIs with compatibility contracts |
| **Semver + SHA** | `myapp:1.2.3-a1b2c3d` | Both human-readable version and exact commit traceability |
| **Date-based** | `myapp:2026-05-01.1` | When releases are time-based, not feature-based |

### Anti-patterns
- Artifacts without version (`:latest` tag in production — which version is running?)
- Rebuilding for each environment (different artifact in prod than what was tested in staging)
- No artifact registry (artifacts exist only in CI ephemeral storage)
- Mutable tags (pushing a new image to the same tag — breaks reproducibility)
- Build depends on external state (downloading `latest` dependency at build time without lockfile)

### Tooling
| Category | Tool | Use case |
|---|---|---|
| **Container registry** | Docker Hub, GitHub Packages, ECR, GCR, Harbor | Store container images |
| **Package registry** | npm registry, PyPI, crates.io, Maven Central | Store libraries/packages |
| **Generic artifact store** | S3, GCS, Artifactory | Binaries, bundles, archives |

---

## 4. Deployment Strategies

How to release new versions to production with controlled risk.

### Strategies

| Strategy | How it works | Risk | Rollback speed |
|---|---|---|---|
| **Recreate** | Stop old, start new | Downtime during switch | Redeploy previous version |
| **Rolling** | Replace instances one by one | Partial new/old during rollout | Reverse the rollout |
| **Blue-Green** | Two identical environments, switch traffic | Full new version, instant switch | Switch back to old env |
| **Canary** | Route small % of traffic to new version, increase gradually | Minimal (only canary % affected) | Route 100% back to old |
| **Feature flags** | Deploy code to all, enable feature gradually | Zero deployment risk (code is already there) | Disable the flag |

### When to use each

| Strategy | Best for |
|---|---|
| **Recreate** | Dev/staging environments, stateful apps that can't run two versions |
| **Rolling** | Stateless services, K8s default, good enough for most cases |
| **Blue-Green** | When you need instant rollback with zero mixed-version traffic |
| **Canary** | High-traffic services where you want to validate with real users at low risk |
| **Feature flags** | Decoupling deploy from release, gradual rollout by user segment |

### Anti-patterns
- Deploying 100% at once with no rollback plan (all-or-nothing)
- Canary without metrics (releasing to 5% but not measuring if it's healthy)
- Blue-green without health checks (switching to a broken environment)
- No automated rollback trigger (relying on humans noticing degradation)
- "We'll just roll forward" without having tested that rolling forward is faster than rollback

---

## 5. Environment Promotion

How artifacts move from development to production.

### Flow
```
Build → Dev → Staging → Production
         ↓        ↓          ↓
      auto     auto/gate    gate
```

### Principles
- **Same artifact everywhere**: what runs in staging is exactly what runs in production (same image SHA)
- **Config differs, code doesn't**: environment differences are handled by configuration (env vars, config maps), not different builds
- **Gates between environments**: automated (tests pass, scans clean) or manual (approval for production)
- **Promotion is a promotion**: moving an existing artifact forward, not building a new one

### Gate types

| Gate | What it checks | Automated? |
|---|---|---|
| **Test gate** | All tests pass | Yes |
| **Security gate** | No critical/high vulnerabilities | Yes |
| **Approval gate** | Human approves production deploy | No (manual) |
| **Smoke gate** | Post-deploy health checks pass | Yes |
| **Soak gate** | No degradation after N minutes/hours | Yes (time-based) |

### Anti-patterns
- Different build per environment (staging artifact ≠ production artifact)
- No staging (dev → prod directly)
- Staging that doesn't mirror production (different infra, different scale, different config structure)
- Manual promotion without audit trail (who deployed what, when)
- Promotion blocked for days by approval bottlenecks

---

## 6. Rollback

How to revert a bad deployment quickly.

### Principles
- **Rollback must be faster than fix-forward**: if fixing takes 30 minutes and rollback takes 2 minutes, always rollback first
- **Rollback must be tested**: if you've never rolled back, you don't know if it works
- **Rollback must be automated**: one command/button, not a 15-step runbook
- **Database compatibility**: new code must work with old schema AND old code must work with new schema (backward compatible migrations)

### Rollback vs roll-forward

| | Rollback | Roll-forward |
|---|---|---|
| **When** | Immediately after detecting a problem | When the fix is trivial and faster than rollback |
| **How** | Redeploy previous known-good version | Push a fix commit through the pipeline |
| **Risk** | Low (known-good version) | Medium (new code under pressure) |
| **DB concern** | Must be backward compatible | Must handle both states |

### Database and rollback
- **Expand-contract pattern**: add new column → migrate code → remove old column. Never rename/delete in one step.
- **Backward compatible migrations**: new schema must work with old code (in case of rollback)
- **Irreversible migrations** (data deletion, column removal) should be a separate deploy from the feature that stops using them

### Anti-patterns
- No rollback mechanism (only option is fix-forward under pressure)
- Rollback that requires rebuilding (defeats the purpose — use immutable artifacts)
- Database migrations that break old code (rollback leaves app in broken state)
- Untested rollback process (find out it's broken during an incident)

---

## 7. Pipeline Security

The pipeline is part of your attack surface.

### Principles
- **Least privilege**: CI jobs get minimum required permissions. No admin tokens.
- **Secrets in secret store**: never in pipeline config files, never in logs. Use CI-native secrets (GitHub Secrets, GitLab CI Variables) or external vault.
- **Signed artifacts**: sign container images, verify signatures before deploy (cosign, Notary)
- **Pinned dependencies**: pin actions/images to SHA, not tags (`actions/checkout@sha` not `actions/checkout@v4`)
- **Audit trail**: who triggered what pipeline, what was deployed, when
- **SBOM (Software Bill of Materials)**: generate per release — list all dependencies, versions, licenses. Required for supply chain transparency and incident response ("are we affected by CVE-X?"). Tools: `syft`, `trivy sbom`, `cyclonedx-cli`.
- **Immutable workloads**: no SSH/exec into production. All changes go through the pipeline. Containers are rebuilt and redeployed, never patched in place. See `../../zero-trust/applications.md`.

### Supply chain (SLSA framework)

| Level | What it means |
|---|---|
| **SLSA 1** | Build process is documented |
| **SLSA 2** | Build service generates provenance (who built what, from which source) |
| **SLSA 3** | Build runs on hardened, isolated infrastructure |
| **SLSA 4** | Two-person review, hermetic builds, reproducible |

### Anti-patterns
- Secrets printed in logs (even accidentally via debug mode)
- Pipeline has write access to production without approval
- Using `latest` or unpinned versions of CI actions (supply chain attack vector)
- CI runners shared between projects without isolation
- `--no-verify` to skip hooks (bypasses security checks)
- Service account with admin permissions "because it's easier"

### Tooling
| Tool | What it does |
|---|---|
| **cosign** | Sign and verify container images |
| **SLSA provenance** | Generate build attestations |
| **StepSecurity Harden-Runner** | Harden GitHub Actions workflows |
| **Checkov** | Scan CI/CD config for misconfigurations |

---

## 8. Monorepo CI

Special considerations when multiple services/packages live in one repo.

### Principles
- **Affected detection**: only build/test what changed (not the entire repo on every commit)
- **Dependency graph**: understand which packages depend on which — a change in a shared library triggers builds for all consumers
- **Selective pipelines**: each service/package has its own pipeline definition, triggered by path filters
- **Shared tooling**: linting, formatting, security scanning configs shared across packages

### Strategies

| Strategy | How it works | Tools |
|---|---|---|
| **Path filters** | Pipeline triggers only when specific paths change | GitHub Actions `paths:`, GitLab `rules:changes:` |
| **Affected packages** | Compute dependency graph, run affected packages | Nx, Turborepo, Bazel, Pants |
| **Label/tag based** | CI detects labels or commit tags to determine scope | Custom scripts |

### Anti-patterns
- Building everything on every commit (CI takes 45 minutes for a README change)
- No dependency graph (changing a shared lib doesn't trigger consumer builds — bugs shipped)
- Per-service CI that ignores shared dependencies
- Single pipeline for all services (can't deploy one service independently)

---

## 9. Pipeline Variations by Tech Type

The principles are universal. The implementation varies.

### By application type

| Tech | Build stage | Test stage | Deploy stage |
|---|---|---|---|
| **Backend (containerized)** | `docker build` → push to registry | Unit + integration (testcontainers) + API tests | K8s rollout, ECS deploy, Cloud Run |
| **Backend (binary)** | `go build` / `cargo build` / `mvn package` | Unit + integration | Systemd restart, scp + restart |
| **Frontend (SPA)** | `npm run build` → static assets | Unit + E2E (Playwright) | CDN upload + invalidation, Vercel/Netlify |
| **Frontend (SSR)** | `npm run build` → Node server or container | Unit + E2E | K8s, Vercel, serverless |
| **Data pipeline** | Package DAGs, validate schemas | Data quality checks, integration tests | Orchestrator sync (Airflow, Dagster) |
| **Mobile** | Signed binary (IPA/APK/AAB) | Unit + device tests + screenshots | App Store/Play Store, OTA (CodePush) |
| **Library/Package** | Compile + package | Unit + property-based tests | Publish to registry (npm, PyPI, crates.io) |

### By deployment target

| Target | Deploy mechanism | Rollback | Config injection |
|---|---|---|---|
| **Kubernetes** | Helm upgrade, ArgoCD sync, kubectl apply | Revision rollback, revert image tag | ConfigMaps, Secrets, env vars |
| **Serverless** | SAM deploy, Terraform apply, `serverless deploy` | Redeploy previous version, traffic shifting | Env vars, SSM parameters |
| **Traditional (VM/bare metal)** | SSH + restart, Ansible, systemd | Symlink swap, restart with previous binary | Env vars, config files |
| **Static/CDN** | S3 sync + CloudFront invalidation, Vercel deploy | Redeploy previous build | Build-time env vars, runtime config.js |
| **PaaS** | `git push heroku`, `fly deploy`, Railway | Rollback to previous release | Platform env vars |

---

## 10. DORA Metrics

Four metrics that measure engineering team performance. Use them to identify bottlenecks, not to punish.

| Metric | What it measures | Elite | Low |
|---|---|---|---|
| **Deployment frequency** | How often you deploy to production | On-demand (multiple/day) | Less than once per month |
| **Lead time for changes** | Commit to production | Less than 1 hour | More than 6 months |
| **Change failure rate** | % of deploys that cause incidents | 0-5% | 46-60% |
| **Mean time to recover (MTTR)** | Time from incident to resolution | Less than 1 hour | More than 6 months |

### How CI/CD affects DORA
- Fast pipelines → lower lead time
- Automated testing → lower change failure rate
- Automated rollback → lower MTTR
- Trunk-based dev + CI → higher deployment frequency

### How to instrument

Each metric has a clear data source. The skill is correlating them, not collecting them — most of the data already exists in your CI, your VCS, and your incident tracker.

| Metric | Source of truth | How to compute |
|---|---|---|
| **Deployment frequency** | CD events (the moment a deploy succeeds in production) | Count successful production deploys per day / week. Source: GitHub Actions deploy job, ArgoCD sync events, Spinnaker pipeline events, the CD platform's audit log. |
| **Lead time for changes** | PR merge timestamp → first production deploy that includes that PR | For each merged PR, find the production deploy that first contained its commit. Lead time = `deploy_time - merge_time`. Source: VCS API (merge time) + CD events (deploy time + commit SHA). |
| **Change failure rate** | Incidents linked to deploys / total deploys | For each incident, link it to the deploy that introduced the regression (manual tag or auto-correlation by time window). CFR = incidents-from-deploys / total-deploys over a window. Source: incident tracker (PagerDuty, Opsgenie, Incident.io) + CD events. |
| **Mean time to recover** | Incident open → incident resolved timestamps | For each incident: `MTTR = resolved_at - opened_at`. Average over the window. Source: incident tracker. |

Practical rules:
- **Tag deploys with the commit SHA and PR list.** Without this, lead time and CFR can't be computed automatically.
- **Tag incidents with the deploy that caused them** (post-mortem field, even if backfilled the next day). Without this, CFR is guesswork.
- **Pick a consistent window.** Rolling 30 or 90 days is standard. Comparing across windows of different sizes is meaningless.
- **Production-only.** Deploys to staging/QA don't count. If they do, you'll game your own metrics.

### Tooling

| Type | Tools | Notes |
|---|---|---|
| **Managed DORA dashboards** | Datadog DORA Metrics, Sleuth, LinearB, Faros AI, Apollo (GitHub native) | Auto-correlate from VCS + CI + incident-tracker integrations. Lowest setup cost, locked into the vendor's correlation logic. |
| **Roll your own** | CI events → BigQuery / Snowflake; VCS via GitHub/GitLab API; incidents via PagerDuty webhooks; metrics in Grafana / Looker | Highest flexibility, you own the joins. Useful when you want non-standard slicing (per service, per team, per env). |
| **Open-source** | Four Keys (Google Cloud), Apache DevLake | Self-hosted dashboards. Reasonable middle ground. |

Most teams overestimate the work. A first version is usually:
1. Tag every deploy in CD with `{commit_sha, pr_number, env, timestamp}`.
2. Pipe deploy events to a single store (BigQuery table, Cloud Logging dataset, even a CSV in S3 to start).
3. Pull merged PRs from VCS API daily, join on commit SHA → lead time.
4. Pull incidents from the tracker daily, join on deploy timestamp ± 24h or explicit tag → CFR + MTTR.

You can have the four numbers in a week. Refining the correlation (auto-tag incidents to deploys, exclude reverts, etc.) is the long tail.

### Anti-patterns
- Measuring DORA without acting on findings.
- Using DORA to compare teams (context differs).
- Gaming metrics (deploying empty commits to boost frequency).
- Ignoring MTTR (deploying fast but recovering slowly = fragile system).
- Computing lead time from first commit instead of merge — penalizes long-lived branches arbitrarily; merge-to-prod is the actionable interval.
- Counting failed deploys as deploys (inflates frequency, deflates CFR).

**Source:** Nicole Forsgren, Jez Humble, Gene Kim — *Accelerate* (2018)

---

## Tooling

### CI/CD Platforms
| Tool | Type | Best for |
|---|---|---|
| **GitHub Actions** | SaaS (integrated) | GitHub-hosted repos, simple to complex pipelines |
| **GitLab CI** | SaaS / self-hosted | GitLab repos, built-in container registry + security |
| **CircleCI** | SaaS | Fast builds, good caching, Docker-native |
| **Jenkins** | Self-hosted | Legacy, maximum flexibility, plugin ecosystem |
| **Dagger** | Portable pipelines | CI-agnostic pipeline definitions (run anywhere) |
| **Earthly** | Portable builds | Reproducible builds, Dockerfile-like syntax |

### GitOps / Continuous Deployment
| Tool | What it does |
|---|---|
| **ArgoCD** | K8s GitOps — syncs cluster state to git |
| **Flux** | K8s GitOps — pull-based deployment |
| **Spinnaker** | Multi-cloud deployment orchestration |

### Monorepo
| Tool | What it does |
|---|---|
| **Nx** | JS/TS monorepo — affected detection, caching |
| **Turborepo** | JS/TS monorepo — task orchestration, caching |
| **Bazel** | Multi-language — hermetic builds, dependency graph |
| **Pants** | Multi-language — Python, Go, Java monorepo support |

---

## References

- [Martin Fowler — Continuous Integration](https://martinfowler.com/articles/continuousIntegration.html)
- [Jez Humble & David Farley — *Continuous Delivery* (2010)](https://continuousdelivery.com/)
- [Nicole Forsgren et al. — *Accelerate* (2018)](https://itrevolution.com/product/accelerate/)
- [SLSA Framework](https://slsa.dev/)
- [DORA Metrics](https://dora.dev/guides/dora-metrics-four-keys/)
- [Trunk-Based Development](https://trunkbaseddevelopment.com/)

For the well-architected perspective on operational excellence (CI/CD + IaC + observability as a unified pillar), see [`../../well-architected/operational-excellence.md`](../../well-architected/operational-excellence.md).
