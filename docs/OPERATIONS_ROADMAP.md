# 다니엘의 저울 — Operations Roadmap

> **ACTIVE DESIGN DOCUMENT · 2026-09-25**
>
> 이 문서는 초기 구축 기록이 아니라, 실제 DICS 운영에 맞춰 지금부터 개선할 기능과 데이터 구조를 정의한다.
> 구현이 완료된 변경은 `CHANGELOG.md`에 기록한다.
>
> 학생 실명·학번·PIN·반 배정 명단은 이 공개 저장소에 넣지 않는다.

---

## 1. 이번 개선의 핵심 방향

다니엘의 저울을 단순한 상·벌점 CRUD에서 다음 흐름을 지원하는 운영 콘솔로 확장한다.

```text
아침 벌점 취합
  ↓
빠른 일괄 입력
  ↓
당일 반성문 대상 자동 생성
  ↓
담당 선도부가 학년군별 취합
  ↓
반별 공지/출력
  ↓
주말 주간 정산
  ↓
체력훈련 대상 확인/출력
  ↓
관리자 종료형 정산기간 누적
  ↓
징계위원회 대상 확인
```

이제부터는 **DICS Core 통합 스키마를 목표 구조로 간주한다.** 다니엘의 저울은 독립 학생 DB를 확장하지 않고, Core 학생 원본을 참조하는 discipline 도메인으로 이동한다.

---

## 2. DICS Core 학생 Identity

### 목표 구조

```text
auth.users
   │  (optional login account)
   ▼
core.students
   │
   ├─ study_planner.*
   ├─ discipline.*
   ├─ computer_lab.*
   └─ assessment.*
```

핵심 원칙:

- `core.students.id` = 학교 전체에서 사용하는 canonical `student_id` UUID
- `student_no` = 사람이 확인하는 학교 공통 학번
- `auth_user_id` = **DICS Core 프로젝트 내부** 로그인 계정 연결값이며 학생 ID 자체가 아님
- 외부/legacy Supabase 프로젝트의 Auth UUID는 `core.external_auth_identities`에 별도 보존
- 이름으로 앱 간 학생을 연결하지 않음
- 각 앱에 별도 `students` master table을 새로 만들지 않음

### 기존 시스템의 전환

현재:

- 다니엘의 저울: `public.students.id` serial
- Study Planner: `public.students.id = auth.users.id`

이 두 구조 모두 최종형이 아니다.

전환 후:

```text
core.students.id
      │
      ├─ Daniel's Scale discipline records
      └─ Study Planner records

core.students.auth_user_id
      └─ DICS Core auth.users.id

core.external_auth_identities
      └─ SP 등 외부 프로젝트의 legacy Auth UUID
```

다니엘의 저울의 기존 `public.students`는 전환 기간 동안만 legacy compatibility table로 유지하고, `core_student_id`로 Core 행에 연결한 뒤 최종적으로 discipline FK를 UUID로 교체한다.

### PIN

PIN은 학생 프로필 데이터가 아니라 **인증 수단**이다.

- PIN 평문을 `core.students`에 저장하지 않는다.
- Git에 넣지 않는다.
- Supabase Auth password/PIN 프로비저닝 계층에서 관리한다.
- 학생이 아직 로그인하지 않는 경우에도 `core.students`에는 존재할 수 있다.

### 개인정보 위치

전교생 원본 명부의 생년월일/성별은 필요하다면 `core.students`에만 둔다.

다니엘의 저울이 사용하는 discipline view에는 기본적으로:

```text
student_id
student_no
name
grade
homeroom
```

만 노출한다.

즉 **Core가 보유하는 정보와 각 앱이 실제로 보는 정보를 분리**한다.

## 3. 학기 / 반 배정

학년과 반은 학생의 영구 속성이 아니라 **학기별 소속**이다.

따라서:

```text
core.students
  └─ 학생 자체

core.academic_terms
  └─ 2026 Fall 등

core.classes
  └─ G9-A / G9-B / G11 등

core.enrollments
  └─ 학생 ↔ 학기 ↔ 반
```

