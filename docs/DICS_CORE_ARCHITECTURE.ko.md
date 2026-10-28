# DICS Core Integrated Schema

**Language / 언어:** [English](DICS_CORE_ARCHITECTURE.md) | [한국어](DICS_CORE_ARCHITECTURE.ko.md)

> 2026-10-28 이후의 판정·G9 담당범위는 [현재 생활지도 규칙](DISCIPLINE_RULES.ko.md)을 우선한다. 아래의 이전 설계·기록은 해당 시점의 근거로 보존한다.

> **Target architecture · 2026-09-25**
>
> 다니엘의 저울, Study Planner, 컴퓨터실 사용기록, Assessment 계열 앱은 장기적으로 하나의 DICS Core Supabase 안에서 동일한 학생 Identity를 사용한다.
>
> 이 문서는 다니엘의 저울 관점에서 통합 DB로 이동하는 기준을 정의한다.

---

## 1. 핵심 원칙

```text
한 학생 = 하나의 core.student_id
```

앱별로 별도의 학생 Master를 만들지 않는다.

```text
❌ study_planner.students
❌ discipline.students
❌ computer_lab.students
❌ assessment.students

✅ core.students
```

각 도메인 기록은 모두 동일한 UUID를 FK로 사용한다.

---

## 2. Student Identity와 Login Identity 분리

학생 자체와 로그인 계정은 다른 개념이다.

```text
core.students.id
= 학생의 학교 시스템 Identity

auth.users.id
= 로그인 계정 Identity
```

따라서:

```text
core.students
├─ id             UUID PK
├─ student_no     학교 공통 학번
├─ auth_user_id   nullable FK → auth.users
├─ name
├─ birth_date
├─ gender
└─ is_active
```

로그인이 없는 학생도 Core에는 존재할 수 있다.

이 원칙 때문에 기존 Study Planner의:

```text
students.id = auth.users.id
```

구조는 장기적으로 분리한다.

---

## 3. 학년 / 반은 학기 소속

`grade`와 `homeroom`을 학생 Master에 영구 저장하면 진급/반 변경 이력을 덮어쓰게 된다.

따라서:

```text
core.students
        │
        └── core.enrollments
                │
                ├── core.academic_terms
                └── core.classes
```

예:

```text
김학생
student_id = 1d2... UUID

2026 Fall
└─ G9-A

2027 Spring
└─ G10
```

현재 학년/반은 현재 term의 enrollment에서 계산한다.

---

## 4. Domain Schema

최종 목표:

```text
DICS Core Supabase

core
├─ students
├─ academic_terms
├─ classes
└─ enrollments

study_planner
├─ term_goals
├─ week_plans
├─ plan_items
└─ progress...

discipline
├─ point_items
├─ point_records
├─ reflections
├─ punishments
├─ settlement_periods
└─ audit_logs

computer_lab
├─ checkins
├─ sessions
└─ device_logs

assessment
├─ tests
├─ responses
└─ results
```

각 도메인의 `student_id`는:

```text
references core.students(id)
```

를 사용한다.

---

## 5. Public schema의 역할

브라우저 앱이 내부 테이블 전체를 직접 보지 않도록:

```text
core / discipline / study_planner
        ↓
public views / RPC
        ↓
Frontend
```

구조를 기본으로 한다.

예:

```text
core.students
  ↓
public.v_core_current_students
  ↓
Daniel's Scale
```

다니엘의 저울에는 생년월일/성별이 필요하지 않으므로 해당 public projection에서 제외한다.

---

## 6. Daniel's Scale 전환

현재 운영 구조:

```text
public.students.id (int)
       ↓
public.point_records.student_id
public.punishments.student_id
```

최종 구조:

```text
core.students.id (uuid)
       ↓
discipline.point_records.student_id
discipline.punishments.student_id
discipline.reflections → point_record
```

한 번에 바꾸지 않고 다음 순서로 이동한다.

### Step 1 — Core 생성

```text
core.students
core.academic_terms
core.classes
core.enrollments
```

### Step 2 — 기존 Supabase 최소 roster에서 Core bootstrap

Daniel's Scale 운영 Supabase에 이미 존재하는 이름/학년 최소 학생 DB를 시작점으로 사용한다.

- 각 legacy 학생 행에 canonical Core UUID를 발급
- 같은 UUID로 `core.students` 행 생성
- 이름/학년 파일을 Git에 다시 올리거나 seed SQL로 복제하지 않음
- 학번/Auth/반/생년월일/성별은 확인 가능한 운영 데이터에서 단계적으로 보강

즉 Core 생성의 첫 단계는 "엑셀 재import"가 아니라 **기존 운영 DB 승격**이다.

