# API Contract Consumption

How frontend consumes APIs — client generation, caching, error handling, and data fetching patterns.

For API **design** (how to build the contract), see [`../../backend-engineering/contract-design/`](../../backend-engineering/contract-design/README.md). This file covers the **consumer** side.

### Zero Trust Assumptions

Every API call from the frontend operates under zero trust:
- **Every request carries a credential** — JWT in header or HttpOnly cookie. No anonymous calls to protected endpoints.
- **Every response comes from an authenticated service** — the browser validates TLS certificates. Never disable certificate validation.
- **Every endpoint is defended server-side** — frontend controls UI visibility, backend controls access. Hiding a button is not authorization.
- **The network is not trusted** — always HTTPS, even in development where possible.

For the full zero trust perspective, see [`../../zero-trust/`](../../zero-trust/README.md). For frontend-specific security, see [`../secure-coding/`](../secure-coding/README.md).

---

## 1. Client Generation

Don't hand-write API clients. Generate them from the contract.

### By protocol

| Protocol | Generate from | Tools |
|---|---|---|
| **REST** | OpenAPI spec | openapi-generator, orval, openapi-typescript |
| **GraphQL** | Schema (SDL) | graphql-codegen, Apollo codegen |
| **gRPC** | .proto files | protoc + grpc-web, Connect-Web |

### What you get
- TypeScript types for requests and responses (compile-time safety)
- Function signatures that match the API exactly
- Automatic updates when the spec changes (regenerate, type errors show breaking changes)

