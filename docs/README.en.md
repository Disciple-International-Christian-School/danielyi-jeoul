# Daniel's Scale — Documentation Guide

**Language / 언어:** [English](README.en.md) | [한국어](README.md)

[Main README](../README.en.md) · [Key issues and decisions](KEY_ISSUES.en.md) · [한국어 핵심 이슈](KEY_ISSUES.md)

This index groups the existing `docs/` references by purpose. **The main README, the documentation index, and the key-issues summary** are available in English and Korean; linked deep technical documents retain their original languages. This is not a claim that every existing document has been translated.

## Start with the key issues

[Key issues and next checks](KEY_ISSUES.en.md) summarizes student-number policy, DICS Core integration, legacy compatibility, administrator identity rollout, and migration governance. Its statuses reflect the cited documentation at the time of writing, not a live database audit.

## 1. Operations and usage

| Document | Purpose |
| --- | --- |
| [Operations roadmap](OPERATIONS_ROADMAP.md) | Terms, settlement, reflections, weekly reports, planned work |
| [Personal admin accounts](ADMIN_ACCOUNT_OPERATIONS.md) | Provisioning, password change, shared-account retirement gates |
| [Original business specification](spec.md) | Original 35-section requirements |
| [Deployment guide](netlify-deployment.md) | Netlify and GitHub Actions setup |
| [UI design system](UI_DESIGN_SYSTEM.md) | Dashboard design decisions |

## 2. DICS Core and data migration

| Document | Purpose |
| --- | --- |
| [Integrated architecture](DICS_CORE_ARCHITECTURE.md) | Canonical student UUID, term enrollment, domain schemas |
| [Core migration governance](CORE_MIGRATION_GOVERNANCE.md) | Central migration ledger and Git ↔ production consistency |
| [Discipline UUID cut-over](DISCIPLINE_CORE_CUTOVER.md) | Completed discipline FK migration and remaining compatibility layer |
| [Study Planner migration plan](STUDY_PLANNER_MIGRATION_PLAN.md) | Migration stages, validation gates and rollback planning |
| [Study Planner migration runbook](SP_CORE_MIGRATION_RUNBOOK.md) | Step-by-step production checks and stop conditions |
| [SP identity migration protocol](SP_IDENTITY_MIGRATION_PROTOCOL.md) | Verified identities; never guess student matches from names |

## 3. Engineering history and decisions

| Document | Purpose |
| --- | --- |
| [Architecture](architecture.md) | Earlier technical structure and historical caveats |
| [Decision log](DECISIONS.md) | Accepted, transitional, and open decisions |
| [Change log](CHANGELOG.md) | Implemented changes and latest recorded work |
| [Development journal](DEVELOPMENT_JOURNAL.md) | Rationale, incidents, and verification narratives |
| [Legacy initial build](LEGACY_INITIAL_BUILD.md) | Initial implementation and platform migration history |

**How to read statuses:** Prefer the later [change log](CHANGELOG.md) and [completed discipline cut-over record](DISCIPLINE_CORE_CUTOVER.md) over old unchecked roadmap items when assessing what has actually shipped.

## Student data protection

Do not include student names, student numbers, PINs, dates of birth, passwords, or verified identity-mapping rows in README files, issues, or pull requests. Keep documentation limited to design decisions and privacy-safe aggregate evidence.
