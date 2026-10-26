# 다니엘의 저울 — 문서 안내

**언어 / Language:** [한국어](README.md) | [English](README.en.md)

[대표 README](../README.md) · [핵심 이슈 및 의사결정](KEY_ISSUES.md) · [영문 핵심 이슈](KEY_ISSUES.en.md)

이 페이지는 기존 `docs/` 문서를 목적별로 안내합니다. **대표 README, 문서 안내, 핵심 이슈**는 한국어·영어 버전을 제공합니다. 아래 링크의 상세 원본 문서는 원래 언어로 유지합니다. 이중언어 안내가 전체 기술문서 번역을 의미하지는 않습니다.

## 핵심 이슈 먼저 보기

[핵심 이슈 및 다음 확인사항](KEY_ISSUES.md)에서는 학생번호 정책, DICS Core 통합, 레거시 호환, 관리자 계정 전환, 마이그레이션 운영을 요약합니다. 상태 판단은 문서의 기록 시점에 따른 것이며 실시간 운영 DB 확인을 대체하지 않습니다.

## 1. 운영 및 사용

| 문서 | 내용 |
| --- | --- |
| [운영 개선 로드맵](OPERATIONS_ROADMAP.md) | 학기·정산·반성문·주간 보고 및 미완료 계획 |
| [관리자 개인계정 운영](ADMIN_ACCOUNT_OPERATIONS.md) | 개인 계정 발급, 비밀번호 변경, 공용 계정 종료 조건 |
| [원본 업무 스펙](spec.md) | 초기 업무 요구사항 35절 |
| [배포 연결](netlify-deployment.md) | Netlify 및 GitHub Actions 배포 방식 |
| [UI 디자인 시스템](UI_DESIGN_SYSTEM.md) | 대시보드 디자인 기준 |

## 2. DICS Core / 데이터 마이그레이션

| 문서 | 내용 |
| --- | --- |
| [통합 아키텍처](DICS_CORE_ARCHITECTURE.md) | 학생 UUID, 학기별 배정, 앱 도메인 구조 |
| [Core Migration Governance](CORE_MIGRATION_GOVERNANCE.md) | 중앙 migration ledger 및 Git ↔ 운영 DB 일치 규칙 |
| [Discipline UUID Cut-over](DISCIPLINE_CORE_CUTOVER.md) | 완료된 discipline FK 전환과 남아 있는 호환 계층 |
| [Study Planner 통합 계획](STUDY_PLANNER_MIGRATION_PLAN.md) | 단계별 데이터 이전과 검증 게이트 |
| [Study Planner Migration Runbook](SP_CORE_MIGRATION_RUNBOOK.md) | 실제 이관 시 점검·중단·롤백 조건 |
| [SP Identity Migration Protocol](SP_IDENTITY_MIGRATION_PROTOCOL.md) | 실명 추정 매칭 금지와 안전한 신원 연결 |

## 3. 개발 및 의사결정 기록

| 문서 | 내용 |
| --- | --- |
| [아키텍처](architecture.md) | 초기 설계·구조와 당시 제한사항 |
| [Decision Log](DECISIONS.md) | 수용·전환·미결정 의사결정 |
| [Change Log](CHANGELOG.md) | 진행된 실제 변경 이력과 최신 기록 |
| [Development Journal](DEVELOPMENT_JOURNAL.md) | 설계 변경의 근거와 검증 과정 |
| [Legacy Initial Build](LEGACY_INITIAL_BUILD.md) | 초기 구축과 이전 플랫폼 기록 |

**읽는 순서:** 현재 상태 판단에는 [Change Log](CHANGELOG.md) 및 [Discipline UUID Cut-over](DISCIPLINE_CORE_CUTOVER.md) 같은 후속 완료 기록을 우선하세요. 오래된 로드맵의 미체크 항목이 이미 완료되었을 수 있습니다.

## 데이터 보호

학생 실명, 학번, PIN, 생년월일, 비밀번호, 신원 연결표는 README·GitHub Issue·PR에 포함하지 않습니다. 이 문서들은 설계와 비식별 집계 수준의 정보를 다룹니다.
