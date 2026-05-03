# Software Principles & Best Practices

Foundational principles for writing maintainable, extensible, and testable software. Language-agnostic — applicable to Go, Rust, Java, Python, TypeScript, and any OOP/functional hybrid.

---

## 1. SOLID

Five principles for object-oriented and module design.

### Single Responsibility Principle (SRP)

A class/module/function should have one reason to change.

- One responsibility = one axis of change
- If a class has multiple reasons to be modified (e.g., business logic + persistence + formatting), it violates SRP
- Applies at every level: function, class, module, service

**Anti-patterns:**
- God classes that handle validation, persistence, notification, and formatting
- Functions that do transformation AND side effects (I/O, DB, HTTP)
- Services that own multiple unrelated domains

**Source:** Robert C. Martin, *Agile Software Development* (2003)

### Open/Closed Principle (OCP)

Open for extension, closed for modification.

- Add new behavior without changing existing code
- Achieved through abstractions: interfaces, strategy pattern, polymorphism
- Not about never touching code — about designing so that new requirements don't force rewrites of stable code

**Anti-patterns:**
- Adding `if/else` or `switch` branches for every new type/case
- Modifying core logic every time a new requirement appears
- Hardcoding behavior that should be pluggable

**Source:** Bertrand Meyer, *Object-Oriented Software Construction* (1988); extended by Robert C. Martin

### Liskov Substitution Principle (LSP)

Subtypes must be substitutable for their base types without altering program correctness.

- If `B` extends `A`, any code using `A` should work with `B` without knowing the difference
- Violated when subclasses throw unexpected exceptions, ignore inputs, or change semantics
- Applies to interface implementations, not just inheritance

**Anti-patterns:**
- A subclass that throws `NotImplementedException` on inherited methods
- Overriding a method to do nothing or do the opposite of the contract
- Return types or preconditions that are stricter than the parent

**Source:** Barbara Liskov, *Data Abstraction and Hierarchy* (1987)

### Interface Segregation Principle (ISP)

Clients should not depend on interfaces they don't use.

- Prefer many small, focused interfaces over one large interface
- A class implementing an interface should use all of its methods
- Reduces coupling — changes to unused methods don't force recompilation/redeployment

**Anti-patterns:**
- One `Repository` interface with 20 methods when most consumers need 2-3
- Implementing interfaces with empty/no-op methods to satisfy the contract
- Forcing mocks to implement methods irrelevant to the test

**Source:** Robert C. Martin, *The Interface Segregation Principle* (1996)

### Dependency Inversion Principle (DIP)

High-level modules should not depend on low-level modules. Both should depend on abstractions.

- Depend on interfaces/contracts, not concrete implementations
- The direction of dependency points toward the domain, not toward infrastructure
- Enables testability (inject mocks), flexibility (swap implementations), and decoupling

**Anti-patterns:**
- Business logic directly instantiating database clients, HTTP clients, or file system calls
- Import chains that pull infrastructure into domain code
- Inability to test a function without a running database or external service

**Source:** Robert C. Martin, *Agile Software Development* (2003)

---

## 2. DRY — Don't Repeat Yourself

Every piece of knowledge must have a single, unambiguous, authoritative representation in a system.

- About **knowledge duplication**, not code duplication — two identical code blocks with different reasons to change are NOT a DRY violation
- Premature DRY (abstracting too early) is worse than repetition
- Applies to: logic, data schemas, configuration, documentation, constants

