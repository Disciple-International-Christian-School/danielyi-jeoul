# Agent instructions — Daniel's Scale

**Language / 언어:** [English](AGENTS.md) | [한국어](AGENTS.ko.md)

Merit, demerit and discipline workflow for DICS. Start with `README.md`, `docs/DECISIONS.md` and `docs/IMPLEMENTATION_TODO.md`. Documentation in this repository is bilingual and checked by `npm run check:docs`; follow `docs/DOCUMENTATION_POLICY.md`, including English-only commit messages.

## DICS organization contract

This repository is one component of the DICS Student 360° Growth OS. The full and current
text lives in the `dics-core` repository under `docs/architecture/`:
[organization architecture](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/ORG_ARCHITECTURE.md),
[CORE contract](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/CORE_CONTRACT.md),
[integration registry](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/INTEGRATION_REGISTRY.md),
[migration ledger](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/MIGRATION_LEDGER.md),
[roadmap and open-work ledger](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/STUDENT_360_ROADMAP.md) and
[agent coordination](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/AGENT_COORDINATION.md).
Read them at the start of a session. If `dics-core` is not available to the session and the
task touches identity, authentication, the roster or the shared database, get access to it
before starting. The rules below are the summary that always applies, for every agent.

1. One student has one `core.students.id` (UUID) in the shared CORE Supabase project
   `jgrzsfomcwfiukkaqtos`. Never create a student master, a PIN table or an app-specific
   student ID.
2. Students sign in through that project's shared Auth with their student number and
   6-digit PIN. Resolve `auth.uid()` to the CORE UUID on the server. Never accept a student
   UUID, number or name from the client as proof of ownership.
3. Student-owned records reference the CORE UUID. Names and student numbers are display
   values, not keys. A stored copy of a name, number or grade is a dated snapshot, not a roster.
4. CORE owns identity, roster, enrollment, grade and class. This application owns only its
   domain data and does not write CORE roster tables.
5. The database is shared production with no staging copy. Before a schema change, check the
   live migration list and the migration ledger. Keep the migration in the repository that
   owns the schema, name the file with the version recorded live, rehearse it in a
   transaction that rolls back, and never edit an applied migration. A change to `core.*`
   or to another application's schema goes through `dics-core`.
6. Row-level security on every table, least privilege, and no service-role key in a browser.
   A shared identity does not mean shared access.
7. Never commit or post student names, PINs, roster data or credentials. Changing student
   records, accounts, credentials or permissions needs Josh's approval for that action.
8. Order of truth: the live system, then `dics-core/docs/architecture/`, then this
   repository's handoff documents, then agent memory. Verify before claiming. When you
   finish, update this repository's handoff and, if the integration status changed, the
   registry row in `dics-core`.
9. Explain to Josh in Korean. Write commits, pull request titles and documents in English.

### Registry status on 2026-11-15 KST

VERIFIED INTEGRATED. Discipline records reference the CORE UUID and none lack it. This
repository is public: write nothing here that should not be public. It holds 72 of the 99
migrations applied to the shared database because the project began here; the complete list
is the migration ledger in `dics-core`. Open organization items that concern this
repository: ORG-11 (CORE staff read policies depend on this application's role helper),
ORG-13 (the interim ledger here covers only this repository's migrations), ORG-15 (definer
RPCs in `public`).