구조로 관리한다.

예:

```text
Student A
  student_id = UUID
        ↓
2026-FALL enrollment
        ↓
G9-A
```

2027 Spring에 반이 바뀌어도 학생 master row를 덮어쓰지 않는다.

다니엘의 저울은 현재 학기의 enrollment를 통해 학년/반을 읽으며, 반별 공지와 출력에도 같은 Core 정보를 사용한다.

원본 roster 파일은 Git ignore 상태로 유지하고, 실제 학생 행은 Supabase에서만 관리한다. 현재 Daniel Supabase에 존재하는 이름/학년 최소 DB를 Core bootstrap의 시작점으로 사용한다.

## 4. 점수 계산 원칙

원본 상점과 벌점은 계속 별도 보존한다.

```text
positive_points = 상점
negative_points = 벌점

net_penalty = negative_points - positive_points
```

즉 **원본 데이터를 상쇄해서 지우는 것이 아니라**, 처분 판정 시 계산된 NET 값을 추가로 사용한다.

---

## 5. 주간 정산

주간 기준:

- 월요일 시작
- 매주 새로 계산
- 벌점 사유 발생 횟수 **3회 이상**, 또는
- 주간 `net_penalty >= 8`

이면:

```text
체력훈련 대상
```

주간 출력 화면에서 최소 다음을 보여준다.

| 항목 | 내용 |
|---|---|
| 학생 | 이름 / 학년 / 반 |
| 벌점 발생 횟수 | 주간 NEGATIVE record 수 |
| 상점 | 주간 상점 |
| 벌점 | 주간 벌점 |
| NET | 벌점 - 상점 |
| 판정 | 체력훈련 대상 여부 |

주말에 담당자가 이 화면을 보고 출력할 수 있어야 한다.

---

## 6. “월간” 정산은 달력 월이 아니다

기존 구현의 calendar month 방식은 실제 DICS 운영과 맞지 않는다.

실제 기준은 **귀가 사이클 단위의 관리자 종료형 정산기간**이다.

예:

```text
정산기간 #1
09/07 시작
  ↓
계속 누적
  ↓
09/27 귀가
  ↓
관리자가 [정산 종료] 클릭

정산기간 #2
09/28 시작
...
```

귀가 일정이 불규칙하면 관리자가 종료하지 않는다.

따라서:

> 버튼을 누르지 않는 것 자체가 “다음 주까지 누적”이라는 운영 선택이다.

DB에는 `settlement_periods`를 두고 동시에 하나의 OPEN period만 존재하도록 한다.

---

## 7. 징계위원회 대상

현재 열린 정산기간에서 다음 중 하나이면 대상이다.

- 체력훈련 판정 주차가 **3회 이상**
- 정산기간 `net_penalty >= 20`

```text
physical_training_weeks >= 3
            OR
settlement_net_penalty >= 20
            ↓
징계위원회 회부 대상
```

체력훈련 “3회”는 임시 숫자를 별도 입력하기보다, 각 주차의 체력훈련 대상 판정을 원점수에서 다시 계산할 수 있게 하는 것을 우선한다.

---

## 8. 부서활동 가산점 자동 입력

`부서활동_가산점.xlsx`의 실제 명단은 Git에 넣지 않는다.

목표 흐름:

```text
활동 배정
  ↓
학생별 주간 상점 rule
  ↓
매주 월요일 자동 생성
  ↓
point_records (POSITIVE)
```

필수 조건:

1. 같은 학생/같은 주차에 중복 생성 금지
2. 자동 생성 기록임을 식별 가능
3. 활동 중단/변경 날짜 관리
4. 관리자가 자동 생성 결과 확인 가능
5. 잘못 생성된 행도 hard delete하지 않고 추적 가능

정확한 점수와 활동 목록은 선도부 협의 후 확정한다.

---

## 9. 반성문 운영

### 기본 마감

#### G7–G12

벌점 발생 당일:

```text
기본 마감 = 17:00
```

오후 벌점 등 특별 사유가 있으면 선도부 재량으로:

