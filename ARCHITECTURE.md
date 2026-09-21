# 다니엘의 저울 (daniels-scale) — Architecture

Student merit/demerit (상점·벌점) management console for DICS. Admin-only — two roles
(선도부 SEONDO, 사생회 SASAENG), students never log in. Target repo:
https://github.com/hylen707/daniels-scale

---

## Where the project stands (2026-09-18)

Three generations of the same app exist:

1. **Lovable deploy** (mockup, code not extractable):
   https://pixel-perfect-match-0249.lovable.app — /dashboard, /students, /reflections,
   /punishments, /penalty-items. Reference for UI/UX only.
2. **Replit build** (copied into `danielyi-jeoul/` in this workspace) — much further along
   than "partial". Contains:
   - `attached_assets/Pasted-Build-*.txt` — **the original 35-section spec. Source of truth
     for business rules.**
   - `lib/db` — complete Drizzle schema: `admins`, `students`, `point_items`,
     `point_records`, `reflection_records`, `punishments` (soft deletes, indexes)
   - `lib/api-spec/openapi.yaml` — full REST contract; `lib/api-zod` +
     `lib/api-client-react` — orval-generated Zod schemas and react-query hooks
   - `artifacts/api-server` — Express 5 server with **all endpoints and most business
     rules implemented** (status detection, reflection lifecycle, punishment validation)
   - `artifacts/daniels-scale` — **complete React UI**, all 8 screens in `src/App.tsx`
     (dashboard, students, student detail, 벌점/상점 entry, reflections, punishments,
     point items + CSV import). Auth is Clerk (Replit default).
3. **This repo (daniels-scale)** — the production rebuild. Backend continues here on
   Supabase.

## Decision: Supabase-native backend (no Express server)

Drop the Express layer; move business logic into Postgres, talk to it with `supabase-js`
directly from the React app.

Why, given the Express server already works:
- It needs a host + Clerk replacement anyway. For a solo maintainer, a second runtime to
  operate is the biggest long-term cost.
- Every business rule in `school.ts` is derived-read logic or a write-time check — both
  map cleanly to views/triggers/RPC. Nothing needs a long-running server.
- Matches the SP Manager operational pattern already in production (Supabase + RLS +
  security_invoker views + Netlify), so one mental model for both school apps.
- The Express `summary()` does N+1 queries per student; a SQL view fixes that for free.

The Express code is not wasted: it is the **reference implementation** to port from, and
`openapi.yaml` + the spec doc define the contract the SQL must satisfy.

Rejected alternative: keep Express + Drizzle with Supabase as a plain Postgres host.
Only worth revisiting if server-side logic outgrows SQL (e.g. real Excel parsing,
scheduled jobs beyond pg_cron).

## Stack

- **Frontend**: React + Vite (reuse `artifacts/daniels-scale` UI nearly as-is), deployed
  to Netlify. Everything bundled — school networks block CDNs.
- **Auth**: Supabase Auth, email/password. `admins` table keyed by `auth.users.id` (uuid)
  carrying `role` (SEONDO | SASAENG) and `display_name`. Two accounts to start.
- **DB**: new Supabase project (separate from `dics-sp`). Schema as SQL migrations in
  `supabase/migrations/` from day one — version-controlled, unlike SP Manager's known gap.
- **Client data layer**: `supabase-js` reads from views, writes to tables/RPCs. The orval
  react-query hooks get replaced by a thin `src/lib/api.ts` exposing the same function
  shapes so page components change minimally.

## Schema (port of Drizzle schema, with fixes)

Tables (all soft-delete via `deleted_at` where history matters):

| Table | Notes vs Replit version |
|---|---|
| `admins` | `user_id` becomes uuid FK → `auth.users`; role enum SEONDO/SASAENG |
| `students` | unchanged: name, grade (1–6), deleted_at |
| `point_items` | unchanged: name, type POSITIVE/NEGATIVE, fixed_points, is_fixed, is_active |
| `point_records` | add FK `student_id → students`; keep `item` as text snapshot; `entered_by_name` stays manual text (spec §6 — never auto-fill from session) |
| `reflection_records` | add FK `point_record_id → point_records` (unique); deadline = record date |
| `punishments` | add FK; `violated_at timestamptz` (null = not violated) |

No `weekly_summary` table (spec §25 suggests one; not needed — weekly aggregates come
from `point_records` grouped by `date_trunc('week', recorded_at)`; history is queryable
because records are never hard-deleted).

## Business rules → Postgres constructs

All timestamps evaluated in **Asia/Seoul**, weeks are **Mon 00:00–Sun 23:59:59**.
(The Express port used UTC — fix this during the port.)

