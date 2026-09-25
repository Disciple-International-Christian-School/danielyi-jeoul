# 다니엘의 저울 — Development Journal

> **Living narrative · started 2026-09-25**
>
> 이 문서는 단순한 Change Log가 아니다.
> 나중에 학교 내부 보고, 개발 회고, 제품 소개, 포트폴리오, DICS 디지털 전환 기록에 사용할 수 있도록
> **문제의 맥락 → 발견 → 판단 → 구현 → 검증 → 다음 과제**를 서사적으로 보존한다.
>
> 실제 학생 이름, PIN, 명부 원본 등 PII는 기록하지 않는다.

---

## 0. 이 프로젝트가 바뀐 지점

다니엘의 저울은 처음부터 “통합 학교 플랫폼”으로 시작한 프로젝트가 아니었다.

출발점은 매우 현실적이었다.

- 선도부가 종이로 모으는 벌점을 전산화한다.
- 반성문 제출을 놓치지 않는다.
- 사생회 처분을 기록한다.
- 주간 생활지도 대상을 빠르게 찾는다.

초기에는 이 업무를 빠르게 화면으로 옮기는 것이 중요했다.

하지만 실제 운영 요구를 하나씩 붙이면서 문제가 드러났다.

```text
벌점 앱의 학생
Study Planner의 학생
컴퓨터실의 학생
배치고사의 학생

이 학생들이 모두 같은 사람인데,
각 앱이 서로 다른 방식으로 학생을 정의하고 있었다.
```

여기서 프로젝트의 성격이 바뀌었다.

**“벌점 사이트를 잘 만드는 것”보다 “DICS가 학생을 한 사람으로 일관되게 식별하는 기반을 만드는 것”이 더 중요한 문제**가 되었다.

이 판단이 DICS Core 통합 설계의 출발점이다.

---

# 1. Prototype에서 실제 운영 시스템으로

## 문제

초기 prototype은 빠르게 기능을 검증하기에는 적합했다.

그러나 운영 시스템으로 보기 시작하면 다음 질문이 생겼다.

- 학생은 누가 관리하는가?
- 벌점 기준 기간은 달력 월인가, 실제 귀가 주기인가?
- 반성문은 날짜만 관리하면 되는가?
- 누가 입력했고 누가 수정했는가?
- 학생이 전학/졸업/비활성화되면 과거 기록은 어떻게 남는가?
- 여러 학교 앱에서 같은 학생을 어떻게 연결하는가?

## 판단

Frontend가 학교 규칙을 “그럴듯하게” 구현하는 것보다,
**DB가 업무 규칙과 기록 책임성을 강제**하는 방향을 택했다.

따라서 구조를:

```text
React/Vite
  ↓
Supabase Auth
  ↓
PostgreSQL
Views / RPC / Triggers / RLS
```

로 정리했다.

## 의미

이 단계부터 다니엘의 저울은 단순 CRUD 화면이 아니라
**학교 생활지도 규칙을 데이터 구조로 표현하는 시스템**이 되기 시작했다.

---

# 2. 첫 번째 큰 전환 — 학생 ID를 다시 정의하다

## 발견

Study Planner와 Daniel's Scale의 학생 identity가 달랐다.

Daniel:

```text
public.students.id = serial integer
```

Study Planner:

```text
students.id = auth.users.id
```

둘 다 각 앱 안에서는 작동했다.

하지만 두 시스템을 합치려 하면 문제가 생긴다.

**학생 자체와 로그인 계정은 같은 개념이 아니다.**

초등학생처럼 로그인 계정이 아직 없는 학생도 학교 시스템에는 존재해야 한다.
반대로 로그인 계정 UUID를 학생의 영구 identity로 쓰면 인증 방식이 학생 데이터 모델을 지배하게 된다.

## 결정

```text
core.students.id
= canonical student UUID

core.students.auth_user_id
= optional login account

core.students.student_no
= 학교가 사람이 확인하는 공통 학번
```

으로 분리했다.

## 구현 전략

운영 DB를 한 번에 갈아엎지 않았다.

기존 Daniel 학생 테이블에:

```text
core_student_id
```

bridge를 추가하고,
기존 학생 행 하나하나에 UUID를 직접 발급했다.

이 과정에서 이름으로 자동 매칭하지 않았다.

### 이유

