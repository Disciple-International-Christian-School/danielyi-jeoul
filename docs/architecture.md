# 다니엘의 저울 (daniels-scale) — Architecture

Student merit/demerit (상점·벌점) management console for DICS. Admin-only — two roles
(선도부 SEONDO, 사생회 SASAENG), students never log in.

**Live:** https://dics-daniels-scale.netlify.app
**Repo:** https://github.com/shualoalumin/danielyi-jeoul
**Supabase:** DICS org, project `daniels-scale` (`jgrzsfomcwfiukkaqtos`, ap-northeast-2)

Initial build history: [LEGACY_INITIAL_BUILD.md](./LEGACY_INITIAL_BUILD.md). Ongoing changes: [EVOLUTION_LOG.md](./EVOLUTION_LOG.md). Business rules: [spec.md](./spec.md).

---

## Where the project stands (2026-09-21)

Production rebuild is deployed. Three generations still exist as reference:

1. **Lovable deploy** (mockup, code not extractable):
   https://pixel-perfect-match-0249.lovable.app — UI/UX reference only.
2. **Replit build** — hit the platform limit. After the port, `_replit/` (gitignored)
   keeps only `school.ts` and the Drizzle `schema/` as a frozen contrast. Clerk,
   Express hosting, orval clients, and the nested git were deleted.
3. **This repo** — Vite + supabase-js + Postgres views/RPCs/RLS. Netlify auto-deploys
   `main`. Two admin accounts (`seondo`, `sasaeng`) are linked.

## Decision: Supabase-native backend (no Express server)

Drop the Express layer; move business logic into Postgres, talk to it with `supabase-js`
directly from the React app.

Why, given the Express server already worked:
- It needed a host + Clerk replacement anyway. For a solo maintainer, a second runtime
  is the biggest long-term cost.
- Every business rule in `school.ts` is derived-read logic or a write-time check — both
  map cleanly to views/triggers/RPC.
- Matches the SP Manager operational pattern (Supabase + RLS + security_invoker views +
  Netlify), so one mental model for both school apps.
- The Express `summary()` did N+1 queries per student; a SQL view fixes that.

The Express code is the **reference implementation**. `openapi.yaml` + spec.md define
the contract the SQL must satisfy.

Rejected alternative: keep Express + Drizzle with Supabase as a plain Postgres host.
Only worth revisiting if server-side logic outgrows SQL (real Excel parsing, jobs
beyond pg_cron).

## Stack

- **Frontend**: React + Vite, deployed to Netlify. Bundled — school networks block CDNs.
- **Auth**: Supabase Auth, email/password. Login ID maps to `{id}@scale.dics.kr`.
  `admins` is keyed by `auth.users.id` with role `SEONDO | SASAENG`.
  Session lives in `sessionStorage` (shared lab PCs).
- **DB**: Supabase project separate from `dics-sp`. SQL migrations in
  `supabase/migrations/` from day one.
- **Client data layer**: `src/lib/api.ts` over supabase-js. Reads from views, writes
  to tables/RPCs. Publishable key only — never `service_role`.

## Schema

Tables (soft-delete via `deleted_at` where history matters):

| Table | Notes vs Replit version |
|---|---|
| `admins` | `user_id` uuid FK → `auth.users`; role enum SEONDO/SASAENG |
| `students` | name, grade (1–6), deleted_at. Spec §4: no extra PII columns |
| `point_items` | name, type POSITIVE/NEGATIVE, fixed_points, is_fixed, is_active |
| `point_records` | FK `student_id`; `item` is a text snapshot; `entered_by_name` is typed by the admin (spec §6) |
| `reflection_records` | unique FK `point_record_id`; deadline = record date |
| `punishments` | FK; `violated_at` null = not violated |

No `weekly_summary` table — weekly aggregates come from `point_records`.

## Business rules → Postgres

All timestamps in **Asia/Seoul**. Weeks are **Mon 00:00–Sun 23:59:59**.

| Rule (spec §) | Construct |
|---|---|
| Reflection auto-created on NEGATIVE record, deadline = same day (§10) | trigger on `point_records` insert |
| SUBMITTED / MISSING / DOUBLE (§10) | computed in `v_reflections` — never stored |
| 체력훈련 대상: week ≥3 벌점 records OR ≥8 벌점 (§11A) | `v_student_summary` |
| 징계위원회 대상: month ≥20 벌점 (§11B) | `v_student_summary` |
| 처분 선택 필요: week ≥5 벌점, no active punishment (§14) | `v_student_summary` |
| 귀가금지 조건 충족: 3 consecutive weeks each ≥5 벌점 (§16) | `v_weekly_penalties` + window check |
| Punishment: week ≥5 → 1 type, ≥10 → 2; only 운동금지/간식금지/면회금지 (§14–15, 18) | `create_punishment` RPC |
| Violation → 귀가금지 (§17) | `set_punishment_violation` stamps `violated_at` |
| 선생님 재량 벌점: 1–5 only, never fixed (§8) | triggers |
| 상점/벌점 never netted (§34) | separate `positive_points` / `negative_points` |

Views: `v_student_summary`, `v_reflections`, `v_point_records`, `v_punishments`,
`v_weekly_penalties`, `v_dashboard_counts`. All `security_invoker = true`.
Helpers live in **`private`** so they never surface as `/rest/v1/rpc`.

## Authorization (RLS)

- No anon access. `authenticated` must have an `admins` row.
- SEONDO writes: `students`, `point_items`, `point_records`, `reflection_records`.
- SASAENG writes: `punishments`.
- Both roles read everything.
- No DELETE policies — history cannot be hard-deleted from the client (spec §21).

## Data protection

These are minors. **No student PII in git.** Schema stores name + grade only.
Rosters, score sheets, and real credentials stay in `_local/` (gitignored).

## Repo layout

```
README.md
package.json / vite.config.ts / netlify.toml
src/                    # Vite app
  lib/supabase.ts       # publishable key, sessionStorage
  lib/api.ts            # views + RPCs
  lib/auth.tsx          # ID/password → {id}@scale.dics.kr
  App.tsx               # all screens
supabase/
  migrations/           # schema, logic, RLS
  seed.dev.sql          # fictional students/items only
docs/
  LEGACY_INITIAL_BUILD.md # frozen initial build history (Lovable/Replit/Cursor)
  EVOLUTION_LOG.md        # active change/evolution log from 2026-09-21 onward
  architecture.md         # this file
  spec.md                 # original 35-section spec
_replit/                # gitignored: school.ts + drizzle schema only
_local/                 # gitignored rosters / xlsx
```

## Known gaps (don't copy the Replit dump blindly)

- Express used UTC week/month windows — this port uses Asia/Seoul.
- 귀가금지 조건 충족 and 처분 선택 필요 were missing in Express; they exist here.
- Audit log (spec §31) is not in v1.
- Real student roster import from Excel is not wired yet — CSV import exists for
  `point_items` only.