| Rule (spec §) | Construct |
|---|---|
| Reflection auto-created on NEGATIVE record, deadline = same day (§10) | trigger on `point_records` insert |
| Reflection status: SUBMITTED / MISSING / DOUBLE (미제출 + 다음날 경과 → 2배 대상) (§10) | computed column in `v_reflections` view — never stored, so it flips at midnight without a job |
| 체력훈련 대상: same week ≥3 벌점 records OR ≥8 벌점 (§11A) | `v_student_summary` view |
| 징계위원회 대상: month ≥20 벌점 (§11B) | `v_student_summary` |
| 처분 선택 필요: week ≥5 벌점, no active punishment (§14) — **missing in Express, add** | `v_student_summary` |
| 귀가금지 조건 충족: 3 consecutive weeks each ≥5 벌점 (§16) — **missing in Express, add** | `v_weekly_penalties` (per-student per-week totals) + window check in `v_student_summary` |
| Punishment validation: week ≥5 → exactly 1 type, ≥10 → exactly 2, only 운동금지/간식금지/면회금지, dates ordered (§14–15, 18) | `create_punishment` RPC (server-side check; client mirrors it) |
| Violation → 귀가금지 status (§17) | `record_violation` RPC stamps `violated_at`; status derived in view |
| 선생님 재량 벌점: 1–5 only, never fixed (§8) | CHECK via trigger on `point_records` + constraint on `point_items` |
| 상점/벌점 never netted (§34) | views expose separate `positive_points` / `negative_points` |

Views: `v_student_summary` (dashboard + student list, statuses as text[]),
`v_reflections` (reflection page rows with student/item/points joined),
`v_weekly_penalties`, `v_dashboard_counts`. All `security_invoker = true`.
Helper functions live in a **`private` schema** (lesson from SP Manager: keep them out of
PostgREST's `/rpc/` surface; note plpgsql bodies store schema refs as text).

## Authorization (RLS)

Server-side role enforcement per spec §3/§30 — RLS is the authorization layer, UI hiding
is cosmetic.

- All tables: no anon access; `authenticated` must exist in `admins`.
- SEONDO writes: `students`, `point_items`, `point_records`, `reflection_records`.
- SASAENG writes: `punishments` (via RPC).
- Both roles read everything (dashboard is shared).
- Never ship `service_role` to the client. Publishable key only.

## Data protection

Same rule as SP Manager: **these are minors — no student PII in the repo.** The schema
stores only name + grade (spec §4 forbids more). Seed files with real names, admin
credentials, and rosters stay out of git.

## Repo layout (target for hylen707/daniels-scale)

```
daniels-scale/
  supabase/
    migrations/          # schema, RLS, views, triggers, RPCs — numbered SQL
    seed.dev.sql         # fake students + sample items only (no real data)
  src/                   # React app, ported from danielyi-jeoul/artifacts/daniels-scale
    lib/supabase.ts      # client (publishable key, sessionStorage)
    lib/api.ts           # data layer replacing orval hooks
    App.tsx              # pages (keep structure; swap Clerk → Supabase Auth)
  docs/
    spec.md              # cleaned copy of the 35-section spec
  ARCHITECTURE.md        # this file
  index.html / vite.config.ts / package.json
```

The Replit monorepo (`danielyi-jeoul/`) stays local as reference; do not push it — it
contains Replit/Clerk plumbing we are abandoning.

## Build order

1. **Supabase project + migrations**: enums, 6 tables, FKs, indexes, private helpers.
2. **Views + triggers + RPCs**: port rules from `artifacts/api-server/src/routes/school.ts`
   against the table above; fix timezone; add the two missing statuses.
3. **RLS policies** + two admin accounts + dev seed.
4. **Frontend port**: copy React app, strip Clerk + `@workspace/api-client-react`,
   implement `lib/api.ts` on supabase-js, wire login screen (Korean, ID/password).
5. **Excel import**: keep the existing client-side CSV parse + preview, insert via
   supabase-js batch (per-row validation mirrors spec §20).
6. Netlify deploy from the new repo.

## Known gaps in the Replit reference (don't copy blindly)

- Week/month windows computed in UTC, not Asia/Seoul.
- 귀가금지 조건 충족 (3 consecutive weeks) and 처분 선택 필요 statuses absent.
- Reflections list shows "점수 기록 #id" instead of student name/item (Lovable shows the
  full row — follow Lovable).
- `PATCH /punishments/:id` skips Zod validation (raw `req.body`).
- Audit log (spec §31, "if practical") not implemented — Postgres trigger-based audit
  table is cheap to add later; not in v1.
