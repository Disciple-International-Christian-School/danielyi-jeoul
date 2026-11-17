# November 2026 Seondo transition — historical training review

## Fixed policy
- Monday 2026-11-16 is the **new physical-training calculation start**.
- The previously issued reflection obligations **retain their existing pages, status, and deadlines**; no retrospective reflection reissue.
- In November, count the approved old-policy qualifying weeks ending November 1, 8, 15 **plus** new-policy weeks ending November 22, 29. Count a student at most once per week. Refer G7–G12 after **at least three total occurrences**, consecutive or not.
- In December, count only weeks whose Sundays fall in December, under the new two-trigger policy. G1–G6 remain eligible for physical training but not committee referral.
- Through December 23, school days exclude only Saturdays/Sundays. Public holidays and discretionary closures are absent this term.

## Source limitations
The operational database had **no historical weekly physical-training closure records**. The backfill therefore contains **derived review candidates**, not confirmed historical execution/assignment records.

New staging table: `discipline.seondo_legacy_weekly_candidates`.
Candidates captured on 2026-11-17 from source records with effective entry before Nov 16:

| Closing Sunday | Week start | Candidates | G1–G6 | G7–G12 |
|---|---|---:|---:|---:|
| Nov 1 | Oct 26 | 25 | 7 | 18 |
| Nov 8 | Nov 2 | 36 | 9 | 27 |
| Nov 15 | Nov 9 | 59 | 5 | 54 |
| **Total student-weeks** | | **120** | **21** | **99** |

These are student-week occurrences, not 120 distinct students.

The staging selection uses old criteria (weekly NET ≤ -8, three negative occurrences, or overdue doubled reflections). It respects historical effective entry boundary and current roster/eligible-reflection views. It may not match notices physically posted at the time, especially if deadlines or records were modified later.

## Required review before November monthly closure
1. Compare the staged rows against **the actual historic training notices/teacher records**. Check withdrawn/transferred students and late-submitted reflections.
2. Correct or exclude discrepancies; the staging table is not an approved count.
3. After the school explicitly signs off, copy approved rows into `discipline.seondo_weekly_training` using their preserved historical week starts.
4. In the same audited operation insert a 2026-11-01 approval row into `discipline.seondo_legacy_review` with the authentic school staff actor ID.
5. Only then may the November committee closure run. **Do not automatically approve all candidates.**

## Safety behavior
- The November monthly job is **blocked** until a recorded approval exists.
- The November 16 and November 23 new weekly records can finalize on their Sundays regardless of this block.
- December monthly closure is independent of November approval.
- Neither the candidate staging nor the new calculation edits actual point records, reflection records, or existing punishments.
- There is no external email/chat delivery; teacher-portal access uses explicitly authorized recipients.

## Verification
Executed a transaction-rollback simulation on the operational database on Nov 17:
- Nov 22 and 29 weekly close periods were created in the transaction.
- The unapproved November monthly closure stayed empty.
- December's month-end closure succeeded independently.
- Elementary committee entries remained absent.
- The transaction was rolled back.

**Do not mistake the candidate backfill or the simulated closures for real November settlements.**
