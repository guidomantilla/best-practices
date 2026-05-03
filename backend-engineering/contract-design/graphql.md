# GraphQL Contract Design

Best practices for designing GraphQL schemas and APIs.

---

## 1. Schema Design

### Principles
- **Schema-first**: define the SDL (Schema Definition Language) before implementation
- Types represent domain entities, not database tables
- Use clear, descriptive type and field names
- Separate query (read) from mutation (write) clearly

### Naming conventions
- Types: `PascalCase` (`User`, `Order`, `PaymentMethod`)
- Fields: `camelCase` (`firstName`, `createdAt`, `orderItems`)
- Enums: `SCREAMING_SNAKE_CASE` values (`PENDING`, `IN_PROGRESS`, `COMPLETED`)
- Mutations: verb + noun (`createUser`, `cancelOrder`, `updateProfile`)
- Queries: noun or get + noun (`user`, `orders`, `currentUser`)

### Anti-patterns
- CRUD-style mutations (`createX`, `readX`, `updateX`, `deleteX`) for everything — GraphQL isn't REST
- Schema that mirrors database schema 1:1 (expose domain concepts, not tables)
- One massive `Query` type with 50 fields (organize with meaningful types)
- Generic types (`Item`, `Thing`, `Data`) — be specific

---

## 2. Nullability

### Principles
- Fields are **nullable by default** in GraphQL — be intentional about `!` (non-null)
- Mark fields as non-null (`!`) only when you're certain they will ALWAYS have a value
- Non-null means a failure to resolve that field will propagate up and null the parent

### Guidelines
- `id: ID!` — an existing object always has an ID
- `name: String!` — only if it's truly required in all cases
- `email: String` — nullable unless guaranteed to exist
- List fields: `orders: [Order!]!` — the list itself is never null, and items in it are never null (but list can be empty)

### Anti-patterns
- Everything non-null (`!`) — one resolver failure cascades and nulls entire responses
- Everything nullable — clients can't trust anything, need null checks everywhere
- Inconsistent approach across the schema

---

## 3. Pagination

### Relay Connection Pattern (recommended)

```graphql
type Query {
  orders(first: Int, after: String, last: Int, before: String): OrderConnection!
}

type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
  totalCount: Int
}

type OrderEdge {
  node: Order!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

### Simple pagination (for simpler use cases)
```graphql
type Query {
  orders(limit: Int, offset: Int): OrderList!
}

type OrderList {
  items: [Order!]!
  total: Int!
  hasMore: Boolean!
}
```

### Anti-patterns
- Unbounded list fields (no pagination = performance bomb)
- Offset pagination on large datasets
- No `hasNextPage` indicator (client doesn't know when to stop)

---

## 4. Mutations

### Input types
```graphql
type Mutation {
  createOrder(input: CreateOrderInput!): CreateOrderPayload!
}

input CreateOrderInput {
  customerId: ID!
  items: [OrderItemInput!]!
}

type CreateOrderPayload {
  order: Order
  errors: [UserError!]!
}

type UserError {
  field: String
  message: String!
  code: ErrorCode!
}
```

### Principles
- Each mutation gets its own `Input` type and `Payload` type
- Payload includes both the result AND potential errors (don't rely only on GraphQL errors for business logic)
- Use `UserError` for domain/validation errors, GraphQL errors for system failures
- Mutations should be specific actions (`cancelOrder`, `addItemToCart`) not generic CRUD

### Anti-patterns
- Reusing the same input type across multiple mutations
- Returning just the entity (no error information in payload)
- Using GraphQL errors for validation failures (clients can't handle them gracefully)
- One `updateEntity` mutation with all fields optional (impossible to know what changed)

---

## 5. N+1 Problem

The #1 performance issue in GraphQL.

### The problem
```graphql
# Client requests:
query {
  orders {        # 1 query to get orders
    customer {    # N queries to get each customer (one per order)
      name
    }
  }
}
```

### Solutions

| Solution | How | When |
|---|---|---|
| **DataLoader** | Batch + cache resolver calls within a single request | Default approach for all relationship resolvers |
| **Eager loading** | Pre-load relationships in the parent resolver | When you always need the relationship |
| **Query complexity limits** | Reject overly complex queries | Protection, not solution |

### Anti-patterns
- No DataLoader (every resolver hits the DB independently)
- DataLoader with no cache (batches but still duplicates within request)
- Ignoring the problem because "it works in dev with 10 records"

---

## 6. Authentication & Authorization

### Principles
- Auth at the **resolver level**, not at the schema level (some fields may be public, others private)
- Use directives for declarative auth: `@auth(requires: ADMIN)`
- Context carries the authenticated user (set in middleware, available to all resolvers)
- Never expose fields that the user shouldn't see — filter at the resolver, don't rely on client not querying them

### Anti-patterns
- All-or-nothing auth (either you're logged in and see everything, or you see nothing)
- Auth logic scattered in individual resolvers without a pattern (use directives or middleware)
- Sensitive fields visible but "empty" for unauthorized users (leaks schema structure)

---

## 7. Query Depth & Complexity

Protect against abusive queries.

### Limits to enforce
- **Max depth**: reject queries deeper than N levels (e.g., 7)
- **Query complexity**: assign cost to fields, reject queries exceeding total cost
- **Max aliases**: prevent alias-based DoS
- **Timeout**: per-query execution timeout

### Anti-patterns
- No limits (a single recursive query can DoS your server)
- Complexity limits so tight that legitimate queries fail
- Rate limiting by IP only (not by query cost)

---

## 8. Schema Evolution

### Safe changes
- Add new types, fields, enum values
- Add new arguments with defaults
- Deprecate fields (`@deprecated(reason: "Use newField instead")`)

### Breaking changes
- Remove types or fields (without deprecation period)
- Change field types
- Make nullable fields non-null
- Remove enum values

### Deprecation pattern
```graphql
type User {
  name: String! @deprecated(reason: "Use firstName and lastName")
  firstName: String!
  lastName: String!
}
```

Keep deprecated fields working for a defined period, then remove.

---

## Tooling

| Tool | What it does |
|---|---|
| **graphql-codegen** | Generate TypeScript types, resolvers, client hooks from schema |
| **Apollo Studio** | Schema registry, breaking change detection, usage analytics |
| **graphql-eslint** | Lint GraphQL schemas and operations |
| **GraphQL Voyager** | Visualize schema relationships |
| **Stellate** | GraphQL CDN/caching layer |
| **Pothos / Nexus** | Code-first schema builders (TypeScript) |
