---
name: assess-secure-coding
description: Review code for security vulnerabilities, data privacy compliance, and secure coding best practices. Use when the user asks to review code for security issues, check compliance with HIPAA/GLBA/CCPA/GDPR/LGPD/PCI-DSS, audit data handling, or validate secure coding patterns. Triggers on requests like "security review", "check for vulnerabilities", "is this HIPAA compliant", "review this for security", or "/assess-secure-coding".
---

# Secure Code Review

Review code for security vulnerabilities and data privacy compliance. Produce actionable findings — not generic advice.

## Domain Detection

Detect the domain from the code being reviewed and read the appropriate reference files:

| Signal | Domain | Context files to read |
|---|---|---|
| Go, Rust, Java, Python with HTTP handlers, gRPC, DB queries | **Backend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/secure-coding/README.md` |
| React, Vue, Angular, Svelte, .tsx/.jsx, Next.js, CSS/HTML | **Frontend** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/secure-coding/README.md` (base) + `https://raw.githubusercontent.com/guidomantilla/best-practices/main/frontend-engineering/secure-coding/README.md` (frontend-specific) |
| dbt, Airflow, Dagster, Spark, pandas, SQL transforms, Parquet | **Data** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/secure-coding/README.md` (base) + `https://raw.githubusercontent.com/guidomantilla/best-practices/main/data-engineering/secure-coding/README.md` (data-specific) |
| LLM SDK imports (anthropic, openai, langchain, llamaindex), prompt templates, tool_use, embeddings | **AI** | `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/secure-coding/README.md` (base) + `https://raw.githubusercontent.com/guidomantilla/best-practices/main/ai-engineering/secure-coding/README.md` (AI-specific: prompt injection, guardrails, data leakage) |

