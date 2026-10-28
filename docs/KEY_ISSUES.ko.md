# 핵심 이슈 및 후속 확인사항

**Language / 언어:** [English](KEY_ISSUES.md) | [한국어](KEY_ISSUES.ko.md)

[문서 목차](README.ko.md) · [대표 README](../README.ko.md)

> **기준:** 2026-10-26 문서 검토. 이 페이지는 Git에 기록된 의사결정·로드맵·변경 이력을 요약한 문서이며 운영 DB를 실시간 조회한 결과가 아닙니다. 아래의 '확인 필요'는 실서비스 장애를 뜻하지 않습니다.

## 현황 요약

| 항목 | 문서 기준 상태 | 다음 조치 |
| --- | --- | --- |
| 전교생 학생번호 정책 (D-013/D-014) | **OPEN** | 학년 독립적인 영구 번호와 기존 로그인 별칭 정책 결정 |
| Discipline의 Core UUID 전환 | **완료 기록 있음** | 완료 상태 유지 검증; 이전 단계로 되돌리지 않기 |
| `public.students` 호환 계층 | **TRANSITION** | 사용처·구형 링크·외부 도메인 의존성 점검 후 제거 여부 결정 |
| Study Planner → Core 전환 | **검증 상태 확인 필요** | 단계별 매핑·데이터 정합성·Auth·롤백 게이트 확인 |
| 관리자 개인계정 전환 | **운영 전개 상태 확인 필요** | 개인 로그인·권한·감사 로그 검증 후 공용계정 종료 |
| 통합 DB migration 소유권 | **중간 운영 체계 존재** | 중앙 ledger 유지, 최종 Core repo 소유권 결정 |
| 사진 기반 벌점 입력 | **로드맵상 계획** | 개인정보 처리·검토 절차 확정 후 구현 여부 결정 |

## 1. 전교생 학생번호 정책 — OPEN

기존 Study Planner의 `GGNN` 형식은 학년을 포함하기 때문에 진급 후에도 변하지 않아야 하는 학교 공통 식별번호로 쓰기 어렵습니다. `core.students.id` UUID는 이미 학생의 표준 식별자로 분리되어 있습니다.

**결정 필요:** 기존 번호를 그대로 보존할지, 로그인 별칭으로만 남길지, 학년과 무관한 새 영구 번호를 발급할지 정책을 확정합니다. 학교의 승인 없이 학생번호를 자동 생성하거나 이름만으로 계정을 연결하지 않습니다.

근거: [Decision Log — D-013/D-014](DECISIONS.ko.md), [SP identity migration protocol](SP_IDENTITY_MIGRATION_PROTOCOL.ko.md).

## 2. Discipline Core UUID와 Legacy 호환 — 완료 + 전환 상태를 분리

**이미 완료된 작업:** discipline 원본 레코드의 물리적 integer 학생 FK 제거 및 Core UUID 기반 전환. [Cut-over runbook](DISCIPLINE_CORE_CUTOVER.ko.md)에는 당시의 운영 검증 결과가 `cutover_completed=true`로 기록되어 있습니다. [2026-10-15 변경 이력](CHANGELOG.ko.md)에는 Core 명부를 legacy 화면 호환행과 실시간 동기화한 변경도 있습니다.

**남은 검토:** `public.students.id`는 구형 numeric URL과 일부 호환 RPC·도구를 위한 bridge로 남아 있습니다. 이것을 즉시 제거하면 안 됩니다. 구형 링크 처리, 프런트엔드 호출, 다른 앱의 의존성, 백업·CI 상태를 먼저 검증해야 합니다.

근거: [Discipline Core UUID Cut-over — Current compatibility boundary](DISCIPLINE_CORE_CUTOVER.ko.md), [Change Log](CHANGELOG.ko.md).

## 3. Study Planner 통합 — 단계별 검증

