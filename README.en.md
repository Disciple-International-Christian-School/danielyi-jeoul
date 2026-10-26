# Daniel's Scale

**Language / 언어:** [English](README.en.md) | [한국어](README.md)

An administrator-only merit and demerit management console for DICS (Disciple International Christian School). It supports student discipline workflows for the **SEONDO** (student guidance) and **SASAENG** (residential life) administrator roles. Students do not sign in to this application.

**Application:** https://dics-daniels-scale.netlify.app

## Start here

- [Documentation index (English)](docs/README.en.md) · [문서 목차 (한국어)](docs/README.md)
- [Key issues and decisions (English)](docs/KEY_ISSUES.en.md) · [핵심 이슈 (한국어)](docs/KEY_ISSUES.md)
- [Operations roadmap](docs/OPERATIONS_ROADMAP.md) and [change log](docs/CHANGELOG.md)

The language links above provide English and Korean versions of this overview, the documentation index, and the key-issues summary. The underlying technical references remain in their original languages.

## Documentation

- [Connect free organization deployment with Netlify](docs/netlify-deployment.md)
- [Original build history — Legacy](docs/LEGACY_INITIAL_BUILD.md)
- [Current changes — Change Log](docs/CHANGELOG.md)
- [Operations roadmap](docs/OPERATIONS_ROADMAP.md)
- [Development journal](docs/DEVELOPMENT_JOURNAL.md)
- [Architecture decision log](docs/DECISIONS.md)
- [DICS Core integrated schema](docs/DICS_CORE_ARCHITECTURE.md)
- [Core migration governance](docs/CORE_MIGRATION_GOVERNANCE.md)
- [Study Planner → DICS Core migration runbook](docs/SP_CORE_MIGRATION_RUNBOOK.md)
- [Discipline Core UUID cut-over](docs/DISCIPLINE_CORE_CUTOVER.md)
- [Personal administrator account operations](docs/ADMIN_ACCOUNT_OPERATIONS.md)
- [Architecture reference](docs/architecture.md)
- [Original specification (35 sections)](docs/spec.md)

## Local development

~~~bash
cp .env.example .env   # Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY
npm install
npm run dev
~~~

The legacy shared login IDs are `seondo` (SEONDO) and `sasaeng` (SASAENG), mapped to `{login_id}@scale.dics.kr`. See the [personal account operations runbook](docs/ADMIN_ACCOUNT_OPERATIONS.md) for the staged move to individual administrator accounts.

## Stack and security

React + Vite + `supabase-js`. PostgreSQL views, triggers, and RPCs implement business rules; Row Level Security (RLS) enforces access permissions. Follow the [deployment instructions](docs/netlify-deployment.md) for GitHub Actions and Netlify CLI.

**Never embed a Supabase `service_role` key in browser code.** Keep real student rosters, student numbers, PINs, credentials, and verified identity mappings out of Git. The local roster directory `_local/` is ignored by Git; the `_replit/` legacy reference contains only `school.ts` and the Drizzle schema.
