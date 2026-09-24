# 다니엘의 저울 — Change Log

> **ACTIVE DOCUMENT — 2026-09-21 이후 계속 갱신**
>
> 이 문서는 `docs/spec.md`의 원래 요구사항을 대체하지 않는다.
> 초기 구축 이전의 상세 과정은 [LEGACY_INITIAL_BUILD.md](./LEGACY_INITIAL_BUILD.md)에 동결 보존한다.
>
> 2026-09-21 이후 발생하는 모든 의미 있는 변경은 작업 도구와 관계없이 이 문서에 기록한다.
> GPT에서 수정했든, Cursor에서 수정했든, 수동으로 Supabase/Netlify를 변경했든 **실제 제품의 변경 과정은 이 파일이 단일 기준점**이다.

---

## 0. 문서 목적

다니엘의 저울은 선도부와 사생회가 학생의 상점·벌점·반성문·처분을 관리하는 내부 운영 시스템이다.

프로토타입 단계에서는 빠르게 기능을 구현하는 것이 중요했지만, 실제 학교 운영에 들어가면 다음 질문에 답할 수 있어야 한다.

- 누가 이 기록을 입력했는가?
- 누가 점수를 수정했는가?
- 언제 수정되었는가?
- 어떤 권한으로 수정했는가?
- 잘못된 기록을 수정하거나 비활성화했을 때 이전 상태를 추적할 수 있는가?

따라서 버전이 올라갈수록 단순한 기능 추가뿐 아니라 **권한, 기록 책임성, 추적 가능성(auditability)** 을 강화한다.

---

# 1. Development History

## Phase 0 — Replit Draft

**상태:** 초기 Draft

초기 목표는 실제 선도부/사생회 업무 흐름을 빠르게 화면과 로직으로 검증하는 것이었다.

주요 목적:

- 학생 목록 관리
- 상점/벌점 등록
- 반성문 관리
- 처분 관리
- 선도부 / 사생회 역할 구분
- 실제 사용 가능한 UX 검증

이 단계에서는 빠른 프로토타이핑이 가장 중요했다.

---

## Phase 1 — Cursor Prototype + Supabase Native Architecture

**상태:** 구현 완료

Replit draft를 기반으로 Cursor에서 실제 배포 가능한 구조로 이전했다.

현재 주요 기술 구조:

```text
Frontend
React 19 + Vite
        ↓
supabase-js
        ↓
Supabase Auth
Supabase PostgreSQL
Views / RPCs / Triggers / RLS
        ↓
Netlify Deployment
```

주요 개선:

- Clerk 제거
- 별도 REST API 계층 제거
- Supabase Auth 사용
- PostgreSQL에 학교 업무 규칙 직접 구현
- RLS(Row Level Security) 적용
- soft delete 기반 기록 보존
- KST 기준 주간/월간 통계
- Netlify SPA routing 지원

현재 배포:

- Frontend: Netlify
- Backend / Auth / Database: Supabase

---

# 2. 현재 관리자 권한 구조

현재 시스템에는 두 역할이 있다.

```text
SEONDO
└─ 선도부

SASAENG
└─ 사생회
```

권한 자체는 명확하다.

예:

```text
SEONDO
→ 학생 / 벌점 / 상점 / 반성문 관련 관리

SASAENG
→ 학생 처분 관련 관리
```

이 역할 구분은 앞으로도 유지할 수 있다.

문제는 **"역할"과 "개인"을 얼마나 정확히 식별하느냐**이다.

---

# 3. 현재 구조를 쉽게 설명하면

현재 구조는 사람보다 **부서 역할 중심**에 가깝다.

예를 들어 선도부 구성원이 여러 명이어도 시스템 입장에서는 다음처럼 보일 수 있다.

```text
선도부 계정
ID: seondo
        ↓
SEONDO 권한
```

사생회도 비슷하다.

```text
사생회 계정
ID: sasaeng
        ↓
SASAENG 권한
```

