---
name: assess-coding-principles
description: Review code for software design principles and best practices. Use when the user asks to review code quality, check design principles, assess maintainability, evaluate testability, or identify code smells. Triggers on requests like "review code quality", "check principles", "is this well designed", "review for maintainability", or "/assess-coding-principles".
category: LLM-pure
---

# Software Principles Review

Review code for violations of software design principles. Produce actionable findings with concrete refactoring suggestions — not generic advice.

## Invocation modes

How to interpret the user's prompt and adapt behavior. These rules apply BEFORE running Domain Detection.

### Scope hint (positional path)

If the first non-flag argument after the slash command looks like a path or glob (e.g., `/assess-coding-principles src/auth/` or `/assess-coding-principles terraform/`), restrict the autoexplore to that path. Treat everything else in the prompt as additional context.

If no path is provided AND intake is not triggered, after the first short response include a one-liner reminder: *"I'm reviewing the entire codebase. You can scope a future run with `/assess-coding-principles <path>`."*

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

   5. ¿Lenguaje principal?
   6. ¿Es código nuevo, refactor de legacy, o exploración?

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

## Context Files

Before reviewing, read this reference document for the full rule set:

- `https://raw.githubusercontent.com/guidomantilla/best-practices/main/backend-engineering/software-principles/README.md` — 11 principles, anti-patterns, design signals

## Review Process

1. **Detect the language and paradigm**: identify from file extensions and patterns (OOP, functional, hybrid, procedural).
2. **Understand the code**: read and understand what the code does before judging how it's written. Don't review code you haven't read.
3. **Identify the scope**: a function, a class, a module, a service — adjust granularity accordingly.
4. **Scan against applicable principles**: not all 11 principles apply to every piece of code — evaluate relevance based on context.
5. **Report findings**: list each issue with impact, location, principle violated, and suggested fix.
6. **Recommend tooling**: based on detected language, suggest applicable tools that would catch these issues automatically.
7. **Offer capabilities**: based on findings, offer additional deliverables from the capabilities menu.

## Principles

Review the code against these principles. Not all apply to every review — evaluate relevance based on the detected context.

1. **SRP** — Single Responsibility: one reason to change per unit
2. **OCP** — Open/Closed: extend without modifying existing code
3. **LSP** — Liskov Substitution: subtypes substitutable for base types
4. **ISP** — Interface Segregation: small, focused interfaces
5. **DIP** — Dependency Inversion: depend on abstractions, not concretions
6. **DI** — Dependency Injection: provide dependencies from outside, not created inside
7. **Interface-Based Development** — program to an interface, not an implementation; define interfaces at the consumer side
8. **DRY** — Don't Repeat Yourself: single source of truth for knowledge
9. **KISS** — Keep It Simple: simplest solution that works
10. **YAGNI** — You Aren't Gonna Need It: don't build for speculative requirements
11. **Composition Over Inheritance** — favor composing behaviors over class hierarchies
12. **Separation of Concerns** — business logic separate from infrastructure
13. **Law of Demeter** — only talk to immediate friends
14. **Fail Fast** — validate early, report errors immediately
15. **Testing as Design Feedback** — hard-to-test code = poorly designed code

These 15 principles are the minimum review scope. Flag additional design issues beyond these based on the detected architecture, patterns, or idioms of the language.

## Impact Assessment

Impact is assigned **per finding based on context**, not per principle. Consider:

- **High**: actively causes bugs, makes the code untestable, or will force cascading rewrites when requirements change
- **Medium**: creates friction for maintenance, makes onboarding harder, or couples components unnecessarily
- **Low**: minor readability issue, slightly suboptimal but not harmful

Do NOT flag everything. Only report issues that have real impact on maintainability, extensibility, or testability. Being pedantic creates noise and erodes trust.

## Pragmatism Rules

- **3 lines repeated twice is fine.** Don't flag DRY for trivial duplication that has no risk of diverging.
- **Not everything needs an interface.** If there's one implementation and no testing need, a concrete dependency is fine.
- **Context matters.** A 200-line function in a CLI script is different from a 200-line function in a domain service.
- **Prototypes and spikes get a pass.** If the code is explicitly experimental, don't review it like production code.
- **Don't prescribe architecture.** Report what's wrong with the current design, don't impose Clean Architecture on a simple CRUD app.

## Tooling by Language

### Go
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Complexity | `gocyclo` | Cyclomatic complexity per function | `go install github.com/fzipp/gocyclo/cmd/gocyclo@latest` |
| Complexity | `gocognit` | Cognitive complexity per function | `go install github.com/uudashr/gocognit/cmd/gocognit@latest` |
| Linter | `golangci-lint` | `cyclop`, `funlen`, `gocognit`, `depguard`, `dupl` | `brew install golangci-lint` |
| Architecture | `go-arch-lint` | Dependency direction rules | `go install github.com/fe3dback/go-arch-lint@latest` |
| Duplication | `jscpd` | Copy-paste detection | `npm install -g jscpd` |