Always read:
- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/data-privacy/README.md` — US, EU, Brazil, Colombia laws + PCI DSS, SOC 2, EU AI Act

In a monorepo, detect domain per file/module — different parts of the codebase may be different domains.

## Review Process

1. **Detect the domain and language(s)**: identify domain from imports, file patterns, and framework signals. Read the appropriate context files.
2. **Classify the data**: determine what type of data the code handles (PII, PHI, NPI, cardholder data, public).
3. **Identify jurisdiction and regulations**: based on the project context (client location, user base, data type), determine which regulations apply.
4. **Scan against security areas**: backend (12 areas), frontend (XSS, CSP, cookies, step-up auth, third-party scripts), data (access controls, PII in pipelines, masking, pipeline integrity).
5. **Report findings**: list each issue with severity, location, and fix.
6. **Recommend tooling**: based on detected language(s) and domain, suggest applicable tools.
7. **Offer capabilities**: based on findings and project context, offer additional deliverables.

## Security Areas

Review the code against these 12 areas. Not all areas apply to every project — evaluate relevance based on the detected context.

1. **Injection** — SQL, command, XSS, SSTI, NoSQL, LDAP, header, log injection
2. **Authentication & Identity** — passwords, MFA, brute force, session management, JWT, password storage
3. **Authorization & Access Control** — BOLA/IDOR, function-level auth, privilege escalation, RBAC, CORS, CSRF
4. **Data Protection & Cryptography** — encryption in transit/rest, weak algorithms, insecure random, hardcoded secrets, data leakage
5. **Input & Output Handling** — validation, mass assignment, excessive data exposure, path traversal, file upload, deserialization
6. **Supply Chain & Dependencies** — CVEs, typosquatting, lockfile tampering, unsigned packages, transitive vulnerabilities, CI/CD poisoning
7. **Configuration & Infrastructure** — default credentials, unnecessary services, security headers, open ports, container/K8s/IaC misconfigs
8. **Error Handling & Resilience** — fail-open vs fail-closed, verbose errors, panics, resource exhaustion, rate limiting, DoS via input
9. **Logging, Monitoring & Incident Response** — audit logs, PII in logs, alerting, log tampering, breach notification
10. **API-Specific Security** — BOLA, excessive data exposure, resource consumption, SSRF, unsafe consumption of third-party APIs
11. **Concurrency & Memory Safety** — race conditions, TOCTOU, double-spend, data races, deadlocks, goroutine/thread leaks
12. **Data Privacy & Compliance** — regulation-specific requirements based on detected jurisdiction

Severity is assigned **per finding based on context**, not per area. The same vulnerability type can be critical in a public API handling PHI and low in an internal admin tool with no sensitive data.

These 12 areas are the minimum review scope. Flag additional context-specific risks beyond these categories based on the detected stack, architecture, or threat model.

## Compliance Checks

Based on the jurisdiction and data type detected in step 3, apply the corresponding requirements from the data-privacy reference document:

| Data type | Regulations to check |
|---|---|
| Health (PHI) | HIPAA, GDPR (if EU), LGPD (if BR) |
| Financial (NPI) | GLBA, PCI DSS (if cardholder data) |
| Payment cards | PCI DSS 4.0 |
| Personal data (US consumers) | CCPA/CPRA + applicable state laws |
| Personal data (EU residents) | GDPR |
| Personal data (BR residents) | LGPD |
| Personal data (CO residents) | Ley 1581/2012 |
| Children's data | COPPA (US), GDPR Art. 8 (EU), LGPD (BR) |
| AI/ML training data | EU AI Act, CCPA ADMT provisions |
| Education records | FERPA |

Do not apply regulations that don't correspond to the project's jurisdiction. If jurisdiction is unclear, ask.

## Security Toolbox by Language

### Go
| Category | Tool | What it does | Install |
|---|---|---|---|
| SAST | `gosec` | Security issues in Go code | `go install github.com/securego/gosec/v2/cmd/gosec@latest` |
| SAST | `semgrep` | Multi-language static analysis | `pip install semgrep` |
| Linter | `staticcheck` | Bugs, performance, some security | `go install honnef.co/go/tools/cmd/staticcheck@latest` |
| SCA | `govulncheck` | Go vulnerability database | `go install golang.org/x/vuln/cmd/govulncheck@latest` |
| SCA | `trivy` | Dependency scanning | `brew install trivy` |
| Secrets | `gitleaks` | Hardcoded secrets | `brew install gitleaks` |
| Container | `trivy` | Docker image CVEs | (same binary) |

### Rust
| Category | Tool | What it does | Install |
|---|---|---|---|
| SCA | `cargo-audit` | Vulnerable crates in Cargo.lock | `cargo install cargo-audit` |
| SCA | `cargo-deny` | Vulnerabilities, licenses, bans | `cargo install cargo-deny` |
| SAST | `semgrep` | Static analysis | `pip install semgrep` |
| Linter | `clippy` | Common mistakes including security | `rustup component add clippy` |
| Secrets | `gitleaks` | Hardcoded secrets | `brew install gitleaks` |
| Fuzzing | `cargo-fuzz` | Fuzz testing | `cargo install cargo-fuzz` |

### Java
| Category | Tool | What it does | Install |
|---|---|---|---|
| SAST | `semgrep` | Static analysis with Java/Spring rules | `pip install semgrep` |
| SAST | `spotbugs` + `find-sec-bugs` | Security bugs in bytecode | Maven/Gradle plugin |
| SAST | `SonarQube` | Code quality and security | Docker or self-hosted |
| SCA | `trivy` | Dependency scanning | `brew install trivy` |
| SCA | `dependency-check` (OWASP) | NVD vulnerability check | Maven/Gradle plugin |
| Secrets | `gitleaks` | Hardcoded secrets | `brew install gitleaks` |

### Python
| Category | Tool | What it does | Install |
|---|---|---|---|
| SAST | `bandit` | Common security issues | `pip install bandit` |
| SAST | `semgrep` | Static analysis | `pip install semgrep` |
| SCA | `pip-audit` | Vulnerability database check | `pip install pip-audit` |
| SCA | `safety` | CVEs in requirements.txt | `pip install safety` |
| SCA | `trivy` | Dependency scanning | `brew install trivy` |
| Secrets | `gitleaks` | Hardcoded secrets | `brew install gitleaks` |

### TypeScript / JavaScript
| Category | Tool | What it does | Install |
|---|---|---|---|
| SAST | `semgrep` | Static analysis with JS/TS/React rules | `pip install semgrep` |
| SAST | `eslint-plugin-security` | ESLint security rules for Node.js | `npm install eslint-plugin-security` |
| SCA | `npm audit` | Known vulnerabilities in node_modules | built-in |
| SCA | `trivy` | Dependency scanning | `brew install trivy` |
| Secrets | `gitleaks` | Hardcoded secrets | `brew install gitleaks` |
| Headers | `helmet` | Security HTTP headers for Express/Node | `npm install helmet` |

### Cross-Language
| Category | Tool | What it does | Install |
|---|---|---|---|
| SAST | `semgrep` | Universal static analysis | `pip install semgrep` |
| Secrets | `gitleaks` | Git repo secret scanning | `brew install gitleaks` |
| Secrets | `trufflehog` | Deep secret scanning (git history) | `brew install trufflehog` |
| SCA | `trivy` | Dependencies + containers + IaC | `brew install trivy` |
| DAST | `OWASP ZAP` | Dynamic testing on running apps | `brew install --cask zap` |
| Container | `grype` | Container image vulnerability scanner | `brew install grype` |
| CI/CD | `checkov` | Scan GitHub Actions, CircleCI, GitLab CI configs | `pip install checkov` |
| CI/CD | `orca` | Pipeline security and misconfig detection | SaaS |
| CI/CD | `step-security` | Harden GitHub Actions workflows | GitHub App |
| Shell | `shellcheck` | Static analysis for bash/shell scripts | `brew install shellcheck` |

## Output Format

### Findings

For each finding:

```
### [SEVERITY] — Short description
- **File**: path/to/file.go:42
- **Area**: which of the 12 security areas
- **Rule**: specific rule violated
- **Issue**: what's wrong
- **Fix**: specific action to take
- **Tool**: which tool from the toolbox would catch this automatically
```

### Summary

```
## Summary
- Critical: N
- High: N
- Medium: N
- Low: N
- Language(s): [detected]
- Data classification: [PII | PHI | NPI | Cardholder | Public | Unknown]
- Jurisdiction: [US | EU | BR | CO | Multiple | Unknown]
- Applicable regulations: [list]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable to this project based on what was found:

```
## What I Can Generate

Based on this review, I can also:
- [ ] Show anti-patterns (vulnerable code vs secure code) for each finding
- [ ] Generate a threat model for this project
- [ ] Create an incident response plan template
- [ ] Build a pen testing checklist for this stack
- [ ] Detail architecture-specific risks for [detected pattern]
- [ ] Provide jurisdiction-specific legal details for [detected regions]
- [ ] Generate breach notification timelines for applicable regulations
- [ ] Create a scanning script (security-scan.sh) with tools for [detected languages]

Select which ones you'd like me to generate.
```

Only list capabilities that are relevant to the findings and context. Don't list all 8 every time.

## What NOT to do

- Don't give generic security advice unrelated to the actual code
- Don't suggest adding comments, docstrings, or documentation
- Don't recommend rewriting code that isn't a security issue
- Don't flag issues in code you haven't read
- Don't assume the worst — verify before flagging
- Don't recommend tools for languages not present in the project
- Don't apply regulations that don't correspond to the project's jurisdiction
- Don't list capabilities that aren't relevant to the current findings

## Invocation examples

These cover the most useful patterns for this skill. The full list (7 patterns + bonus on context formats) is in the [Invocation patterns section of the README](../../README.md#invocation-patterns).

- **Blind** — `/assess-secure-coding`
- **Narrative** — `/assess-secure-coding greenfield, datos PHI/PII, foco auth y APIs externas`
- **Deterministic** — `/assess-secure-coding después del review, generame un security-scan.sh con las herramientas recomendadas`