따라서 시스템은

> "선도부 권한을 가진 사용자가 벌점을 입력했다."

라는 사실은 알 수 있지만,

> "선도부의 Daniel Yi가 벌점을 입력했다."

라는 개인 단위 책임성을 강하게 보장하기 어렵다.

---

# 4. `entered_by_name` 방식의 한계

현재 기록에는 `entered_by_name`과 같은 문자열 필드가 사용된다.

예:

```text
entered_by_name = "Daniel"
```

이 값은 **인증된 사용자 ID가 아니라 문자열**이다.

즉 이론상 사용자가 다음처럼 입력할 수도 있다.

```text
Daniel
daniel
Daniel Yi
Josh
선도부
```

DB 입장에서는 이 문자열이 실제 로그인 사용자와 동일한 사람인지 자동으로 검증하기 어렵다.

즉,

```text
entered_by_name
≠
인증된 사용자 신원
```

이다.

---

# 5. P1 개선안 — Individual Admin Identity

## 핵심 아이디어

**역할(Role)과 사람(Identity)을 분리한다.**

현재 개념:

```text
사람 ≈ 역할

SEONDO 계정
SASAENG 계정
```

개선 구조:

```text
개인 관리자 계정
      ↓
관리자 프로필
      ↓
역할
      ↓
SEONDO / SASAENG
```

예:

```text
Daniel Yi
user_id: abc123
role: SEONDO

John Kim
user_id: def456
role: SEONDO

Peter Lee
user_id: ghi789
role: SASAENG
```

Daniel과 John은 서로 다른 사람이지만 동일한 `SEONDO` 권한을 가진다.

```text
Daniel Yi ─┐
           ├─ SEONDO → 선도부 기능 사용
John Kim ──┘

Peter Lee ─── SASAENG → 사생회 기능 사용
```

---

# 6. 기록 입력 방식도 바뀐다

현재:

```text
entered_by_name = "Daniel"
```

개선 후:

```text
created_by = auth.uid()
```

예:

```text
record_id: 381
student_id: 105
item: 지각
points: 1

created_by: abc123
created_at: 2026-09-21 20:32
```

그리고 관리자 테이블에서:

```text
abc123
→ Daniel Yi
→ SEONDO
```

로 연결한다.

사용자는 자신의 이름을 매번 입력할 필요가 없다.

**로그인한 계정 자체가 기록 작성자를 증명한다.**

---

# 7. Audit Trail이란?

Audit Trail은 쉽게 말하면 **관리자 활동 블랙박스**다.

최종 결과만 저장하는 것이 아니라 중요한 변경 과정을 남긴다.

예:

```text
20:31 Daniel Yi
학생 A에게 벌점 3점 등록

20:34 Daniel Yi
벌점 3점 → 1점 수정

수정 사유:
"입력 오류"
```

또는:

```text
21:02 John Kim
해당 기록 비활성화
```

이렇게 하면 나중에 다음 질문에 답할 수 있다.

- 누가 기록했는가?
- 누가 수정했는가?
- 언제 수정했는가?
- 무엇이 바뀌었는가?
- 왜 수정했는가?

---

# 8. 왜 학교 벌점 시스템에서 중요한가?

벌점/처분 기록은 일반 메모보다 책임성이 높다.

운영 중 실제로 다음과 같은 상황이 생길 수 있다.

> "이 벌점 누가 입력했나요?"

> "원래 2점이었는데 왜 4점으로 바뀌었나요?"

> "이 기록이 왜 없어졌나요?"

> "선도부가 수정했나요, 사생회가 수정했나요?"

개인 계정 + audit trail 구조가 있으면 시스템 기록으로 확인할 수 있다.

---

# 9. 권한 체계가 복잡해지는 것은 아니다

중요한 점은 역할을 많이 만드는 것이 아니다.

기존 두 역할은 그대로 유지한다.

```text
SEONDO
SASAENG
```

달라지는 것은 **각 역할 안에 실제 사용자를 식별하는 것**이다.

