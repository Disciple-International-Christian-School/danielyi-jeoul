# Daniel's Scale — Project Case Study

**Language / 언어:** [English](PROJECT_CASE_STUDY.md) | [한국어](PROJECT_CASE_STUDY.ko.md)

## Problem and purpose

DICS needed a practical way to turn paper discipline sheets into timely student-guidance work: record merit and demerit points, track reflection submissions, prepare class notices, and identify weekly or settlement-period follow-up. Daniel's Scale is an internal administrator application serving that workflow. Students do not sign in to it.

The engineering problem expanded when several school applications represented the same student differently. Daniel's Scale used integer student IDs; Study Planner used authentication UUIDs. A shared student identity became necessary before those applications could exchange records reliably.

## Design decisions and tradeoffs

| Decision | Reason | Cost or limitation |
| --- | --- | --- |
| Separate `core.students.id` from login identity | Students can exist without accounts; authentication changes should not replace student identity | Requires explicit identity bridges and verified migration |
| Keep academic placement in term enrollments | Preserve promotion and class-change history | Queries must resolve the current term |
| Enforce rules through PostgreSQL views, RPCs, triggers, and RLS | Keep authorization and score rules consistent across clients | SQL migrations need runtime checks as well as frontend CI |
| Migrate through dual keys, shadow calculations, and parity checks | Preserve operational records and compatibility during the UUID transition | Temporary compatibility code must be tracked and retired |
| Separate structural migrations from private operational data | Rebuild schema from Git without committing student rosters or identity mappings | Recovery also requires separately governed operational data |
| Require individual administrator accounts and authenticated audit actors | Attribute new actions to an operator rather than a typed name | Full accountability depends on completing the staff rollout |

Decision details and alternatives are recorded in the [decision log](DECISIONS.md).

## Evidence recorded in the repository

These are dated historical observations from checked-in records, not a new production audit or a claim about today's enrollment.

| Milestone | Recorded evidence | Interpretation |
| --- | --- | --- |
| Core bootstrap, September 2026 | 180 legacy student rows mapped; 175 active, 5 inactive | Preserved identities with historical records, including inactive students |
| Pilot reconciliation | 29 source students; 28 exact matches, 1 pending, 0 ambiguous | A disputed identity stayed pending rather than being guessed |
| Term setup | 13 classes; 144 enrollments; 31 G9 placements pending at that checkpoint | Automation stopped where verified section assignments were unavailable |
| Discipline UUID cut-over | Student summary 175/175, mismatch 0; weekly 1/1, mismatch 0 | Parity held for the measured dataset; this is not a high-volume benchmark |
| Post-cut-over checks | Point record 1, point sum 5, reflection 1, punishments 0, weekly report rows 175 | Recorded state was preserved; rollback probes covered Core and legacy entry points |
| Migration governance | Historical checkpoint: 55 live migrations, 51 tracked structural migrations, 4 data-only entries | Versioned structure and sensitive operational changes were treated separately |
| Dashboard verification | Synthetic fixtures at desktop, 390px, 320px, and dark mode | UI verification; authenticated production workflows were outside that check |
| Core roster synchronization, October 15, 2026 | Recorded trigger-based synchronization and one missing active-student bridge backfill | Core remains the student authority; the legacy roster is a compatibility bridge |

See the [development journal](DEVELOPMENT_JOURNAL.md), [cut-over record](DISCIPLINE_CORE_CUTOVER.md), [change log](CHANGELOG.md), and [UI verification record](UI_DESIGN_SYSTEM.md).

## Contribution and tool attribution

The records describe work across Lovable, Replit, Cursor, Claude Code, and GPT-assisted workflows, together with human operational decisions. This repository should be presented as an AI-assisted engineering project. Do not attribute every repository change to a single student.

For an extracurricular submission, identify the applicant's own work with specific commits or pull requests and a short explanation of the requirement, decision, implementation, and verification they personally handled. The repository alone does not establish individual authorship or leadership. School staff should confirm deployment status and operational responsibility before those claims appear in an application.

## Open work and limitations

School-wide student numbering policy, Study Planner migration completion, individual administrator adoption, and retirement of legacy compatibility require current owner verification. Photo-assisted intake and a unified student profile remain planned work in the cited records. No time-saved estimate, adoption rate, learning-outcome improvement, or independent security certification is claimed here.

Use synthetic examples and aggregate evidence in submission materials. A historical account handout contained student identifiers and PINs; its replacement is a blank, bilingual template. That replacement does not erase old Git objects or establish that credentials have been rotated. The owner must review historical exposure and credential validity before sharing repository access.