### Step 3 — Legacy bridge

```text
public.students.core_student_id
        ↓
core.students.id
```

모든 기존 Daniel 학생 행이 정확한 Core 학생과 연결됐는지 검증한다.

**이름 자동 매칭만으로 확정하지 않는다.**

### Step 4 — Discipline FK cut-over

모든 mapping이 완료된 뒤:

- point records
- punishments
- reflection 관련 조회
- settlement 집계

를 UUID Core FK 기준으로 옮긴다.

### Step 5 — Legacy student master 제거

더 이상 `public.students`가 학생 원본 역할을 하지 않도록 제거/compatibility view화한다.

---

## 7. Study Planner 전환

현재 SP는 **별도 Supabase 프로젝트**에서 운영되고 있으며 학생 Auth UUID를 곧바로 student PK로 사용한다.

여기서 중요한 제약이 있다.

```text
SP auth.users.id
```

는 SP Supabase 프로젝트의 Auth identity이고,

```text
DICS Core auth.users.id
```

는 Core Supabase 프로젝트의 Auth identity다.

UUID 문자열 형식이 같더라도 **서로 다른 Auth namespace**이므로 기존 SP UUID를 곧바로:

```text
core.students.auth_user_id
```

FK에 넣으면 안 된다.

### Migration 기간

```text
SP external auth.users.id
        ↓
core.external_auth_identities
        ↓
core.students.id
        ↓
canonical student identity
```

`core.external_auth_identities`는 외부 프로젝트의 identity를 FK가 아닌 text identifier로 보존한다.

예:

```text
source_system      = STUDY_PLANNER
source_project_ref = <SP project ref>
external_user_id   = <SP auth UUID>
student_id         = core.students.id
```

PIN/password는 이 bridge에 저장하지 않는다.

### 최종 통합 후

학생 계정을 DICS Core Auth에 provision/migrate하면:

```text
DICS Core auth.users.id
        ↓
core.students.auth_user_id
        ↓
core.students.id
        ↓
study_planner.*
discipline.*
computer_lab.*
assessment.*
```

가 된다.

따라서 기존 SP의 외부 Auth UUID는 migration provenance로 남고,
새 domain FK는 모두 canonical `core.students.id`를 사용한다.

---

## 8. PIN

PIN은 Core 프로필 값이 아니다.

```text
student_no → login identifier
PIN        → auth credential
```

PIN 평문 컬럼:

```text
core.students.pin
```

은 만들지 않는다.

Supabase Auth가 credential을 관리한다.

---

## 9. 개인정보 최소 노출

Core는 학교 Master이므로 생년월일/성별 등을 보유할 수 있다.

하지만 Domain app은 필요한 정보만 본다.

### Daniel's Scale

기본 노출:

```text
student_id
student_no
name
grade
homeroom
```

기본 미노출:

```text
birth_date
gender
auth_user_id
```

### 원칙

```text
Core can know more.
Apps should see less.
```

---

## 10. RLS 원칙

권한은 Frontend 버튼이 아니라 DB가 강제한다.

학생:

```text
자기 Core identity / 자기 앱 데이터
```

선도부:

```text
discipline 업무 범위
```

사생회:

```text
discipline 처분 업무 범위
```

교사/Admin:

```text
역할에 따라 필요한 범위
```

통합 이후에는 앱별 공용계정보다 개인 Auth + domain role을 사용한다.

---

## 11. Query 원칙

DICS Core가 여러 앱의 공통 DB가 되므로 다음을 전역 규칙으로 한다.

```text
Avoid select('*') in production.
Select required columns only.
Use pagination.
Use server-side aggregation.
Use proper indexes.
Prefer event-driven refresh.
Do not poll whole tables.
```

---

## 12. 현재 Daniel 작업 브랜치의 의미

`gpt/operations-foundation`은 이제 schema 준비 단계를 넘어 **운영 DB를 backward-compatible하게 단계적 전환 중**이다.

현재 적용된 것:

- Core student UUID 180명 bootstrap 및 legacy bridge
- 2026 Fall current term + 13개 class
- G1–8/G10–12 enrollment 144명
- G9-A/B 31명 검증 대기
- 기존 SP pilot 중 검증된 28명의 student_no Core 보강
- external app Auth identity bridge
- 주간 NET / settlement / reflection due-time / audit foundation

다음 단계는 **G9-A/B 실제 명단 검증, 나머지 전교생 student_no 발급정책 확정, SP external Auth mapping**이다.

충분한 mapping 검증 후 discipline FK를 legacy integer에서 canonical Core UUID로 전환한다.