예:

```text
Admins

Daniel Yi   → SEONDO
John Kim    → SEONDO
Peter Lee   → SASAENG
Sarah Choi  → SASAENG
```

따라서 구조는 오히려 명확해진다.

```text
사람
 ↓
개인 로그인 계정
 ↓
역할
 ↓
허용 기능
```

---

# 10. UI에서 보이는 변화

현재처럼 단순히

```text
선도부
```

라고 표시하는 대신:

```text
Daniel Yi · 선도부
```

처럼 표시할 수 있다.

기록에도 자동으로:

```text
등록자 Daniel Yi
2026-09-21 20:32
```

를 표시할 수 있다.

사용자가 직접 등록자 이름을 입력하는 UI는 제거할 수 있다.

---

# 11. 권장 DB 방향

향후 예시:

## admins

```text
user_id        uuid  → auth.users.id
display_name   text
role           SEONDO | SASAENG
is_active      boolean
created_at     timestamptz
```

## point_records

기존 문자열 작성자 필드 대신:

```text
created_by     uuid
created_at     timestamptz
updated_by     uuid
updated_at     timestamptz
```

필요하면 기존 `entered_by_name`은 migration 기간 동안 legacy/display 목적으로 유지할 수 있다.

---

# 12. Audit Log 권장 구조

향후 별도 테이블을 둘 수 있다.

## audit_logs

예시:

```text
id
actor_user_id
action
entity_type
entity_id
before_data
after_data
reason
created_at
```

예:

```text
actor_user_id: abc123
action: UPDATE
entity_type: point_record
entity_id: 381

before:
points = 3

after:
points = 1

reason:
"입력 오류"
```

---

# 13. 단계별 적용안

## P1-A — 개인 관리자 계정

목표:

- 관리자마다 Supabase Auth 계정 생성
- `admins.user_id`와 연결
- `display_name` 저장
- `role`은 기존 SEONDO / SASAENG 유지

완료 기준:

> 로그인한 사용자가 누구인지 DB에서 개인 단위로 식별 가능하다.

---

## P1-B — 기록 작성자 자동 저장

목표:

- `entered_by_name` 수동 입력 제거
- 상점/벌점 등록 시 `auth.uid()` 자동 기록
- UI에 관리자 이름 자동 표시

완료 기준:

> 모든 신규 기록의 작성자를 인증된 계정으로 추적할 수 있다.

---

## P1-C — 수정자 추적

목표:

- `updated_by`
- `updated_at`

추가.

완료 기준:

> 누가 마지막으로 기록을 수정했는지 확인 가능하다.

---

## P1-D — Audit Trail

목표:

중요 변경에 대해:

- CREATE
- UPDATE
- SOFT DELETE
- 반성문 상태 변경
- 처분 등록/변경

등의 활동 기록을 남긴다.

완료 기준:

> 주요 학생 생활기록 변경의 이전 상태와 이후 상태를 관리자 로그에서 확인할 수 있다.

---

# 14. Version Roadmap

이 문서에서는 실제 Git tag와 별개로 다음 개선 단계를 관리한다.

| 단계 | 상태 | 핵심 변화 |
|---|---|---|
| Phase 0 | 완료 | Replit 기반 초기 draft |
| Phase 1 | 완료 | Vite + Supabase + Netlify 프로토타입 |
| P1-A | 예정 | 관리자 개인 계정 식별 |
| P1-B | 예정 | auth.uid 기반 기록 작성자 자동 저장 |
| P1-C | 예정 | 수정자 / 수정시간 추적 |
| P1-D | 예정 | Audit Trail 구축 |
| P2 | 추후 | 운영 데이터/UX 고도화 및 세부 권한 확장 |

---

# 15. 설계 원칙

향후 개선에서도 다음 원칙을 유지한다.

### 1. DB가 권한의 최종 기준이다

버튼을 숨기는 것만으로 권한을 통제하지 않는다.

