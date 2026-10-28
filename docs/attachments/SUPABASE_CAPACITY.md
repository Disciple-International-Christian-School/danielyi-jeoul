# Shared Supabase Capacity — Historical Discussion

**Language / 언어:** [English](SUPABASE_CAPACITY.md) | [한국어](SUPABASE_CAPACITY.ko.md)

> English reading edition of the 20 screenshot fragments in the legacy HTML attachment. The fragments begin and end mid-discussion; they are not a complete source transcript. This records an earlier planning discussion, not verified current pricing, quotas, or an approved production plan. The original Korean HTML/PDF are retained as source archives.

## Main question

Would one Supabase project, separated by schemas/tables, avoid the need for a paid plan solely to obtain more projects? The discussion answered yes: multiple school apps can share one database project. App count and database-project count are different constraints.

## Proposed layout

A shared DICS Core would hold canonical students, accounts/authentication, and enrollment, while schemas separate Study Planner, discipline, computer-lab, placement, SAT/TOEFL, and future portal/dashboard records. A second development project could host disposable prototypes, migration trials, and schema experiments without real student data. Separate free organizations/projects were discussed for experimental MVPs and personal learning.

The draft examples included public.students/classes/enrollments; discipline incidents/rewards/weekly/monthly summaries; study_planner tasks/progress/assignments; computer_lab checkins/sessions/device_logs; and testing English/math placement and speaking results. These names were conceptual sketches, not the current migration contract. In particular, an early student_auth_pins/profile-PIN sketch is superseded: current architecture keeps credentials in Auth, never plaintext student-profile PIN columns.

## Why consider a paid operational environment?

The discussion emphasized inactivity pausing, backup/recovery, compute capacity, usage headroom, and reliability rather than the number of apps. School holidays can reduce activity, making a paused database at term restart an operational inconvenience. Each separate project has its own resources, so multiplying projects can also multiply operational and compute costs.

It suggested a single free project could be adequate for an MVP/internal test and that a real daily-use school service should evaluate a paid plan for continuity and recovery. That suggestion was not a recorded purchase or capacity test.

## Historical numeric claims in the screenshots

| Topic | Claim in the old discussion |
| --- | --- |
| Free active projects | Two |
| Inactivity | Possible pausing after seven days of low activity |
| Database | 500 MB |
| Monthly active users | 50,000 |
| Storage | 1 GB |
| Egress | 5 GB uncached plus 5 GB cached |
| Edge Function invocations | 500,000 |
| Realtime messages | 2 million |
| Free maximum file size | 50 MB |

These figures are preserved for translation fidelity only. Recheck official plan/account conditions before a purchasing or deployment decision. The source's claim that tens of thousands of discipline/lab rows and hundreds of thousands of planner tasks would likely fit was an estimate, not a measurement; indexes, retention, query patterns, and record size still matter.

## Binary files and recovery

Text/numbers/timestamps are usually smaller than screenshots, PDFs, and audio. Retained speaking recordings could dominate storage and transfer. Separate object storage or a separate media workload was suggested rather than placing all binary content in Core. The source also stressed that managed backup access differs by plan and that school identity, learning, and assessment records need a recovery strategy. Its last screenshot ends during that discussion; no missing conclusion has been invented here.

## Source and current authority

- [Original Korean screenshot HTML](../archive/supabase-capacity-source.ko.html)
- [Original Korean PDF](../archive/supabase-capacity-source.ko.pdf)
- [Bilingual reading PDF](supabase-capacity.pdf)
- [Current repository architecture](../DICS_CORE_ARCHITECTURE.md)
- [Migration and recovery governance](../CORE_MIGRATION_GOVERNANCE.md)

[Supabase pricing](https://supabase.com/pricing) and the [production checklist](https://supabase.com/docs/guides/deployment/going-into-prod) are verification starting points; this translation does not assert their present contents.
