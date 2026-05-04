# Frontend-Specific Testing

Additions to the general testing practices for frontend. For the full testing reference (test pyramid, unit, integration, API, E2E, contract, performance, flaky tests), see [`../../backend-engineering/testing/`](../../backend-engineering/testing/README.md).

This file covers what's **different or additional** for frontend.

---

## 1. Component Testing

Test components in isolation — rendered in a test environment, not in a full browser.

### What to test
- Component renders correctly with given props
- User interactions produce expected behavior (click, type, select)
- Conditional rendering (shows/hides elements based on state)
- Error states and loading states
- Accessibility (correct ARIA attributes, keyboard navigation)

### What NOT to test
- Styling (use visual regression instead)
- Internal state directly (test behavior, not implementation)
- Third-party component internals (that the date picker works — trust the library)

### Principles
- **Test as the user would**: find elements by role, label, or text — not by CSS class or test ID
- **One component, one concern**: test the component's behavior, not its children's
- **Mock API calls, not components**: mock the data layer (MSW, mock service worker), render the real component tree

### Tooling
| Tool | What it does |
|---|---|
| **Testing Library** (React/Vue/Svelte) | Component testing with user-centric queries |
| **Vitest** | Fast test runner (Vite-native) |
| **MSW** (Mock Service Worker) | Mock API at the network level (not in component code) |
| **Storybook + test runner** | Test stories as component tests |