동명이인이 있을 수 있고,
이름/학년 문자열은 identity가 아니기 때문이다.

## 운영 적용 결과

2026-09-25 기준:

```text
legacy student rows 180
        ↓
Core UUID mapping 180 / 180

active   175
inactive   5
```

비활성 학생도 Core에서 제거하지 않았다.

실제 점수기록이 연결된 비활성 학생이 확인되었기 때문이다.

### 이 발견이 바꾼 것

초기 migration은 active 학생만 옮길 수도 있었지만,
운영 DB를 읽어보니 **비활성 학생에게도 보존해야 할 discipline history가 존재**했다.

그래서 원칙을:

> “현재 재학생 명부”와 “학교가 보존해야 할 학생 identity”는 다르다.

로 수정했다.

이 결정은 이후 졸업·전학 학생 기록 보존에도 그대로 적용된다.

---

# 3. 예상하지 못한 Legacy 제약 — G1–G6만 허용

Core 전환 중 기존 `public.students.grade` constraint가
G1–G6만 허용하고 있다는 사실을 발견했다.

초기 prototype의 범위가 DB constraint에 남아 있었던 것이다.

하지만 실제 운영 DB에는 G1–G12 학생이 존재한다.

## 대응

전환 기간 legacy table의 grade constraint를 G1–G12로 확장했다.

Core의 최종 학년/반은 학생 master에 고정하지 않고:

```text
core.academic_terms
core.classes
core.enrollments
```

로 옮기는 방향을 유지했다.

## 교훈

Prototype에서 자연스러웠던 constraint가
운영 범위가 확대되면 migration blocker가 될 수 있다.

따라서 이후 migration에서는 “현재 데이터가 실제로 무엇을 담고 있는가”를 먼저 조회한 뒤 적용하는 방식을 강화했다.

---

# 4. “월간 벌점”을 버리다

## 기존 모델

초기 로직에는 calendar month 기준 벌점 누적이 있었다.

그러나 실제 DICS 운영은 달력 월과 맞지 않았다.

학생들의 귀가 주기는 대체로 3주이지만 상황에 따라 2주가 될 수도 있고,
관리자가 실제 귀가 시점에 정산을 끊어야 했다.

## 운영 요구를 데이터 모델로 번역

```text
OPEN settlement
      ↓
계속 누적
      ↓
실제 귀가
      ↓
관리자가 종료
      ↓
다음 settlement
```

즉 “관리자가 버튼을 누르지 않았다”는 것도 의미 있는 운영 결정이다.

## 구현

`settlement_periods`를 만들고
동시에 하나의 OPEN period만 존재하도록 DB가 보장한다.

판정 기준도 raw 벌점이 아니라:

```text
NET = 벌점 - 상점
```

을 사용한다.

### 주간

- 벌점 incident 3회 이상
- 또는 NET 8 이상

→ 체력훈련 대상

### 정산기간

- 체력훈련 판정 주차 3회 이상
- 또는 정산 NET 20 이상

→ 징계위원회 대상

## 의미

학교의 실제 업무 흐름을 달력 단위에 억지로 맞추지 않고,
**업무 자체가 가진 경계(event)를 DB 모델로 사용한 사례**다.

---

# 5. 반성문 — 날짜에서 “운영 시간”으로

## 발견

기존 반성문 deadline은 date였다.

하지만 실제 규칙은 시간까지 필요했다.

- G7–G12: 당일 17:00
- 오후 벌점 등: 선도부 재량 21:00
- G1–G6: 다음 등교 아침

## 결정

```text
submission_deadline date
```

만으로는 부족하므로:

```text
due_at timestamptz
```

를 추가했다.

## 운영적 의미

같은 “미제출”이라도:

- 아직 마감 전인지
- 마감이 지나 2배 제출 대상인지

를 정확한 시각으로 판정할 수 있게 되었다.

---

# 6. KST 버그를 발견하다

Frontend의 기존 `today()`는:

```text
new Date().toISOString().slice(0, 10)
```

방식이었다.

이는 UTC 날짜다.

한국 시간 00:00–08:59 사이에는
업무 화면의 기본 날짜가 전날로 잡힐 수 있었다.

생활지도 입력이 아침에 집중되는 시스템에서는 작은 문제가 아니었다.

## 수정

모든 operational date 기본값을:

```text
Asia/Seoul
```

기준으로 명시했다.

## 교훈

학교 운영 시스템에서 timezone은 표시 형식이 아니라
**업무 규칙의 일부**다.

---

# 7. 출력은 “부가기능”이 아니라 업무의 마지막 단계

처음에는 목록 화면이 있으면 충분해 보였다.

하지만 실제 목적은 목록을 보는 것이 아니었다.

- 아침에는 반별로 공지해야 한다.
- 주말에는 체력훈련 대상자를 취합해야 한다.
- 담당교사에게 보고해야 한다.

즉 조회 결과의 최종 산출물은 종종 **종이/보고서**였다.

## 구현

서버 측 projection:

- `v_daily_discipline_notice`
- `v_weekly_discipline_report`

Frontend:

- 날짜 선택
- 학년/반 필터
- 반별 그룹
- A4 print stylesheet
- 앱 navigation 숨김

## 설계 의미

“조회 화면에 인쇄 버튼을 붙였다”가 아니라,
**통지/보고 자체를 하나의 업무 workflow로 모델링**했다.

---

# 8. 아침 벌점 입력 — 현장 시간을 기준으로 UX를 다시 만들다

사용 패턴을 다시 보면 벌점은 오전에 종이 시트를 모아
여러 건을 연속 입력하는 경우가 많았다.

일반적인 CRUD form은 이 상황에 비효율적이다.

## 개선

연속입력 모드:

- 이름/학번/반 검색
- 결과가 한 명이면 Enter 선택
- 저장 후 학생만 초기화
- 벌점 항목/점수/날짜/기입자 유지
- 학생 검색창으로 자동 focus
- 최근 저장 6건 즉시 확인

## 판단

사진 OCR을 먼저 만들지 않았다.

### 이유

사진 인식은 편리하지만 오인식 검토 UI, 개인정보 처리, 보존정책까지 같이 필요하다.

반면 연속입력 최적화는
현재 업무를 바로 줄이면서도 데이터 정확도를 낮추지 않는다.

따라서:

```text
P1 = 빠른 수동 일괄입력
P2 = 사진 인식 + 사람 검토
```

순서로 결정했다.

---

# 9. 부서활동 자동 상점 — scheduler보다 idempotency가 먼저

요구사항은 “매주 월요일 자동 상점”이었다.

처음 생각하면 cron job이 떠오른다.

운영 Supabase를 확인한 결과 `pg_cron`은 설치 가능하지만 활성화되어 있지 않았다.

## 결정

scheduler부터 켜지 않았다.

먼저 다음을 만들었다.

```text
core.departments
core.department_memberships

discipline.department_merit_rules

point_records.source_type
point_records.source_key
```

그리고:

```text
ensure_weekly_department_merits()
```

RPC가 같은 주/같은 membership에 대해
**몇 번 호출되어도 한 번만 생성**하도록 했다.

Frontend는 선도부가 Dashboard에 처음 들어올 때
그 주 월요일 누락분을 보장한다.

## 이유

자동화의 핵심은 “정확히 월요일 00시에 실행됨”보다
**중복 없이 결국 정확한 결과가 만들어지는 것**이다.

scheduler를 나중에 붙여도 같은 RPC를 재사용할 수 있다.

---

# 10. 개인 관리자 Identity와 담당범위

초기 운영은 공유 계정:

```text
SEONDO
SASAENG
```

중심이었다.

하지만 실제 운영에서는:

- 초등 담당
- 중등 담당
- 고등 담당
- 선도부장

업무범위가 다르다.

## 추가 모델

```text
admins.discipline_scope
  ELEMENTARY
  MIDDLE
  HIGH
  ALL

admins.is_lead
admins.is_active
```

기존 shared SEONDO 계정은
전환 중 운영이 깨지지 않도록:

```text
ALL + lead
```

로 유지했다.

## 화면 변화

- 반성문: 담당 학년군 우선
- 일일 공지: 담당 범위
- 주간 정산 보고: lead
- 정산기간 시작/종료: lead

### 중요한 원칙

UI에서 메뉴만 숨긴 것이 아니다.

정산 RPC 자체가 lead 권한을 검사한다.

---

# 11. entered_by_name에서 인증된 작성자로

초기에는:

```text
entered_by_name = "..."
```

문자열을 사용했다.