```text
연장 마감 = 21:00
```

### G1–G6

당일 저녁 제출을 요구하지 않고:

```text
다음 등교일 아침 제출
```

을 기본 원칙으로 한다.

따라서 기존 `submission_deadline date`만으로는 부족하며, 정확한 시간까지 표현하는 `due_at timestamptz`가 필요하다.

---

## 10. 반성문 담당 구조

선도부 구성원은 개인 계정을 사용하고 담당 범위를 가진다.

권장 범위:

```text
ELEMENTARY → G1–G6
MIDDLE     → G7–G9
HIGH       → G10–G12
LEAD       → 전체 / 주간 정산 / 보고
```

실제 담당자 이름은 공개 Git 문서에 기록하지 않고 Supabase 운영 데이터로만 둔다.

선도부장은:

- 누락 확인
- 통합 입력
- 주간 정산
- 담당교사 보고

흐름을 볼 수 있어야 한다.

---

## 11. 아침 벌점 입력 UX

현재 종이 벌점 시트를 오전에 일괄 입력하는 현실을 기준으로 UX를 최적화한다.

### P1

**빠른 일괄 수동 입력**

- 학생 연속 검색
- 키보드 중심 입력
- 날짜 기본값 오늘
- 벌점 항목 반복 입력 최소화
- 저장 후 바로 다음 학생
- 같은 종이 시트의 여러 학생을 짧은 시간에 처리

### P2

**벌점 시트 사진 업로드 보조**

```text
사진
 ↓
텍스트/표 인식
 ↓
후보 기록 생성
 ↓
사람이 반드시 검토
 ↓
확정 저장
```

사진 인식 결과를 검토 없이 자동 확정하지 않는다.

---

## 12. 매일 반별 공지 / 출력

아침 공지를 위해 **오늘의 벌점·반성문 대상 명단**을 학년/반별로 묶는다.

화면:

```text
오늘 공지
├─ G7
├─ G8
├─ G9-A
├─ G9-B
├─ G10
├─ G11
└─ G12
```

필요 기능:

- 날짜 선택
- 학년/반 필터
- 벌점 사유
- 반성문 제출 여부/마감
- A4 인쇄 최적화
- 불필요한 앱 메뉴는 print 시 숨김

이 화면은 “데이터 조회”보다 **통지물을 바로 만드는 기능**으로 설계한다.

---

## 13. 주간 정산 / 출력

주말에는 별도 화면에서:

- 이번 주 벌점 발생 3회 이상
- 이번 주 NET 8 이상
- 체력훈련 대상
- 미제출 반성문
- 정산기간 누적 상태

를 한 번에 확인한다.

주간 보고/체력훈련 대상 명단 역시 A4 출력 가능하게 한다.

---

## 14. Landing / Login

이 시스템은 공개 서비스가 아니라 내부 업무 도구다.

따라서 마케팅형 랜딩 페이지를 유지할 이유가 없다.

목표:

```text
접속
 ↓
다니엘의 저울
ID
Password
[로그인]
```

이미 로그인되어 있으면 즉시 Dashboard로 보낸다.

---

## 15. 관리자 계정 / Audit

기존 방향을 유지한다.

```text
개인 계정
 ↓
role: SEONDO / SASAENG
 ↓
담당 범위
 ↓
created_by / updated_by
 ↓
audit log
```

공용 `seondo` / `sasaeng` 계정은 초기 운영용 legacy 계정으로 보고 개인 계정 전환 후 단계적으로 사용을 줄인다.

---

## 16. Study Planner / 다른 DICS 앱과의 관계

DB 통합을 먼 미래 과제로 미루지 않고, **지금부터 모든 신규 설계를 Core 기준으로 한다.**

다만 운영 중인 기존 앱을 한 번에 깨뜨리지 않기 위해 migration은 단계적으로 진행한다.

### Phase A — Core 생성

- `core.students`
- `core.academic_terms`
- `core.classes`
- `core.enrollments`
- 공통 학번
- optional Core-local `auth_user_id`
- external/legacy Auth bridge