RLS / RPC / DB constraint가 실제 권한을 강제한다.

### 2. 학교 업무 규칙은 가능한 한 서버/DB에서 검증한다

벌점 기준, 처분 조건 등 중요한 규칙은 프론트엔드에만 의존하지 않는다.

### 3. 기록은 삭제보다 보존을 우선한다

학생 생활지도 기록은 가능한 한 hard delete하지 않고 soft delete와 audit log를 사용한다.

### 4. 실제 학생 개인정보는 GitHub seed에 넣지 않는다

Repository에는 fictional/sample data만 저장한다.

### 5. 사람과 권한을 분리한다

```text
Identity ≠ Role
```

한 사람이 특정 역할을 가진 것이지, 역할 자체가 한 사람의 계정이 되어서는 안 된다.

---

# 16. 한 문장 요약

현재의

```text
"선도부가 기록했다"
```

수준에서,

향후에는

```text
"선도부 소속 Daniel Yi가
2026-09-21 20:32에 이 기록을 생성했고,
20:34에 3점에서 1점으로 수정했다."
```

까지 신뢰성 있게 추적할 수 있는 운영 시스템으로 발전시키는 것이 P1의 핵심이다.

---

## In Development — GPT operations foundation

작업 브랜치: `gpt/operations-foundation`

- 실제 운영 요구사항을 `docs/OPERATIONS_ROADMAP.md`로 정리.
- DICS 앱별 학생 master 중복을 중단하고 `core.students.id` UUID를 canonical student identity로 사용하는 통합 스키마 방향으로 확정.
- Student identity와 Auth identity를 분리: `core.students.id`는 학생 자체, `auth_user_id`는 optional 로그인 계정.
- 생활지도 DB에는 불필요한 생년월일/성별을 복제하지 않는 데이터 최소화 원칙 명시.
- `core.students`, `core.academic_terms`, `core.classes`, `core.enrollments` migration foundation 추가. 학년/반을 학기별 enrollment로 관리하도록 변경.
- 기존 Daniel `public.students`는 `core_student_id` bridge를 가진 legacy compatibility table로 전환 준비.
- 상점/벌점 원본은 분리 보존하면서 `net_penalty = negative - positive`를 계산하는 주간 view 추가.
- 달력 월 대신 관리자가 종료하는 `settlement_periods` 모델과 정산기간 집계 view/RPC 추가.
- 반성문 마감을 date가 아닌 `due_at`으로 확장: G7–12 당일 17:00, 재량 21:00 연장, G1–6 익일 08:20 기준.
- 공개형 랜딩 화면을 제거하고 루트 접속 시 바로 관리자 로그인 화면으로 진입하도록 단순화.
- 기존 `public.students.grade` 1–6 제한을 bridge 기간에 G1–G12로 확장.
- Git-ignore roster 재import 대신 **기존 Daniel Supabase 최소 학생 DB를 Core bootstrap source**로 사용하도록 migration 전략 수정.
- `student_no`는 Core에서 최종 공통 키로 유지하되 migration 초기에 없는 학생도 canonical UUID를 먼저 받을 수 있도록 nullable transition 허용.
- 학생 명부 UI를 app-local CRUD에서 **DICS Core read-only roster**로 전환: 학생 추가/삭제는 Core에서만 처리.
- Dashboard를 누적 벌점 중심에서 **주간 상점/벌점/NET + 열린 정산기간 NET** 중심으로 변경 준비.
- 주간 `3회 벌점 OR NET 8+` 체력훈련 대상, 정산기간 `체력훈련 3주 OR NET 20+` 징계위원회 대상 카운트를 Dashboard에 반영.
- SP의 기존 학번 로그인 + 6자리 PIN 규칙을 확인했으며, 기존 Auth UUID는 앞으로 `core.students.auth_user_id`로 연결하는 compatibility 대상으로 정의.
- 이 항목들은 아직 운영 DB/`main`에 적용하지 않은 review 단계이며, 검증 후 상태를 갱신한다.