이는 표시에는 편하지만 작성자를 증명하지 못한다.

## 개선

```text
created_by = auth.uid()
updated_by = auth.uid()
```

를 DB trigger에서 자동 기록한다.

기존 `entered_by_name`은 migration 동안 display/legacy 호환용으로 유지한다.

## Audit Log

`discipline.audit_logs`를 추가해:

- INSERT
- UPDATE
- DELETE

의 before / after JSON을 저장한다.

대상:

- point records
- reflection records
- punishments
- settlement periods

## 과거 기록은 왜 backfill하지 않았는가

과거 공유계정 시기의 실제 작성자를 확정할 근거가 없기 때문이다.

추정값을 넣는 것보다:

```text
unknown = null
```

로 남기는 것이 감사기록으로서 더 정직하다.

---

# 12. CI가 개발방식을 바꾼 순간

브랜치 변경을 쌓으면서 처음 CI를 추가했다.

```text
npm ci
  ↓
typecheck
  ↓
Vite build
```

첫 실행에서 실패했다.

원인은 큰 architecture 문제가 아니라
사용하지 않는 TypeScript import 하나였다.

## 의미

작은 오류였지만 중요한 전환점이었다.

이전에는 “코드를 작성했다”가 완료 기준이었다면,
이후부터는:

```text
코드 작성
  ↓
자동 검증
  ↓
통과
  ↓
다음 단계
```

가 기본 흐름이 되었다.

그 뒤의 주요 frontend 변경은 PR/push CI를 통과시키며 진행하고 있다.

---

# 13. Database migration에서 얻은 실제 교훈

## View 교체 실패

Core-aware `v_student_summary`를 적용할 때
기존 view의 컬럼 구조를 바꾸려 하자 PostgreSQL이 교체를 거부했다.

## 대응

기존 production contract의 첫 컬럼 순서를 그대로 유지하고,
새 Core/NET 컬럼을 뒤에 추가했다.

## 의미

운영 시스템 migration에서는
“새 구조가 더 좋다”는 이유만으로 기존 API contract를 깨면 안 된다.

**Backward compatibility 자체가 하나의 기능**이다.

---

# 14. Claude + GPT 병렬 개발

Study Planner는 Claude Code에서 이미 개발 중이었다.

통합 작업을 위해 Claude 세션과 GPT 세션이 서로의 대화내용에 의존하지 않도록
GitHub를 공용 source of truth로 정했다.

SP repo:

```text
main
├─ claude/*
└─ gpt/*
```

공용 coordination issue에는:

- 현재 branch
- PR
- 변경 파일
- DB 변경
- 다음 작업
- blocker

를 handoff 형식으로 남긴다.

## 실제 첫 협업

Claude가 GPT branch를 검증하며
새 identity bridge view 때문에 verification의 예상 view count가
4 → 5가 되어야 한다는 점을 발견했다.

GPT가 이를 바로 수정하고,
비학생 test account를 `is_active`로 단순 제외하면 안 된다는
mapping rule도 문서화했다.

## 의미

병렬 AI 개발의 핵심은
두 모델이 같은 채팅을 읽는 것이 아니라:

> **같은 repository state와 명시적인 handoff contract를 읽는 것**

이라는 운영방식을 검증했다.

---

# 15. 2026-09-25 Readiness Snapshot

현재 Daniel 운영 DB의 aggregate 상태:

```text
Core students                 180
student_no assigned             0
Auth linked                     0

academic terms                  0
current terms                   0
classes                         0
enrollments                     0

departments                     0
department memberships          0
department merit rules          0

admin accounts                  2
active discipline records       1
audit records                   0
```

현재 active 학생 학년 분포:

```text
G1   10
G2    7
G3    9
G4    9
G5   14
G6   15
G7   19
G8   19
G9   31
G10  21
G11  16
G12   5
----------------
Total 175
```

## 이 snapshot이 보여주는 것

Core identity 자체는 만들어졌다.

하지만 아직 학교 공통 Directory로 완성되지는 않았다.

다음 빈칸은 명확하다.

```text
student_no / Auth
academic term / class / enrollment
department memberships / rules
personal admin provisioning
```

즉 현재 단계는:

> **생활지도 domain의 운영 규칙은 상당히 성숙했지만,
> DICS Core의 학교 공통 Directory enrichment가 다음 병목인 상태**

