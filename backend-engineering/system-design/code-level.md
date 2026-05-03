# Code-Level Design Patterns

Recurring solutions to common problems **inside** a class or module. Gang of Four (GoF) patterns and practical variations.

For design **principles** (SOLID, DRY, KISS, DI) that guide WHEN to use these patterns, see `../software-principles/README.md`.

---

## When to Use Patterns

### Do use a pattern when
- You recognize a recurring problem it solves
- The pattern reduces complexity compared to the ad-hoc alternative
- Other developers will recognize it (shared vocabulary)

### Don't use a pattern when
- The problem doesn't exist yet (YAGNI)
- A simpler solution works (a function is simpler than Strategy for 2 cases)
- You're using it to impress, not to solve (resume-driven development)

---

## Creational Patterns

### Factory Method / Abstract Factory

**Problem**: creating objects without specifying the exact class.

**When**: object creation logic is complex, varies by context, or should be decoupled from the consumer.

```go
// Factory function (simple Go idiom)
func NewStorage(config Config) Storage {
    switch config.Type {
    case "s3":
        return NewS3Storage(config)
    case "gcs":
        return NewGCSStorage(config)
    case "local":
        return NewLocalStorage(config)
    }
}
```

**Anti-pattern**: factory that returns only one type (pointless abstraction).

### Builder

**Problem**: constructing complex objects step by step.

**When**: object has many optional parameters, or construction has multiple steps.

```go
server := NewServer().
    WithPort(8080).
    WithTimeout(30 * time.Second).
    WithTLS(certFile, keyFile).
    Build()
```

**Anti-pattern**: builder for objects with 2-3 fields (just use a constructor).

### Singleton

**Problem**: exactly one instance of something.

**When**: truly global shared resource (connection pool, config, logger).

**Warning**: singletons are global state — hard to test, hide dependencies. Prefer dependency injection. Use singleton only when the runtime genuinely needs exactly one instance.

**Anti-pattern**: everything is a singleton (hidden global state, untestable code).

---

## Structural Patterns

### Adapter (Wrapper)

**Problem**: incompatible interfaces need to work together.

**When**: integrating third-party libraries, legacy code, or external APIs with your internal interfaces.

```go
// Your interface
type PaymentGateway interface {
    Charge(amount Money, card Card) (Receipt, error)
}

// Adapter wraps Stripe's SDK to match your interface
type StripeAdapter struct { client *stripe.Client }

func (a *StripeAdapter) Charge(amount Money, card Card) (Receipt, error) {
    // translate to Stripe's API
}
```

**Anti-pattern**: adapter that just proxies without any translation (unnecessary layer).

### Decorator (Middleware)

**Problem**: add behavior to an object without modifying it.

**When**: logging, caching, auth, metrics, retry — cross-cutting concerns around core logic.

```go
// Core
type UserService interface { GetUser(id string) (User, error) }

// Decorator adds logging
type LoggingUserService struct { next UserService; logger Logger }
func (s *LoggingUserService) GetUser(id string) (User, error) {
    s.logger.Info("getting user", "id", id)
    return s.next.GetUser(id)
}

// Decorator adds caching
type CachingUserService struct { next UserService; cache Cache }
```

Decorators compose: `Logging(Caching(Metrics(RealService)))` — each adds one behavior.

**Anti-pattern**: decorator that changes the core behavior (not decorating, it's replacing).

### Facade

**Problem**: complex subsystem needs a simple interface.

**When**: multiple internal components need to be orchestrated, but consumers shouldn't know the details.

**Anti-pattern**: facade that exposes all internal methods (not simplifying, just proxying).

---

## Behavioral Patterns

### Strategy

**Problem**: algorithm varies at runtime.

**When**: multiple ways to do the same thing, selected by context (sorting algorithms, payment methods, notification channels).

```go
type NotificationStrategy interface {
    Send(user User, message string) error
}

type EmailNotification struct{}
type SMSNotification struct{}
type PushNotification struct{}

// Selected at runtime based on user preference
func Notify(user User, msg string, strategy NotificationStrategy) error {
    return strategy.Send(user, msg)
}
```

**Anti-pattern**: strategy with one implementation that will never have a second (premature abstraction).

### Observer (Event/Listener)

**Problem**: when something happens, multiple components need to react without tight coupling.

**When**: event-driven within a single process (not between services — that's integration-level).

```go
type EventBus struct { listeners map[string][]Handler }
func (b *EventBus) Publish(event Event) { /* notify all listeners */ }
func (b *EventBus) Subscribe(eventType string, handler Handler) { /* register */ }
```

**Anti-pattern**: observer chains that create unpredictable execution order or circular notifications.

### Command

**Problem**: encapsulate a request as an object.

**When**: undo/redo, queuing operations, logging all actions, transactional behavior.

```go
type Command interface {
    Execute() error
    Undo() error
}

type CreateOrderCommand struct { order Order }
func (c *CreateOrderCommand) Execute() error { /* create */ }
func (c *CreateOrderCommand) Undo() error { /* cancel */ }
```

**Anti-pattern**: command pattern for simple CRUD with no undo/queue need (over-engineering).

### State Machine

**Problem**: object behavior changes based on internal state, with defined transitions.

**When**: order lifecycle, payment flow, document approval, any entity with distinct states and rules about transitions.

```
[Draft] → submit → [Pending Review]
[Pending Review] → approve → [Approved]
[Pending Review] → reject → [Draft]
[Approved] → publish → [Published]
```

**Principles**:
- Define all valid states explicitly (enum/type)
- Define all valid transitions (state + event → new state)
- Reject invalid transitions with clear errors
- Persist the current state (DB column)

**Anti-pattern**: state encoded as multiple booleans (`is_active`, `is_verified`, `is_published`) that create impossible combinations.

### Repository

**Problem**: abstract data access behind a clean interface.

**When**: always (for any non-trivial application). Core domain logic should not know whether data comes from PostgreSQL, MongoDB, or an in-memory map.

```go
type UserRepository interface {
    FindByID(ctx context.Context, id string) (User, error)
    FindByEmail(ctx context.Context, email string) (User, error)
    Save(ctx context.Context, user User) error
    Delete(ctx context.Context, id string) error
}

// PostgreSQL implementation
type PgUserRepository struct { db *sql.DB }

// In-memory implementation (for tests)
type InMemoryUserRepository struct { users map[string]User }
```

**Anti-pattern**: repository with 30 methods (violates ISP — split into reader/writer or domain-specific interfaces).

---

## Concurrency Patterns

### Worker Pool

**Problem**: process N tasks concurrently with bounded parallelism.

**When**: batch processing, parallel API calls, image processing — you need concurrency but not unbounded.

**Anti-pattern**: spawning one goroutine/thread per item without limit (resource exhaustion).

### Fan-out / Fan-in

**Problem**: distribute work across multiple workers, collect results.

**When**: parallel computation where results need to be aggregated.

### Circuit Breaker (code-level)

**Problem**: stop calling a failing dependency, fail fast instead.

**When**: external service is down, retrying makes it worse. Let it recover.

Note: this also appears at integration-level (service mesh) — see `integration-level.md`.

---

## When NOT to Use Patterns

- **3 lines of code solve it** → don't add an interface, factory, and strategy for something trivial
- **One implementation** → don't create an interface "in case we need another later"
- **Simple conditional** → `if/else` with 2-3 cases is clearer than Strategy pattern
- **No shared vocabulary needed** → if only you will ever read this code, don't pattern-ify it for an audience that doesn't exist

Patterns are tools. Use them when they help, not as ceremony.