### Principles
- **Contract is the source of truth** — never manually define types that the spec already defines
- **Regenerate on CI** — check that generated code is up to date (fail if spec changed but code wasn't regenerated)
- **Wrap generated clients** — don't use generated code directly in components. Wrap in a service layer (can add auth headers, error mapping, retries)

### Anti-patterns
- Hand-written API types that drift from the actual API (type says `string`, API returns `number`)
- Generated client used directly in components (coupling to API shape in UI code)
- No regeneration check in CI (spec changes, frontend types are stale for weeks)
- Generating but not using the types (generate then cast to `any`)

---

## 2. Data Fetching Patterns

### Server State Libraries

| Library | For | Key feature |
|---|---|---|
| **TanStack Query (React Query)** | REST/fetch | Cache, revalidation, pagination, infinite scroll |
| **SWR** | REST/fetch | Stale-while-revalidate, simpler API |
| **Apollo Client** | GraphQL | Normalized cache, local state, subscriptions |
| **URQL** | GraphQL | Lightweight, extensible, simpler than Apollo |
| **tRPC** | TypeScript full-stack | End-to-end type safety without code generation |

### Principles
- **Use a server-state library** — don't manage loading/error/cache state manually (Redux for API data is an anti-pattern)
- **Stale-while-revalidate**: show cached data immediately, refetch in background
- **Deduplicate requests**: if 5 components need the same data, one request — library handles this
- **Invalidate on mutation**: after a write, invalidate related queries (React Query: `queryClient.invalidateQueries`)

### Patterns

```typescript
// TanStack Query — fetch + cache + loading/error state
const { data, isLoading, error } = useQuery({
  queryKey: ['users', userId],
  queryFn: () => api.getUser(userId),
  staleTime: 5 * 60 * 1000, // 5 minutes before refetch
});

// Mutation with invalidation
const mutation = useMutation({
  mutationFn: api.updateUser,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['users'] });
  },
});
```

### Anti-patterns
- `useEffect` + `useState` for data fetching (no caching, no dedup, race conditions, no loading states handled properly)
- API data in Redux/Zustand (manual cache management, stale data, complex reducers for loading/error)
- No staleTime (refetch on every component mount — unnecessary network traffic)
- No error handling (loading spinner forever when API returns 500)

---

## 3. Optimistic Updates

Update the UI immediately before the server confirms — roll back if it fails.

### When to use
- Low-risk mutations where the server almost always succeeds (toggle like, mark as read, reorder items)
- UX demands instant feedback (social media interactions, drag-and-drop)

### When NOT to use
- High-risk mutations (payment, delete account — wait for confirmation)
- Complex multi-step operations (too many things to roll back)
- When the server frequently rejects (high failure rate = confusing flickering)

### Pattern
```typescript
const mutation = useMutation({
  mutationFn: api.toggleLike,
  onMutate: async (postId) => {
    // Cancel in-flight refetches
    await queryClient.cancelQueries({ queryKey: ['post', postId] });
    // Snapshot current state
    const previous = queryClient.getQueryData(['post', postId]);
    // Optimistically update
    queryClient.setQueryData(['post', postId], (old) => ({
      ...old,
      liked: !old.liked,
    }));
    return { previous }; // context for rollback
  },
  onError: (err, postId, context) => {
    // Rollback on failure
    queryClient.setQueryData(['post', postId], context.previous);
  },
  onSettled: () => {
    // Refetch to ensure consistency
    queryClient.invalidateQueries({ queryKey: ['post', postId] });
  },
});
```

### Anti-patterns
- Optimistic update without rollback (failed mutation, UI shows wrong state permanently)
- Optimistic update on payment/financial operations (user sees "paid" but it failed)
- No `onSettled` invalidation (optimistic state becomes stale if server made additional changes)

---

## 4. Error Handling from APIs

### Error response mapping
Frontend should translate API errors into user-facing messages:

```typescript
// API returns structured error
{ "error": { "code": "VALIDATION_ERROR", "details": [{ "field": "email", "message": "invalid" }] } }

// Frontend maps to form errors
const fieldErrors = response.error.details.reduce((acc, d) => {
  acc[d.field] = d.message;
  return acc;
}, {});
```

### HTTP status → UI behavior

| Status | UI behavior |
|---|---|
| `400` | Show validation errors on form fields |
| `401` | Redirect to login |
| `403` | Show "not authorized" message |
| `404` | Show "not found" page or message |
| `409` | Show conflict (e.g., "someone else edited this") |
| `429` | Show "too many requests, try again in X seconds" |
| `500` | Show generic error, log to error tracker |
| `503` | Show "service unavailable, try again later" |
| Network error | Show "no internet connection" or retry prompt |

### Principles
- **Centralize error handling** — interceptor/middleware, not per-component
- **User-friendly messages** — never show raw API error or stack trace to user
- **Retry on transient errors** — 503, network error → automatic retry with backoff (library handles this)
- **Distinguish errors** — validation (user can fix) vs server error (user can't fix, just report)

### Anti-patterns
- Generic "Something went wrong" for every error (user can't act)
- Showing raw API messages to users (`"relation users does not exist"`)
- No 401 handling (user gets stuck on broken page instead of redirected to login)
- No retry on network errors (one blip = failure, user refreshes manually)
- Error handling per component (inconsistent, easy to forget)

---

## 5. Pagination & Infinite Scroll

### Patterns

| Pattern | UX | Implementation |
|---|---|---|
| **Page numbers** | Traditional, jumpable | `useQuery` with `page` param, prefetch next page |
| **Load more button** | Appends to list | `useInfiniteQuery`, manual trigger |
| **Infinite scroll** | Auto-loads on scroll | `useInfiniteQuery` + intersection observer |
| **Virtual list** | Renders only visible items (10K+ items) | @tanstack/react-virtual, react-window |

### Principles
- **Prefetch next page** — anticipate the user's next action (hover over "next" → prefetch)
- **Show loading state per page** — not a full-screen spinner for page 2
- **Virtual list for large lists** — rendering 10,000 DOM nodes kills performance
- **Preserve scroll position** — navigate away and back → user is where they left off

### Anti-patterns
- Loading all data upfront (10K items fetched and rendered at once)
- Infinite scroll without virtual list (DOM nodes accumulate → memory + performance degradation)
- No loading indicator (content just appears, user doesn't know it's loading)
- Pagination resets on navigation back (user was on page 5, goes back, starts at page 1)

---

## References

- [TanStack Query Documentation](https://tanstack.com/query/latest)
- [SWR Documentation](https://swr.vercel.app/)
- [Apollo Client Documentation](https://www.apollographql.com/docs/react/)
- [orval — OpenAPI Client Generator](https://orval.dev/)