다.

---

# 16. 다음 개발 서사에서 추적할 질문

다음 Phase부터는 아래 질문을 계속 기록한다.

1. 2026 Fall current term을 어떻게 안전하게 생성할 것인가?
2. G9-A/B 분반을 실데이터와 어떻게 연결할 것인가?
3. SP의 기존 `student_no + auth UUID`를 Core에 어떻게 보강할 것인가?
4. 이름을 identity로 사용하지 않고도 두 기존 DB를 어떻게 reconcile할 것인가?
5. 실제 부서활동 명단/점수 규칙을 Git에 PII 없이 어떻게 적재할 것인가?
6. legacy integer FK를 Core UUID로 언제 cut-over하는 것이 안전한가?
7. shared admin account를 개인계정으로 전환할 때 운영 중단을 어떻게 피할 것인가?

---

# 17. 보고서 작성 시 사용할 수 있는 핵심 메시지

현재까지의 개발을 한 문장으로 요약하면:

> **“기존 학교 업무를 단순히 웹으로 옮긴 것이 아니라, 실제 운영에서 드러난 예외와 책임구조를 데이터 모델로 다시 정의하면서 여러 교육 시스템이 같은 학생을 공유할 수 있는 DICS Core 기반으로 확장했다.”**

또 다른 관점에서는:

> **“빠른 prototype → 운영 데이터 검증 → backward-compatible migration → Core identity → 업무 자동화 → auditability → cross-project integration”**

의 순서로 진행된 프로젝트다.

이 문서는 이후 개발에서도 계속 누적한다.


---

# 18. Current Term Provisioning — “추측하지 않는 자동화”

Core 학생 UUID가 모두 준비된 뒤에도 학기/반 정보는 비어 있었다.

2026-09-25 readiness:

```text
core.students       180
academic_terms        0
classes               0
enrollments           0
```

생활지도 화면은 기존 legacy grade를 fallback으로 사용할 수 있었지만,
반별 공지와 장기 통합을 위해서는 실제 학기별 enrollment가 필요했다.

## 데이터 원본 확인

과거에 공유된 `2026-7학사일정 (2).hwp`를 다시 찾아
2026 Fall의 경계를 확인했다.

가을학기 표에서:

- 2026-08-19: 시업 및 입학식
- 2027-01-21: 방학식
- 겨울방학: 2027-01-21 시작

이 흐름을 근거로:

```text
2026-FALL
starts_on = 2026-08-19
ends_on   = 2027-01-21
```

로 Core term을 정의했다.

## 가장 중요한 제약

G9은 A/B 분반이다.

하지만 현재 Daniel Supabase에는 G9 학생의 “학년=9” 정보만 있고,
A/B 개인별 배정 근거는 없었다.

따라서 자동화 범위를 명확히 잘랐다.

```text
G1–8     → 현재 grade로 자동 enrollment
G10–12   → 현재 grade로 자동 enrollment

G9       → 자동배정 금지
           A/B 명단 확인 후 수동 배정
```

이 결정은 “자동화 가능한 것”보다
**“근거가 있는 것만 자동화한다”**는 원칙을 우선한 사례다.

---

# 19. Runtime-only DB Bug — CI가 잡지 못한 것

학기 provisioning RPC는 migration 적용도 성공했고,
frontend typecheck/build도 성공했다.

하지만 production에서 실제 함수를 처음 호출하자 실패했다.

원인:

```text
v_classes_created := v_classes_created + row_count
```

PL/pgSQL의 `ROW_COUNT`는 일반 변수처럼 직접 참조할 수 없고:

```text
GET DIAGNOSTICS variable = ROW_COUNT;
```

로 읽어야 한다.

## 왜 이 버그가 의미 있었는가

이 오류는:

- SQL migration 적용 단계에서는 발견되지 않았고
- frontend CI에서도 발견되지 않았고
- 실제 function execution path에서만 드러났다.

즉:

> **컴파일/빌드 성공과 운영 경로 검증은 서로 다른 품질 단계다.**

라는 사실을 보여줬다.

## 안전성 확인

함수 호출 자체가 실패했기 때문에 PostgreSQL statement 전체가 rollback됐다.

즉 실패 직후:

```text
terms        0
classes      0
enrollments  0
```

임을 직접 확인했다.