### Phase B — Legacy Mapping

```text
Daniel public.students.id (int)
          ↓
core_student_id
          ↓
core.students.id (uuid)
```

Study Planner의 기존 Auth UUID 기반 학생 행도 같은 Core 학생에 매핑하되, 외부 프로젝트 Auth UUID는 `core.external_auth_identities`에 보존한다. Core-local `auth_user_id`는 Auth consolidation 이후 별도로 provision한다.

### Phase C — Domain FK Cut-over

최종적으로:

```text
discipline.*.student_id
study_planner.*.student_id
computer_lab.*.student_id
assessment.*.student_id
        ↓
core.students.id
```

가 되도록 전환한다.

### Phase D — Unified Student Profile

추후 Student Portal / Study Planner에서:

- 학습 진척도
- 생활점수/벌점
- 시험 결과
- 컴퓨터실 사용기록

을 같은 `core.student_id`로 조합한다.

즉 Cross-project 연결을 위해 이름이나 학번 문자열로 JOIN하는 것이 아니라 **동일 UUID FK를 사용**하는 것이 최종 목표다.

## 17. 구현 우선순위

### P1-A — DICS Core + 운영 기반

- [x] `core.students` 설계
- [x] `core.academic_terms / classes / enrollments` 설계
- [x] Daniel legacy `public.students.core_student_id` bridge migration 준비
- [x] 기존 Daniel Supabase 최소 학생 DB(이름/학년)를 기준으로 Core UUID bootstrap migration 준비
- [x] 기존 Daniel 학생 행을 운영 DB에서 Core UUID로 실제 매핑 적용
- [ ] Study Planner 기존 학생과 Core mapping 계획 확정
- [~] 현재 학기 enrollment: G1–8/G10–12 완료, G9-A/B 31명 검증 대기
- [x] 간단 로그인 화면 변경 준비
- [x] 주간 positive / negative / NET 계산 view 준비
- [x] 주간 체력훈련 대상 판정 준비

### P1-B — 정산기간

- [x] `settlement_periods`
- [x] OPEN period
- [x] 관리자의 정산 종료
- [x] 정산기간 NET
- [x] 체력훈련 대상 주차 수
- [x] 징계위원회 대상 판정

### P1-C — 반성문 운영

- [x] 시간형 마감 `due_at`
- [x] G7–12 17:00
- [x] 21:00 연장
- [x] G1–6 익일 등교 제출
- [x] 학년군 담당자
- [x] 오늘의 반성문 대상 화면
- [x] 반별 출력

### P1-D — 주간 보고

- [x] 주간 정산 화면
- [x] 체력훈련 대상 출력
- [x] 관리자용 누락/집계 확인

### P2 — 자동화

- [x] 부서활동 월요일 상점 자동 입력 foundation
- [x] 일괄 입력 UX 고도화
- [ ] 벌점 시트 사진 업로드 + 검토 기반 추출
- [x] 개인 관리자 계정 구조 + 상세 Audit trail foundation

### P3 — Legacy 제거 / 통합 프로필

- [ ] discipline 테이블 FK를 `core.students.id` UUID로 전환
- [ ] 기존 `public.students` legacy master 제거
- [ ] Study Planner FK를 동일 Core UUID로 전환
- [ ] 컴퓨터실/Assessment 신규 테이블은 처음부터 Core UUID 사용
- [ ] 전교생 PIN/Auth 프로비저닝 정책 통일
- [ ] 학생 본인 화면에 학습 + 생활점수 + 학교 기록 통합

---

## 18. 데이터 보호 원칙

- 실제 학생 명단/학번/PIN은 Git에 올리지 않는다.
- 학생 이름 목록이 들어간 SQL migration도 Git에 올리지 않는다.
- discipline 앱에는 기능상 필요 없는 생년월일/성별을 복제하지 않는다.
- 출력물은 업무상 필요한 최소 정보만 포함한다.
- 사진 업로드 기능이 도입되면 보존 기간과 삭제 정책을 함께 정의한다.