### Rust
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Linter | `clippy` | Complexity, unnecessary patterns, idiomatic issues | `rustup component add clippy` |
| Metrics | `rust-code-analysis` | Cyclomatic/cognitive complexity, LOC | `cargo install rust-code-analysis-cli` |
| Duplication | `jscpd` | Copy-paste detection | `npm install -g jscpd` |

### Java
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Design | `PMD` | God class, coupling, complexity, duplication (CPD) | Maven/Gradle plugin |
| Design | `SpotBugs` | Code smells, bad practices | Maven/Gradle plugin |
| Architecture | `ArchUnit` | Architectural rules (layer dependencies, naming) | JUnit dependency |
| Metrics | `SonarQube` | Maintainability, complexity, duplication, debt | Docker or self-hosted |
| Duplication | `CPD` (PMD) | Copy-paste detection | Included with PMD |

### Python
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Linter | `pylint` | too-many-arguments, too-many-methods, complexity | `pip install pylint` |
| Complexity | `radon` | Cyclomatic complexity, maintainability index | `pip install radon` |
| Linter | `ruff` | Fast linter, complexity rules, import sorting | `pip install ruff` |
| Dependencies | `deptry` | Unused/missing dependencies | `pip install deptry` |
| Duplication | `jscpd` | Copy-paste detection | `npm install -g jscpd` |

### TypeScript / JavaScript
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Linter | `eslint` | max-params, max-depth, complexity, no-restricted-imports | `npm install eslint` |
| Architecture | `dependency-cruiser` | Module dependency rules, circular deps | `npm install dependency-cruiser` |
| Metrics | `plato` | Complexity visualization | `npm install -g plato` |
| Duplication | `jscpd` | Copy-paste detection | `npm install -g jscpd` |

### Cross-Language
| Category | Tool | What it detects | Install |
|---|---|---|---|
| Metrics | `SonarQube` | Maintainability, complexity, duplication, tech debt | Docker or self-hosted |
| Metrics | `Code Climate` | Maintainability score, duplication | SaaS |
| Duplication | `jscpd` | Cross-language copy-paste detection | `npm install -g jscpd` |

## Output Format

### Findings

For each finding:

```
### [IMPACT] — Short description
- **File**: path/to/file.go:42
- **Principle**: which principle is violated
- **Anti-pattern**: which specific anti-pattern from the reference
- **Issue**: what's wrong and why it matters
- **Suggestion**: how to improve (with code sketch if applicable)
- **Tool**: which tool from the toolbox would catch this automatically
```

### Summary

```
## Summary
- High: N
- Medium: N
- Low: N
- Language(s): [detected]
- Paradigm: [OOP | Functional | Hybrid | Procedural]
- Most violated principle: [which one]
```

### Capabilities Available

After the summary, list which additional deliverables are applicable based on findings:

```
## What I Can Generate

Based on this review, I can also:

### For reproducibility (deterministic, CI-ready)
- [ ] **Generate a complexity-and-structure CI report** (cyclomatic complexity, function length, dependency cycles, coupling metrics). Partial determinism — flags structural smells; design judgment still needs the skill.

### For deeper exploration (LLM, non-deterministic)
- [ ] Show refactoring (before/after code) for each finding
- [ ] Propose a progressive refactoring plan (ordered by impact, minimal disruption)
- [ ] Evaluate testability and suggest how to make the code testable
- [ ] Identify the dependency graph and suggest decoupling points
- [ ] Suggest architectural boundaries for this codebase

Select which ones you'd like me to generate.

## What NOT to Do

- Don't be pedantic — if it works, is readable, and has no maintenance risk, leave it alone
- Don't prescribe patterns the code doesn't need (no "you should use Strategy pattern here" on a 3-case switch)
- Don't flag style preferences as principle violations (tabs vs spaces, bracket placement)
- Don't flag code you haven't read
- Don't suggest refactoring that would break tests or change behavior without stating the risk
- Don't impose architectural patterns on simple code (no hexagonal architecture for a 50-line script)
- Don't recommend tools for languages not present in the project
- Don't flag DRY violations for test code (repetition in tests is often clarity)
- Don't assume — if the design intent is unclear, ask before flagging

## Invocation examples

These cover the most useful patterns for this skill. The full list (7 patterns + bonus on context formats) is in the [Invocation patterns section of the README](../../README.md#invocation-patterns).

- **Blind** — `/assess-coding-principles`
- **Scoped** — `/assess-coding-principles src/services/`
- **Roadmap** — `/assess-coding-principles dame un plan de refactor priorizado por impacto`