부분 생성된 학적 데이터는 없었다.

## 수정 방식

이미 production에 적용된 migration 파일을 소급 수정하지 않았다.

대신 별도의 correction migration:

```text
20260925000017_fix_current_term_setup_runtime.sql
```

을 추가했다.

이 방식은 migration history 자체를 개발 기록으로 보존한다.

---

# 20. Current Term 실제 적용 결과

correction migration 후 동일한 provisioning RPC를 다시 실행했다.

결과:

```text
2026-FALL
2026-08-19 ~ 2027-01-21

classes created        13
enrollments created   144
G9 pending              31
```

13개 class 구조:

```text
G1
G2
G3
G4
G5
G6
G7
G8
G9-A
G9-B
G10
G11
G12
```

활성 학생 175명 중:

```text
non-G9 144명 → 자동 enrollment 완료
G9      31명 → A/B 검증 대기
```

## 이 단계의 의미

이제 “학생이 몇 학년인가”를 Daniel의 legacy student row에만 의존하지 않고,
Core가:

```text
학생 자체
  ↓
2026 Fall
  ↓
학급
```

관계를 실제로 보유하기 시작했다.

즉 DICS Core가 단순 UUID registry에서
**학적(directory + enrollment) 시스템으로 한 단계 진입한 시점**이다.

---

# 21. Core Provisioning Console

학기/반 생성 작업을 SQL 콘솔에서 반복하지 않도록
선도부장 전용 `Core 설정` 화면을 추가했다.

기능:

- 학기 코드/이름
- 시작일/종료일
- current term 초기화
- class/enrollment readiness 확인
- G9 미배정 인원 확인
- G9-A / G9-B 개별 배정

## 의도

이 화면은 Daniel's Scale의 장기 업무화면이라기보다
**DICS Core가 별도 Admin app으로 분리되기 전의 provisioning console**이다.

장기적으로는:

```text
Daniel's Scale
→ discipline domain only

DICS Core Admin
→ students / terms / classes / enrollment / shared identity
```

로 책임을 분리하는 것이 목표다.

---

# 22. 2026-09-25 Updated Readiness

Current production aggregate:

```text
Core students                 180
active students               175

current academic term           1
classes                        13
active enrollments            144
G9 pending                     31

student_no assigned             0
Auth linked                     0

departments                     0
department memberships          0
department merit rules          0
```

다음 병목은 더 선명해졌다.

1. G9-A/B 실제 명단 확인
2. SP의 기존 student_no/Auth를 Core에 연결
3. 부서활동 실제 membership/rule 적재
4. 개인 관리자 계정 provision
5. 충분한 검증 후 discipline FK를 Core UUID로 cut-over

이제부터는 “새 기능을 더 만드는 단계”보다
**기존 학교 데이터를 Core에 정확히 연결하는 단계**의 비중이 커진다.


---

# 23. Parallel DB Drift — 통합 Dev 환경의 첫 실제 경고

Claude/GPT 병렬 작업이 본격화되면서 live Supabase가 Git보다 먼저 변한 순간이 발생했다.

Readiness를 다시 측정했을 때 직전에는:

    terms         0
    classes       0
    enrollments   0

이던 값이 갑자기:

    terms           1
    classes        13
    enrollments   144

로 바뀌어 있었다.

추가 확인 결과 migration history에는:

    lead_audit_view
    current_term_setup
    fix_current_term_setup_runtime

가 live DB에 적용되어 있었지만, 동일 변경이 현재 Git migration tree에는 완전히 반영되지 않은 상태였다.

## 왜 중요한가

병렬 개발에서 가장 위험한 상태는 “두 모델이 다른 코드를 작성하는 것” 자체가 아니다.

더 위험한 것은:

    Git history != live database history

가 되는 순간이다.

이 상태가 길어지면 다음 개발자가 migration을 재현할 수 없고,
복구/재배포/새 환경 구축이 어려워진다.

## 대응

live 구조를 직접 읽고 다음을 version-controlled reconciliation migration으로 되돌려 기록했다.

- 2026-FALL academic term
- G1–G8, G10–G12 class shells
- G9-A / G9-B class shells
- G9을 제외한 144명 current enrollment
- lead-facing audit view

Reconciliation migration은 idempotent하게 작성해 live DB에 이미 존재하는 구조를 다시 적용해도 중복 생성되지 않도록 했다.

