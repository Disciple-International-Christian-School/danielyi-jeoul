# Daniel's Scale — UI Design System

**Language / 언어:** [English](UI_DESIGN_SYSTEM.md) | [한국어](UI_DESIGN_SYSTEM.ko.md)

## September 28, 2026 dashboard reference

Help SEONDO operators understand the week, identify guidance targets, and reach the next action. Following PR #10 typography/contrast work, the design revised hierarchy, spacing, repeated components, and state communication.

### Information order

1. Today/weekday, Monday-based week-of-month, responsibility scope.
2. Reflection targets → missing → double-submission → physical training → disciplinary committee.
3. Weekly calendar, department-merit generation, and reflection/notice/settlement actions.
4. Student scores with target filters, search, and sorting.

### Visual rules

Warm paper background, subtle card borders, dark-green weekly panel. Keep Pretendard Variable, tabular numerals, and right-aligned scores. Use amber for missing counts; red only when double-submission targets exist. Counts represent students and may overlap across cards; disclose that in the workflow.

Keep card order on all sizes; mobile uses two columns and a final full-width card. Distinguish loading, failed, unconfigured, partial, and complete merit generation. Query settlement state independently of student rows. Lead-only department/settlement links stay restricted. Support visible keyboard focus, semantic headings/tables/buttons/links, and reduced motion.

### Components

- src/components/dashboard.tsx: data-driven view, search/filter/sort/navigation.
- src/components/dashboard.css: dashboard styling and reusable visual reference.
- src/App.tsx: existing queries and responsibility-scope container.
- src/index.css: shared sidebar/topbar/content width/focus styling.

### Verification and limits

Local TypeScript/Vite checks and first PR CI run 36417547820 passed. A temporary Deploy Preview rendered the actual DashboardView with synthetic data. Desktop, 390px, 320px, and dark mode were checked; body and scroll width were both 320 at the smallest viewport.

After an empty search, the training card cleared search and showed two targets; committee showed one; All restored six. Failed/unconfigured/empty states and hidden lead links for ordinary SEONDO were checked. Only an extension metadata error was observed, with no application runtime error.

This was synthetic UI verification, not an authenticated production-data check. Cloud Browser was used because the agent-browser daemon could not bind its socket. Temporary public/design-review pages and fixtures were excluded from the production bundle.

![Dashboard verified with synthetic data](design/dashboard-2026-09-28.jpg)