### Production DB applied — 2026-09-25

- `daniels-scale` 운영 Supabase에 DICS Core bootstrap migration 적용.
- 기존 Daniel 학생 180명 모두 canonical Core UUID 생성/매핑 완료.
  - active 175
  - inactive 5
  - 비활성 학생의 기존 discipline 기록도 Core 경로 유지.
- `core.students` 및 Core RLS / current student projection 적용.
- 주간 NET 계산 및 관리자 종료형 `settlement_periods` 적용.
- 반성문 `due_at` 적용.
  - G7–12 기본 17:00
  - 선도부 재량 21:00 연장 RPC
  - G1–6 익일 08:20
- Core-aware `v_student_summary` / `v_dashboard_counts` 적용.
- 기존 production view의 첫 컬럼 계약을 보존해 기존 frontend와 호환 유지.
- Supabase security advisor의 mutable function search_path 경고 수정.
- 신규 FK access path 인덱스 추가.
- 현재 열린 정산기간은 0개이며, 실제 귀가 사이클 시작일은 관리자가 UI에서 지정하도록 유지.

### Frontend in branch — deployment pending

- 학생 명부를 DICS Core read-only roster 관점으로 변경.
- Dashboard를 주간 NET / 정산 NET 중심으로 개편.
- 선도부 전용 `정산 관리` 화면 추가.
  - 정산 시작일/라벨 지정
  - 현재 기간 종료
  - 종료 다음날 새 기간 자동 시작 선택
- 반성문 화면에 실제 제출 마감 시각 표시 및 중고등부 21시 연장 조치 추가.
- 운영 날짜 기본값을 UTC가 아닌 Asia/Seoul 기준으로 수정.
- 로컬 실행 환경의 외부 GitHub DNS 제한 때문에 이 세션에서 `npm build` 검증은 실행하지 못함.

## Change Log

### 2026-09-25 — 재학생 명단을 Supabase에 적재

Git에는 이름 목록을 넣지 않았다. 행 데이터는 Supabase에만 있다. 다음 세션은 이 절과 원격 마이그레이션 이력으로 재구성한다.

- 출처: `docs/student-roster-26Fall.xlsx`의 재학생 구간. 자퇴·졸업 구간은 넣지 않음.
- 저장 컬럼: `students.name`, `students.grade`만. 주민번호·주소·연락처·학부모명은 적재하지 않음.
- 학년 체크를 1–6에서 1–12로 변경. Git 마이그레이션 `supabase/migrations/20260925000005_grade_1_to_12.sql`. 학생 등록 화면 선택지도 1–12.
- 가상 seed 4명(홍길동, 김민지, 이준호, 박서연, id ≤ 4)은 soft delete. 홍길동의 데모 벌점 기록은 그 행에 남김.
- `docs/G9-student-roster.xlsx`는 9학년 반 배정표. 반(A/B)은 컬럼이 없어 DB에 없음.
- 반 명단에만 있던 이름 1건은 전체 명단의 오타였다. 검토 후 그 행만 soft delete. 본명은 전체 명단 9학년에 이미 있었음. 생활점수 기록은 없었음.
- 적재 후 활성 학생 175명. 학년별 10, 7, 9, 9, 14, 15, 19, 19, 31, 21, 16, 5 (1학년부터 12학년).
- 원격에만 있는 마이그레이션: `import_fall_2026_enrolled_roster`, 그리고 오타 행 soft delete 1건. 이름 SQL은 리포에 없음.
- `부서활동_가산점.xlsx`는 넣지 않음.

### 2026-09-21

- Version Changes 문서 최초 생성
- 현재 SEONDO / SASAENG 역할 구조 설명
- `entered_by_name` 문자열 방식의 한계 문서화
- Individual Admin Identity 구조 제안
- `auth.uid()` 기반 작성자 추적 방향 정의
- Audit Trail 개념 및 단계별 P1 roadmap 정의