## 운영 원칙으로 승격

앞으로 병렬 AI 개발에서:

1. live DB 변경이 발견되면 migration history를 먼저 확인한다.
2. Git에 같은 구조가 없으면 drift로 간주한다.
3. 실데이터가 아닌 구조 변화는 반드시 reconciliation migration으로 Git에 복귀시킨다.
4. “현재 DB가 잘 된다”보다 “새 환경에서 동일 DB를 재현할 수 있다”를 완료 기준으로 본다.

이 사건은 Claude + GPT 병렬 개발이 단순 코드 분업을 넘어
실제 database change-management 규칙을 필요로 한다는 것을 보여줬다.

---

# 24. Core Readiness Dashboard — 통합 진행률을 숫자로 보기

Core identity가 만들어진 뒤부터 migration 진행상태를 감으로 판단하지 않기로 했다.

새 readiness projection은 학생마다 다음 상태를 계산한다.

    CORE_ONLY
    PARTIAL
    READY

READY 기준:

    canonical Core UUID
    + student_no
    + Auth link
    + current-term enrollment

2026-09-25 현 시점:

    Core total                 180
    Active students            175
    Daniel bridge              175
    Current enrollment         144
    Student number linked        0
    Auth linked                  0

G9 31명은 A/B 분반 근거가 필요해 의도적으로 current enrollment가 비어 있다.

Core 설정 화면은 이제 provisioning console뿐 아니라
통합 진행률을 보여주는 dashboard 역할도 한다.

향후 SP mapping이 진행되면:

    student_no  0 → 기존 SP cohort → 전교생
    Auth        0 → 로그인 보유 학생
    enrollment 144 → 175

처럼 migration이 숫자로 드러난다.

이 숫자는 향후 개발 보고서에서 “무엇을 완료했는가”를 설명하는 객관적 근거로 사용할 수 있다.

---

# 25. Study Planner Shadow Schema — 앱을 합치기 전에 옮겨갈 자리를 먼저 만든다

Study Planner는 현재 별도 Supabase 프로젝트에서 운영되고 있다.

기존 SP schema의 가장 중요한 특징은:

    students.id = auth.users.id

라는 점이다.

DICS Core에서는 이를 그대로 가져오지 않는다.

통합 목표:

    core.students.id
    = canonical student UUID

    core.students.auth_user_id
    = optional login identity

따라서 DICS Core 프로젝트 안에 비어 있는 study_planner schema를 먼저 만들었다.

## 설계 변화

기존 SP:

    public.students
    public.terms
    public.week_plans
    ...

Core target:

    core.students
    core.academic_terms

    study_planner.weeks
    study_planner.term_goals
    study_planner.week_plans
    study_planner.plan_items
    study_planner.item_records
    ...

즉 학생과 학기 master는 중복 생성하지 않는다.

Study Planner는 학습 domain 데이터만 소유한다.

## 왜 먼저 빈 schema를 만들었는가

실데이터 migration 전에 target schema가 있으면:

- FK 방향을 먼저 검증할 수 있고,
- 기존 SP table과 1:1 비교할 수 있고,
- migration order를 계획할 수 있고,
- live SP를 건드리지 않고도 통합 구조를 검증할 수 있다.

현재 target schema에는 실제 SP 학생/계획 데이터가 0건이다.

기존 SP production은 그대로 유지된다.

이 단계는:

    현재 앱을 바로 합친다

가 아니라:

    안전하게 옮길 목적지를 먼저 만든다

는 migration 전략이다.

---

# 26. 다음 Integration 단계

Study Planner migration은 다음 순서로 진행한다.

1. live SP table별 row count/schema drift 확인
2. SP 학생의 student_no/Auth와 Core 학생 mapping
3. mapping 검증
4. static/reference data 복사
5. terms를 Core academic_terms와 reconcile
6. goals/plans/items/records 순서로 데이터 복사
7. row count + FK + sample behavior 검증
8. SP frontend를 Core-backed API로 전환
9. 일정 기간 dual-check
10. legacy SP database를 archive/retire 여부 판단

중요한 원칙은 계속 동일하다.

실데이터를 Git에 넣지 않고,
mapping을 이름만으로 확정하지 않으며,
기존 운영 앱을 먼저 끄지 않는다.