Study Planner는 별도 Auth namespace를 갖기 때문에 기존 SP Auth UUID를 Core 학생 UUID나 Core-local Auth UUID와 혼동해서는 안 됩니다. 데이터 복사 전에 검증된 신원 매핑과 원본·대상 집계, FK 정합성, Auth 재구성, 롤백 지점을 확인해야 합니다.

기존 계획서가 있다는 사실만으로 운영 이전이 아직 미완료이거나 이미 완료되었다고 단정하지 않습니다. 실제 시행 기록 및 담당자 확인 후 상태를 갱신합니다. 이름 유사도로 미확인 학생을 자동 연결하지 않습니다.

근거: [Migration plan](STUDY_PLANNER_MIGRATION_PLAN.ko.md), [Migration runbook](SP_CORE_MIGRATION_RUNBOOK.ko.md), [Identity protocol](SP_IDENTITY_MIGRATION_PROTOCOL.ko.md).

## 4. 개인 관리자 계정 및 감사 추적 — 운영 검증

개인 관리자 계정과 Audit 기반 구조는 구축 기록이 있습니다. 다만 [계정 운영 문서](ADMIN_ACCOUNT_OPERATIONS.ko.md)의 초기 작성 당시에는 실제 개인 계정 전개가 시작되지 않은 상태였습니다. 현재 실운영 발급 현황은 별도로 확인해야 합니다.

공용 `seondo`/`sasaeng` 계정은 무작정 삭제하지 않습니다. 실제 담당자 계정 생성 → 최초 비밀번호 변경 → 역할·담당범위·감사로그 테스트 → 모든 운영자 전환 → 공용 계정 비활성화 순서로 진행합니다. 자격증명은 PR에 남기지 않습니다.

근거: [Admin Account Operations](ADMIN_ACCOUNT_OPERATIONS.ko.md), [Change Log](CHANGELOG.ko.md).

## 5. 공유 DICS Core DB 마이그레이션 거버넌스

여러 앱과 작업자가 같은 Supabase DB 구조를 변경할 수 있으므로, Git 마이그레이션 파일과 실제 운영 이력 간 드리프트 방지가 핵심입니다. 변경 시 `supabase/migration-ledger.json`, 적용 버전, 검증 및 롤백 근거를 일치시킵니다.

[거버넌스 문서](CORE_MIGRATION_GOVERNANCE.ko.md)의 경로는 현재 조직 저장소 `Disciple-International-Christian-School/danielyi-jeoul`로 정리했습니다. 임시 중앙 원장 모델은 유지하며 실제 도메인 간 이관 책임은 운영 모델 변경 전에 Owner가 확인해야 합니다. 장기적인 별도 DICS-Core 저장소 계획도 미결정 운영 과제로 남습니다.

근거: [Core Migration Governance](CORE_MIGRATION_GOVERNANCE.ko.md), [Decision Log — D-016/D-022](DECISIONS.ko.md).

## 6. 로드맵상의 기능 과제 — 장애 아님

[운영 로드맵](OPERATIONS_ROADMAP.ko.md)은 **벌점 시트 사진 업로드와 검토 기반 추출**, 여러 DICS 앱의 **학생 통합 프로필** 등을 장기 과제로 제시합니다. 이들은 문서상 계획 항목이며 현재 서비스의 장애로 분류하지 않습니다. 사진 관련 기능을 설계할 때는 학생 개인정보 최소 수집, 접근 권한, 보관·삭제 정책을 함께 정의해야 합니다.

## 상태 갱신 원칙

- 새로운 이슈 상태는 실제 변경 이력·CI·운영 검증으로 확인한 뒤 바꿉니다.
- 오래된 체크박스가 최신 완료 기록과 충돌하면 최근 검증 기록을 우선합니다.
- 학생 정보, 학번, PIN, 비밀번호, 신원 매핑 행은 Git/Issue/PR에 올리지 않습니다.
- 이 페이지의 이슈는 **설명용 요약**이며 별도 GitHub Issue 등록이나 우선순위 승인을 의미하지 않습니다.
