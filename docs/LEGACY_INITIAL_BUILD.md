# Legacy Initial Build — Daniel's Scale

**Language / 언어:** [English](LEGACY_INITIAL_BUILD.md) | [한국어](LEGACY_INITIAL_BUILD.ko.md)

> Frozen historical record, September 21, 2026. This English edition translates/reflows the initial-build account. Later work belongs in [CHANGELOG.md](CHANGELOG.md). Historical repository ownership, schema, seed state, and deployment methods below are not current operational instructions; see [deployment](netlify-deployment.md) and [migration governance](CORE_MIGRATION_GOVERNANCE.md).

DICS administrator console for merits/demerits. Students do not sign in. Roles are SEONDO (student guidance) and SASAENG (residential life).

## Historical running environment

App: https://dics-daniels-scale.netlify.app. The original working repository was shualoalumin/danielyi-jeoul on main, described as public at that time. Supabase was the DICS organization's daniels-scale project in Seoul, ref jgrzsfomcwfiukkaqtos. Login IDs seondo/sasaeng mapped to {id}@scale.dics.kr. Local setup copied .env.example to .env, installed npm dependencies, and started Vite. VITE_SUPABASE_* values were injected at build time, so changing them required redeployment.

## Timeline

### 1. Lovable mockup

The initial UI reference was https://pixel-perfect-match-0249.lovable.app/dashboard, including students/reflections/punishments/penalty-items screens. Code could not be extracted; it served only as a visual reference.

### 2. Replit rebuild and limit

A full-stack rebuild produced Drizzle schema, Express API, OpenAPI/orval client, eight React screens, and Clerk authentication. Platform limits stopped work. After porting, only school.ts and Drizzle schema remained in ignored _replit; the original 35-section prompt became [spec.md](spec.md).

### 3. September 18 architecture decision

Do not host Express. Authentication needed replacement anyway; derived reads and write-time validation fit PostgreSQL views/triggers/RPCs. Reuse SP Manager's Supabase/RLS/Netlify operating pattern. The rejected alternative kept Express/Drizzle while using Supabase only as a PostgreSQL host.

### 4. Repository cleanup and frontend port

The intended hylen707/daniels-scale destination was inaccessible to the machine's shualoalumin Git identity, so commits initially stayed local. Clerk became Supabase Auth with ID/password and sessionStorage; orval became src/lib/api.ts; schema/logic/RLS migrations and fictional seeds were prepared. NextSnap's free slots were full, preventing project creation there.

### 5. September 21 recovery

Re-extracting a ZIP lost three unpushed local commits. File contents were recovered from earlier session records. An empty shualoalumin/danielyi-jeoul repository became the working origin and accepted pushes.

### 6. GitHub and Netlify

The dics-daniels-scale site used an SPA rewrite to index.html and a GitHub deploy key for main. Without Supabase variables, the first deployment displayed a missing-configuration message.

### 7. Supabase in the DICS organization

The placement-test development project was paused to release a free slot. daniels-scale was created in ap-northeast-2, migrations and fictional seed applied, and VITE_SUPABASE_URL/ANON_KEY configured before redeployment. Two Auth users were linked to admins by role. Email confirmation was disabled for that initial login setup. This records what happened; it is not a recommendation to reset production or reuse shared credentials.

## Repository layout and ownership

src, supabase, and docs were tracked. _replit retained only source references; _local held private rosters/spreadsheets; .env held local configuration. Clerk/orval/nested Git/node_modules were removed from the imported dump. At that time hylen707/daniels-scale was empty and shualoalumin/danielyi-jeoul was the source. Current ownership is the school organization repository.

## Historical remote additions

The initial three migrations were supplemented with fictional seed, email-based admin bindings without hardcoded Auth UUIDs, and fixed function search_path/RPC grants. Later ledger reconciliation renamed draft migrations to live versions. The original reset recipe assumed a development environment; do not apply it to production data.

## Unfinished at that checkpoint

Real-roster import, fixed point values for the first three items, audit logging, custom domain, and optional mirroring were not complete on September 21. Later records supersede those gaps. The fictional seed had four students; that was not the later operational roster.
