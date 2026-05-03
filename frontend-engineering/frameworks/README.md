# Frontend Frameworks — How They Implement the Principles

The principles in this repo are framework-agnostic. This document shows how each major framework implements them — because the "how" varies significantly.

This is NOT a framework tutorial. It maps best practices to framework-specific idioms.

---

## Framework Overview

| Framework | Rendering | Reactivity | Component model | Ecosystem maturity |
|---|---|---|---|---|
| **React** | Client (SPA), SSR/SSG (Next.js) | Virtual DOM, re-render on state change | Functions + hooks | Very mature, largest ecosystem |
| **Vue** | Client (SPA), SSR/SSG (Nuxt) | Proxy-based reactive system | Options API or Composition API | Mature, growing ecosystem |
| **Angular** | Client (SPA), SSR (Angular Universal) | Zone.js + signals (v17+) | Classes + decorators + modules | Mature, opinionated, enterprise |
| **Svelte** | Client (SPA), SSR/SSG (SvelteKit) | Compile-time reactivity (no runtime) | Compile-to-JS components | Growing, small bundle by design |
| **Astro** | Static-first, Islands architecture | Per-island (bring your own: React, Vue, Svelte) | Any framework per island | Content-focused, partial hydration |

---

## State Management

| Principle | React | Vue | Angular | Svelte |
|---|---|---|---|---|
| **Local state** | `useState` | `ref()` / `reactive()` | Component property | `let variable` (reactive by default) |
| **Shared state (small)** | Context API | `provide/inject` | Service + `@Injectable` | Svelte stores (`writable`) |
| **Server state** | TanStack Query, SWR | TanStack Query, VueQuery | HttpClient + signals/RxJS | TanStack Query (Svelte adapter) |
| **Global state (if needed)** | Zustand, Jotai | Pinia | NgRx, signals-based store | Svelte stores |
| **URL state** | React Router (search params) | Vue Router (query) | Angular Router (queryParams) | SvelteKit ($page.url) |

### The principle is the same
- Server state in a server-state library, not in global store
- Local state stays local — lift only when needed
- URL for shareable state (filters, pagination)
- Derive, don't duplicate

---

## Component Composition

| Principle | React | Vue | Angular | Svelte |
|---|---|---|---|---|
| **Props (data down)** | `props` | `defineProps` | `@Input()` | `export let prop` |
| **Events (actions up)** | Callback props (`onClick`) | `defineEmits` | `@Output()` + EventEmitter | `dispatch('event')` |
| **Slots (content projection)** | `children` / render props | `<slot>` named slots | `<ng-content>` | `<slot>` |
| **Dependency injection** | Context API | `provide/inject` | DI system (built-in, powerful) | Context API (getContext/setContext) |

### The principle is the same
- Data flows down (props), actions flow up (events)
- Composition over configuration (small composable components, not mega-components with 30 props)
- DI for cross-cutting dependencies (not prop drilling)

---

## Side Effects & Lifecycle

| Principle | React | Vue | Angular | Svelte |
|---|---|---|---|---|
| **On mount** | `useEffect(() => {}, [])` | `onMounted()` | `ngOnInit()` | `onMount()` |
| **On update** | `useEffect(() => {}, [dep])` | `watch()` / `watchEffect()` | `ngOnChanges()` | `$:` reactive statement |
| **Cleanup** | Return from `useEffect` | `onUnmounted()` | `ngOnDestroy()` | `onDestroy()` |
| **Derived values** | `useMemo` | `computed()` | `computed()` (signals) | `$:` derived |

### The principle is the same
- Clean up subscriptions, timers, listeners (memory leaks)
- Derive instead of sync (computed > manual state updates)
- Minimize side effects — keep components pure where possible

---

## Data Fetching

| Principle | React | Vue | Angular | Svelte |
|---|---|---|---|---|
| **Recommended** | TanStack Query | TanStack Query / VueQuery | HttpClient + signals | TanStack Query (Svelte) |
| **SSR data** | Next.js `getServerSideProps` / Server Components | Nuxt `useAsyncData` / `useFetch` | Angular Universal resolvers | SvelteKit `load()` |
| **Optimistic updates** | TanStack Query `onMutate` | Same | Custom with signals | Same |
| **Error handling** | Error boundaries + query error state | `onErrorCaptured` + query error | ErrorHandler + interceptors | SvelteKit `handleError` |

### The principle is the same
- Use a server-state library (don't `useEffect` + `useState` for fetching)
- Handle loading, error, success states explicitly
- SSR for SEO-critical data, client-fetch for interactive data

---

## Form Handling

| Principle | React | Vue | Angular | Svelte |
|---|---|---|---|---|
| **Library** | React Hook Form, Formik | VeeValidate, FormKit | Reactive Forms (built-in) | Superforms, custom |
| **Validation** | Zod / Yup schema | Zod / Yup / Valibot | Built-in validators + custom | Zod + Superforms |
| **Server validation** | Display API errors per field | Same | Same | Same |

### The principle is the same
- Schema-based validation (Zod/Yup) — one schema for client AND server
- Show errors per field, not one global message
- Server validates too (client validation is UX, server validation is security)

---

## Testing

| Principle | React | Vue | Angular | Svelte |
|---|---|---|---|---|
| **Component tests** | Testing Library + Vitest/Jest | Testing Library + Vitest | TestBed + Jasmine/Karma or Vitest | Testing Library + Vitest |
| **E2E** | Playwright / Cypress | Same | Same | Same |
| **Mocking APIs** | MSW | MSW | MSW or HttpClientTestingModule | MSW |

### The principle is the same
- Test behavior (what user sees), not implementation (internal state)
- MSW for API mocking (network-level, framework-agnostic)
- E2E with Playwright for critical paths

---

## Performance

| Principle | React | Vue | Angular | Svelte |
|---|---|---|---|---|
| **Avoid unnecessary re-renders** | `React.memo`, `useMemo`, `useCallback` | Automatic (proxy-based, granular) | `OnPush` change detection, signals | Automatic (compile-time, granular) |
| **Code splitting** | `React.lazy` + `Suspense` | `defineAsyncComponent` | Lazy loaded routes/modules | Dynamic `import()` |
| **Bundle analysis** | `@next/bundle-analyzer` | `rollup-plugin-visualizer` | `webpack-bundle-analyzer` | `rollup-plugin-visualizer` |

### The principle is the same
- Code split by route (minimum)
- Analyze bundle regularly
- Some frameworks need manual optimization (React), others are optimized by default (Svelte, Vue)

---

## When to Choose What

| Scenario | Consider |
|---|---|
| Large enterprise team, need structure and conventions | **Angular** (opinionated, built-in everything) |
| Largest ecosystem, most hiring availability | **React** (+ Next.js for SSR/SSG) |
| Balance between flexibility and conventions | **Vue** (+ Nuxt for SSR/SSG) |
| Smallest bundle, compile-time optimization | **Svelte** (+ SvelteKit for SSR/SSG) |
| Content-heavy site with some interactivity | **Astro** (static-first, islands, use any framework per island) |

This is a trade-off, not a ranking. See [`../../well-architected/trade-off-analysis.md`](../../well-architected/trade-off-analysis.md).

---

## Anti-patterns (cross-framework)

- Choosing framework because "it's popular" without evaluating team expertise and project needs
- Fighting the framework (React patterns in Angular, Angular patterns in React)
- Not using the framework's recommended patterns (custom state management when the framework provides one)
- Framework-specific lock-in in business logic (domain code should be framework-agnostic where possible)
- Migrating frameworks without a clear reason (migration cost is enormous)