**Anti-patterns:**
- Same business rule implemented in 3 places that drift over time
- Copy-paste code that must be updated in sync (and isn't)
- Same validation logic in frontend, backend, and database layer without a shared source of truth

**When NOT to apply:**
- Two similar code blocks that serve different domains and will diverge
- Abstracting 3 lines into a helper used once — adds indirection without value
- Tests — repetition in tests is often clearer than DRY test helpers

**Source:** Andrew Hunt & David Thomas, *The Pragmatic Programmer* (1999)

---

## 3. KISS — Keep It Simple, Stupid

The simplest solution that works is the best solution.

- Simplicity is measured by cognitive load for the reader, not by line count
- Clever code is a liability — obvious code is an asset
- Complexity should be introduced only when the problem demands it, not preemptively

**Anti-patterns:**
- Abstracting for hypothetical future requirements that never arrive
- Using design patterns because they exist, not because they solve a current problem
- Generic frameworks for problems that have one concrete instance
- Metaprogramming/reflection/code generation when a plain function would do

**Source:** Kelly Johnson (Lockheed Skunk Works, 1960s); applied to software broadly

---

## 4. YAGNI — You Aren't Gonna Need It

Don't implement something until you actually need it.

- Build for today's requirements, not tomorrow's speculation
- Features not yet needed cost: maintenance, testing, cognitive load, coupling
- If it turns out you need it later, you'll know more about the requirement and build it better

**Anti-patterns:**
- Configuration options nobody asked for
- Plugin architectures for systems that will only ever have one implementation
- "Flexible" abstractions that serve one concrete case
- Building pagination, caching, or multi-tenancy before the first user exists

**Source:** Kent Beck, *Extreme Programming Explained* (1999)

---

## 5. Dependency Injection (DI)

Provide dependencies from outside rather than creating them inside.

- Constructor injection is the clearest form: all dependencies visible in the signature
- Enables testing (inject mocks/stubs), configuration (swap implementations per environment), and decoupling
- Does NOT require a DI framework — manual injection (passing arguments) is valid and often preferable

**Anti-patterns:**
- `new` / direct instantiation of infrastructure inside business logic
- Service locator pattern (hides dependencies, makes them implicit)
- Global singletons accessed directly from business code
- DI containers that make the dependency graph invisible

**Levels of DI:**
1. Constructor/function parameter injection (simplest, most explicit)
2. Interface-based injection (decouple contract from implementation)
3. Framework-managed injection (Spring, Wire, Dagger — useful at scale, adds indirection)

**Source:** Martin Fowler, *Inversion of Control Containers and the Dependency Injection pattern* (2004)

---

## 6. Interface-Based Development

Program to an interface, not an implementation.

- Define contracts (behavior) before implementations
- Allows multiple implementations: production, test, mock, different providers
- Keeps coupling at the boundary — internals can change freely

**Anti-patterns:**
- Consuming a concrete struct/class when only 2 methods are used (depend on the behavior, not the object)
- Interfaces that mirror a single implementation 1:1 (pointless abstraction)
- Interfaces defined by the implementor instead of by the consumer (wrong ownership)

**Design guideline:**
- Define interfaces where you USE them (consumer side), not where you implement them
- Keep interfaces small (ISP) — 1-3 methods is ideal
- If there's only one implementation and no testing need, you probably don't need an interface yet

**Source:** Erich Gamma et al., *Design Patterns: Elements of Reusable OO Software* (1994) — "Program to an interface, not an implementation"

---

## 7. Testing as Design Feedback

Unit tests are not just validation — they're a design tool.

- **Hard-to-test code = poorly designed code.** If a function needs 10 mocks to test, it has too many dependencies.
- TDD forces small, focused functions with clear inputs/outputs
- Tests reveal coupling: if changing one module breaks 50 tests, the design is too tangled
- Tests document behavior: a test is a specification of what the code does

**Design signals from tests:**
- Can't instantiate the class without a database? → DIP violation
- Test setup is 40 lines? → SRP violation (too many responsibilities)
- Must mock 8 interfaces? → class depends on too much (ISP/SRP)
- Test is fragile to implementation changes? → testing implementation, not behavior

**Anti-patterns:**
- Writing tests after the fact to hit coverage targets (tests that verify nothing useful)
- Testing private methods (sign of a class doing too much)
- Mocking everything including the thing you're testing
- Tests that pass when the code is wrong

**Source:** Kent Beck, *Test-Driven Development: By Example* (2003); Michael Feathers, *Working Effectively with Legacy Code* (2004)

---

## 8. Composition Over Inheritance

Favor composing objects/functions over class hierarchies.

- Inheritance creates tight coupling between parent and child — changes propagate unpredictably
- Composition is explicit: you choose what behaviors to include
- Most languages (Go, Rust) don't have classical inheritance by design

**Anti-patterns:**
- Deep inheritance trees (3+ levels) where behavior is scattered across ancestors
- Inheriting to reuse one method (use composition or a standalone function)
- Base classes that grow into god classes because every subclass "needs" something

**When inheritance is fine:**
- Truly "is-a" relationships with shared invariants (rare in practice)
- Framework requirements (extending a base controller, for example)
- Sealed/final hierarchies with exhaustive pattern matching (enums, ADTs)

**Source:** Erich Gamma et al., *Design Patterns* (1994) — "Favor object composition over class inheritance"

---

## 9. Separation of Concerns

Each component should address a single concern.

- Business logic should not know about HTTP, databases, or UI
- Infrastructure (persistence, messaging, transport) is a separate concern from domain logic
- Cross-cutting concerns (logging, auth, tracing) belong in middleware/decorators, not inline

**Layering patterns:**
- Clean Architecture / Hexagonal / Ports & Adapters — domain at center, infrastructure at edges
- The key insight is the same in all: **dependency arrows point inward toward the domain**

**Anti-patterns:**
- SQL queries inside HTTP handlers
- Business rules in database triggers or stored procedures (invisible logic)
- Domain objects that know how to serialize themselves to JSON, save to DB, and send emails

**Source:** Edsger Dijkstra, *On the role of scientific thought* (1974); Robert C. Martin, *Clean Architecture* (2017)

---

## 10. Law of Demeter (Principle of Least Knowledge)

Only talk to your immediate friends.

- A method should only call methods on: its own object, its parameters, objects it creates, its direct dependencies
- Avoid chains: `order.getCustomer().getAddress().getCity()` — each dot is a coupling point
- Violations create fragile code: changes to intermediate objects break distant callers

**Anti-patterns:**
- Train wrecks: `a.getB().getC().getD().doSomething()`
- Reaching through objects to access their internals
- Functions that need to "know" the structure of objects 3 levels deep

**Source:** Karl Lieberherr et al., Northeastern University (1987)

---

## 11. Fail Fast

Report errors at the earliest possible point.

- Validate inputs at the boundary — don't let invalid data propagate through the system
- Throw/return errors immediately rather than silently continuing with bad state
- A crash with a clear error is better than silent corruption

**Anti-patterns:**
- Swallowing errors / empty catch blocks
- Returning default values when input is invalid (hides bugs)
- Checking for errors 5 layers deep when you could have validated at entry
- Null/nil propagation through multiple function calls before crashing

**Source:** Jim Shore, *Fail Fast* (IEEE Software, 2004)

---

## References

### Books
- Robert C. Martin — *Clean Code* (2008), *Clean Architecture* (2017), *Agile Software Development* (2003)
- Martin Fowler — *Refactoring* (2018), *Patterns of Enterprise Application Architecture* (2002)
- Kent Beck — *Test-Driven Development: By Example* (2003), *Extreme Programming Explained* (1999)
- Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides — *Design Patterns: Elements of Reusable OO Software* (1994)
- Andrew Hunt & David Thomas — *The Pragmatic Programmer* (1999)
- Michael Feathers — *Working Effectively with Legacy Code* (2004)

### Online
- [SOLID Principles (Wikipedia)](https://en.wikipedia.org/wiki/SOLID)
- [Martin Fowler's Bliki](https://martinfowler.com/bliki/)
- [Refactoring Guru — Design Patterns](https://refactoring.guru/design-patterns)
