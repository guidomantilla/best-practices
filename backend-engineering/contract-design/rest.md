# REST API Contract Design

Best practices for designing HTTP REST APIs.

---

## 1. Resource Design

### Principles
- URLs represent **resources** (nouns), not actions (verbs)
- Use plural nouns: `/users`, `/orders`, `/products`
- Hierarchical relationships via nesting: `/users/{id}/orders`
- Maximum 2 levels of nesting (beyond that, use query params or top-level resources with filters)

### HTTP methods as verbs

| Method | Purpose | Idempotent | Safe |
|---|---|---|---|
| `GET` | Read resource(s) | Yes | Yes |
| `POST` | Create resource | No | No |
| `PUT` | Replace entire resource | Yes | No |
| `PATCH` | Partial update | No (can be made idempotent) | No |
| `DELETE` | Remove resource | Yes | No |

### Anti-patterns
- `/getUsers`, `/createOrder` — verbs in URLs (use HTTP methods for the verb)
- `/users/delete/123` — action as path segment
- Deeply nested: `/orgs/{id}/teams/{id}/members/{id}/permissions/{id}` — too deep, flatten
- Using `POST` for everything (not REST, just HTTP-RPC)

---

## 2. Naming Conventions

- **kebab-case** for URL paths: `/user-profiles`, `/order-items`
- **camelCase** or **snake_case** for JSON fields (pick one, be consistent across all APIs)
- Resource names are **domain terms**, not database table names
- Avoid abbreviations: `/organizations` not `/orgs` (unless it's a universally understood term)

---

## 3. Status Codes

Use HTTP status codes correctly — they ARE part of the contract.

### Success

| Code | When |
|---|---|
| `200 OK` | Successful GET, PUT, PATCH, DELETE |
| `201 Created` | Successful POST that created a resource (include `Location` header) |
| `202 Accepted` | Request accepted for async processing (not yet completed) |
| `204 No Content` | Successful DELETE or action with no response body |

### Client errors

| Code | When |
|---|---|
| `400 Bad Request` | Invalid request body, missing required fields, validation failure |
| `401 Unauthorized` | No auth credentials provided, or credentials invalid |
| `403 Forbidden` | Authenticated but not authorized for this resource/action |
| `404 Not Found` | Resource doesn't exist |
| `409 Conflict` | Resource state conflict (duplicate, version mismatch) |
| `422 Unprocessable Entity` | Request is syntactically valid but semantically wrong |
| `429 Too Many Requests` | Rate limit exceeded (include `Retry-After` header) |

### Server errors

| Code | When |
|---|---|
| `500 Internal Server Error` | Unexpected server failure |
| `502 Bad Gateway` | Upstream service failure |
| `503 Service Unavailable` | Temporarily unavailable (maintenance, overload) |
| `504 Gateway Timeout` | Upstream service timeout |

### Anti-patterns
- `200 OK` with `{"error": "user not found"}` — use proper status codes
- `500` for validation errors — that's a 400/422
- `404` for authorization failures — that's a 403 (or 404 if hiding resource existence)
- Custom status codes (700, 800) — non-standard, clients won't understand

---

## 4. Error Response Format

Standardize error responses across all endpoints.

### Recommended format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "field": "email",
        "message": "must be a valid email address"
      },
      {
        "field": "age",
        "message": "must be greater than 0"
      }
    ]
  }
}
```

### Principles
- Consistent shape across ALL error responses (same structure for 400, 401, 403, 500)
- Machine-readable `code` for clients to handle programmatically
- Human-readable `message` for debugging
- `details` array for field-level validation errors
- Never expose internal details (stack traces, SQL errors, internal paths) in production

---

## 5. Pagination

Every list endpoint must be paginated — unbounded lists are a DoS vector.

### Strategies

| Strategy | How | Best for |
|---|---|---|
| **Offset-based** | `?page=3&per_page=20` | Simple UIs, jumpable pages |
| **Cursor-based** | `?after=cursor_abc&limit=20` | Large datasets, real-time feeds, stable ordering |
| **Keyset-based** | `?after_id=123&limit=20` | Same as cursor but using actual field values |

### Response metadata

```json
{
  "data": [...],
  "pagination": {
    "total": 1423,
    "page": 3,
    "per_page": 20,
    "next": "/users?page=4&per_page=20",
    "prev": "/users?page=2&per_page=20"
  }
}
```

### Anti-patterns
- No pagination (returns all 100K records)
- Offset pagination on large datasets (offset 50000 = DB scans 50K rows)
- No `total` or `next` link (client can't know if there's more)
- Inconsistent pagination style across endpoints

---

## 6. Filtering, Sorting, Search

### Filtering
```
GET /orders?status=pending&created_after=2026-01-01
GET /users?role=admin&active=true
```

### Sorting
```
GET /users?sort=created_at:desc
GET /products?sort=price:asc,name:asc
```

### Search
```
GET /users?q=john
GET /products?search=laptop
```

### Anti-patterns
- Filter in request body for GET (violates HTTP semantics)
- No way to filter — client must fetch all and filter client-side
- Unbounded search without pagination

---

## 7. Versioning

### Strategies

| Strategy | Example | Trade-off |
|---|---|---|
| **URL path** | `/v1/users` | Explicit, simple, but all endpoints "move" together |
| **Header** | `Accept: application/vnd.myapp.v2+json` | Clean URLs, harder to test in browser |
| **Query param** | `/users?version=2` | Easy to use, but pollutes query space |

### Principles
- Start with v1 from day one (adding versioning later is painful)
- Only version on **breaking changes** — additive changes don't need a new version
- Maintain old versions for a documented deprecation period
- Communicate deprecation via headers (`Deprecation: true`, `Sunset: date`)

---

## 8. Authentication & Rate Limiting

### Auth patterns
- Bearer token in `Authorization` header: `Authorization: Bearer <token>`
- API keys for service-to-service: `X-API-Key: <key>` (or in `Authorization`)
- Never in URL query params (logged, cached, visible in browser history)

### Rate limiting headers
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 997
X-RateLimit-Reset: 1620000000
Retry-After: 30
```

Return `429 Too Many Requests` when exceeded.

---

## 9. Request/Response Design

### Principles
- **Consistent envelope**: either always wrap responses or never (don't mix)
- **Minimal response**: don't return the entire object on every operation if not needed
- **Expand/include**: let clients opt-in to related resources (`?include=orders,address`)
- **Partial responses**: let clients specify fields they need (`?fields=id,name,email`)

### Anti-patterns
- Different response shapes for the same resource across endpoints
- Returning sensitive fields (password hash, internal IDs) in responses
- No way to get related resources without N+1 separate requests
- Inconsistent field names (camelCase in one endpoint, snake_case in another)

---

## Tooling

| Tool | What it does |
|---|---|
| **OpenAPI / Swagger** | Define REST contract as spec, generate docs and clients |
| **Spectral** | Lint OpenAPI specs for quality and consistency |
| **Prism** | Mock server from OpenAPI spec (test consumers before implementation) |
| **openapi-generator** | Generate client SDKs and server stubs from spec |
| **Redoc / Swagger UI** | Generate interactive documentation from spec |