### Anti-patterns
- Snapshot tests as primary strategy (break on any change, nobody reviews the diff, committed blindly)
- Testing `querySelector('.my-class')` (coupled to CSS, breaks on style change)
- Mocking child components (`jest.mock('./Button')` — you're not testing the real thing)
- Testing `useState` values directly (implementation detail — test the rendered output)

---

## 2. Visual Regression Testing

Detect unintended visual changes by comparing screenshots.

### When to use
- Design systems / component libraries (visual consistency is critical)
- After CSS refactoring (did anything break visually?)
- Cross-browser rendering verification

### How it works
```
1. Capture baseline screenshots of components/pages
2. On PR, capture new screenshots
3. Diff against baseline
4. Human reviews visual diffs, approves or rejects
```

### Tooling
| Tool | What it does |
|---|---|
| **Chromatic** | Visual testing for Storybook (cloud diffing, review UI) |
| **Percy** | Visual testing platform (integrates with Playwright/Cypress) |
| **Playwright screenshots** | Built-in screenshot comparison |
| **BackstopJS** | Open-source visual regression |
| **Loki** | Visual testing for Storybook (local) |

### Principles
- **Not a replacement for functional tests** — visual regression catches CSS issues, not logic bugs
- **Review diffs manually** — auto-approve defeats the purpose
- **Stable baselines** — flaky screenshots (animation, dynamic content, timestamps) create noise
- **Component-level, not full-page** — more stable, faster, easier to review

### Anti-patterns
- Full-page screenshots as primary test (fragile — any text change, ad load, or dynamic content breaks it)
- Auto-approving baseline updates (defeats the purpose of visual review)
- No stable rendering (animations, randomized content, dates cause false diffs)
- Visual tests for every component (diminishing returns — focus on design system components)

---

## 3. Accessibility Testing (Automated)

Catch accessibility issues in CI — complements manual testing.

### What automated tests catch
- Missing alt text, missing labels
- Incorrect ARIA roles/attributes
- Color contrast violations
- Keyboard focus issues
- Heading hierarchy violations

### What they DON'T catch (need manual testing)
- Logical tab order (automated knows there's focus, not if the ORDER makes sense)
- Screen reader experience (does the flow make sense aurally?)
- Cognitive accessibility (is the content understandable?)
- Dynamic content announcements (live regions working correctly?)

### Integration in pipeline
```
Lint (eslint-plugin-jsx-a11y) → Component tests (axe-core) → E2E (axe + Playwright) → Manual audit (quarterly)
```

### Tooling
| Tool | Integration | What it does |
|---|---|---|
| **axe-core** | Jest, Vitest, Playwright, Cypress | Automated a11y rule checking |
| **eslint-plugin-jsx-a11y** | ESLint | Lint-time a11y checks for JSX |
| **Playwright axe** | E2E tests | A11y audit on real rendered pages |
| **Storybook a11y addon** | Storybook | A11y checks per story |
| **pa11y** | CLI / CI | Automated a11y audits on URLs |

### Anti-patterns
- Only automated testing (catches ~30% of a11y issues — manual review is essential)
- No a11y testing at all (accessibility is a legal requirement in many jurisdictions)
- Testing only on one browser (different screen readers + browsers behave differently)
- A11y tests disabled because "too many violations" (fix them, don't ignore them)

---

## 4. Frontend E2E — Additional Considerations

The general E2E practices in [`../../backend-engineering/testing/`](../../backend-engineering/testing/README.md) apply. These are frontend-specific additions:

### Selectors
- **Prefer**: `getByRole`, `getByLabel`, `getByText` (user-centric, accessible)
- **Acceptable**: `data-testid` (stable, but doesn't validate accessibility)
- **Avoid**: CSS selectors (`.btn-primary`), XPath, auto-generated IDs — fragile

### Handling async UI
- Use framework-aware waits (`waitFor`, `expect.toBeVisible()`, Playwright auto-wait)
- Never `sleep()` — use explicit conditions
- Handle loading spinners, skeleton screens, lazy-loaded content

### Cross-browser
- Test in Chrome + Firefox minimum (Playwright supports both natively)
- Safari/WebKit if targeting iOS users (Playwright supports WebKit)
- Don't test in every browser — diminishing returns beyond top 2-3

### Mobile viewport
- Test critical flows at mobile viewport sizes (responsive breakpoints)
- Playwright: `page.setViewportSize({ width: 375, height: 812 })` (iPhone)
- Not the same as real mobile testing — but catches responsive layout issues

---

## 5. Fitness Functions (Frontend)

Automated tests that validate frontend architecture characteristics in CI. Architecture degrades through small decisions — fitness functions catch it. For the full concept, see [`../../backend-engineering/system-design/methodology.md`](../../backend-engineering/system-design/methodology.md) §4 and [`../../well-architected/fitness-functions.md`](../../well-architected/fitness-functions.md).

### Frontend-specific fitness functions

| What it validates | Target | Tool | Fails build? |
|---|---|---|---|
| **Bundle size** | < 200KB gzipped (initial JS) | `size-limit`, `bundlesize` | Yes |
| **LCP** | < 2.5s (p75) | Lighthouse CI | Yes (or warn) |
| **INP** | < 200ms (p75) | Lighthouse CI | Yes (or warn) |
| **CLS** | < 0.1 | Lighthouse CI | Yes (or warn) |
| **Accessibility** | No critical axe violations | `axe-core` + Playwright | Yes |
| **CSP present** | All responses include CSP header | Custom integration test | Yes |
| **No console.log in prod** | Zero console statements in build | ESLint rule `no-console` | Yes |
| **No critical dep vulnerabilities** | Zero critical CVEs | `npm audit`, Trivy | Yes |
| **Import restrictions** | No circular deps, no banned imports | `eslint-plugin-import`, dependency-cruiser | Yes |

### Implementation
```json
// size-limit config (package.json or .size-limit.json)
[
  { "path": "dist/index.js", "limit": "200 KB" },
  { "path": "dist/vendor.js", "limit": "150 KB" }
]
```

```yaml
# Lighthouse CI in GitHub Actions
- run: lhci autorun
  env:
    LHCI_ASSERT__PRESET: lighthouse:recommended
    LHCI_ASSERT__ASSERTIONS__LARGEST_CONTENTFUL_PAINT: ["error", {"maxNumericValue": 2500}]
```

### Principles
- Start with **3 fitness functions** (bundle size, a11y, no critical CVEs) — add more as needed
- **Fail the build**, not just warn — warnings are ignored
- Review thresholds periodically — adjust as the application evolves

---

## References

- [Testing Library Documentation](https://testing-library.com/)
- [MSW Documentation](https://mswjs.io/)
- [Chromatic Documentation](https://www.chromatic.com/docs/)
- [axe-core Rules](https://dequeuniversity.com/rules/axe/)
- [Playwright Component Testing](https://playwright.dev/docs/test-components)
