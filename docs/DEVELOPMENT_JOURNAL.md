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
20260925004655_fix_current_term_setup_runtime.sql
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

---

# 23. SP 29명 Identity Reconciliation — “전체 성공보다 검증 가능한 부분 성공”

Study Planner pilot에는 이미 29명의 학생에게 학번 형식 ID가 부여되어 있었다.

Core가 만들어진 뒤 이 값을 학교 공통 `student_no`로 보강하려고 했지만, 실데이터 migration에서 가장 먼저 한 일은 UPDATE가 아니었다.

```text
SP source
student_no + name + grade
          ↓
Daniel operational roster
name + grade + core_student_id
```

PIN은 이 reconciliation에서 완전히 제외했다.

## 첫 검증 결과

```text
source rows     29
exact matches   28
unmatched        1
ambiguous        0
```

29명을 한 번에 넣을 수도 있었다.

하지만 한 학생의 이름 표기가 두 시스템 사이에서 달랐다.

## 결정

```text
확정 28명 → 먼저 반영
불일치 1명 → pending
```

이 결정은 migration 완료율을 100%로 보이게 만드는 것보다 **잘못된 학생에게 identity를 붙이지 않는 것**을 우선한 것이다.

## 실제 반영

검증된 28명만 `core.students.student_no`에 반영했다.

그 결과:

```text
Core students              180
student_no assigned         28
student_no pending         152
```

기존 SP pilot 29명 중 1명은 별도 원본으로 이름을 확인할 때까지 보류한다.

## 의미

이 단계에서 student_no는 더 이상 SP 화면 안에서만 쓰는 값이 아니라, 실제로 DICS Core에 들어오기 시작했다.

하지만 기존 문서가 이 번호를 “임시로 매긴 값”이라고 설명하고 있었기 때문에, 전교생으로 확대할 때는 번호 발급정책 자체도 별도 결정으로 남겨야 한다.

> **기존 사용 중인 번호를 존중하되, 전교생 확장은 별도의 안정적인 school-wide numbering policy가 필요하다.**

---

# 24. 중요한 Architecture Correction — UUID가 같아 보여도 같은 Auth가 아니다

SP 통합 문서를 처음 만들 때는:

```text
existing SP auth.users.id
        ↓
core.students.auth_user_id
```

로 연결하면 된다고 표현했다.

그러나 실제 배포구조를 다시 대조하면서 중요한 문제가 드러났다.

SP와 Daniel/DICS Core는 **서로 다른 Supabase 프로젝트**다.

따라서:

```text
SP Project A
auth.users.id = UUID-A
```

와:

```text
Core Project B
auth.users.id = UUID-B
```

는 서로 다른 Auth namespace다.

문자열이 UUID라는 이유로 외부 프로젝트의 ID를 Core 프로젝트의 `auth.users(id)` FK에 넣을 수 없다.

## 수정된 전환 모델

Migration 기간:

```text
SP external auth UUID
        ↓
core.external_auth_identities
        ↓
core.students.id
```

최종 통합 후:

```text
DICS Core local auth.users.id
        ↓
core.students.auth_user_id
        ↓
core.students.id
```

즉:

- `core.students.id`는 프로젝트와 무관한 canonical student identity
- `core.students.auth_user_id`는 **Core 프로젝트의 local Auth 전용**
- 기존 외부 앱 Auth는 `core.external_auth_identities`로 migration provenance를 보존

한다.

## 왜 이 정정이 중요한가

이 문제를 놓치면 “UUID니까 그대로 연결하면 된다”는 착각으로 데이터베이스 FK와 인증 경계를 섞게 된다.

통합 시스템에서 identity는:

```text
사람의 identity
로그인 계정의 identity
외부 시스템의 identity
```

를 각각 분리해 다뤄야 한다.

이 발견은 DICS Core가 단순히 “여러 앱이 같은 학생번호를 쓰는 구조”가 아니라, **여러 시스템의 identity namespace를 조정하는 integration layer**가 되어야 한다는 점을 분명하게 만들었다.

---

# 25. Migration Drift Reconciliation — 운영 DB와 Git을 다시 일치시키다

병렬 개발이 진행되면서 새로운 유형의 문제가 나타났다.

운영 Supabase migration history에는:

```text
computer_lab_p0
study_planner_target_schema
external_auth_identity_bridge
...
```

가 실제 적용되어 있었지만, Daniel integration branch의 migration 디렉터리를 확인하니 일부 파일은 timestamp가 중복되어 있었고 `computer_lab_p0` 원본은 아예 보이지 않았다.

## 위험

운영 DB에는 구조가 존재하지만 Git에 source migration이 없으면:

- 새 환경 재현 불가
- disaster recovery 시 schema 재생성 불가
- 어떤 변경이 어느 repo에서 왔는지 추적 불가
- 이후 migration 순서 판단이 어려움

즉 **DB가 source of truth가 되고 Git이 뒤따라가는 drift**가 생긴다.

## 원본 탐색

GitHub 설치 repo 전체를 확인한 결과:

```text
shualoalumin/dics-device-manager
```

에서 정확한 원본:

```text
20260925005111_computer_lab_p0.sql
```

을 찾았다.

DB schema를 역추출해 비슷한 SQL을 새로 만드는 대신 **원본 migration을 그대로 Core integration history에 복원**했다.

## Timestamp 정리

병렬 작업 때문에:

```text
20260925000015_...
20260925000015_...
20260925000016_...
20260925000016_...
```

처럼 같은 migration version prefix가 중복되어 있었다.

운영 Supabase의 실제 applied migration timestamp를 기준으로 뒤쪽 파일명을 정렬했다.

결과적으로:

```text
20260925004004 lead_audit_view
20260925004257 current_term_setup
20260925004557 core_migration_readiness
20260925004655 fix_current_term_setup_runtime
20260925004934 parallel_db_reconciliation
20260925005111 computer_lab_p0
20260925005238 study_planner_target_schema
20260925005346 external_auth_identity_bridge
20260925005501 study_planner_fk_indexes
20260925005646 external_auth_identity_bridge_reconcile
20260925005951 split_core_external_auth_readiness_v3
```

처럼 실제 적용 순서가 파일명에서 읽히도록 정리했다.

## 교훈

> **병렬 개발에서는 코드 충돌만 볼 것이 아니라, database migration history의 충돌도 별도로 관리해야 한다.**

Claude/GPT/다른 프로젝트가 하나의 Core DB에 접근할수록 `live migration ↔ Git source` reconciliation은 정기적인 운영 항목이 되어야 한다.

---

# 26. DICS Core가 실제 Multi-domain DB가 된 시점

2026-09-25 후반 readiness를 다시 측정했다.

```text
Core students                 180
active students               175
student_no assigned            28

current term                    1
current classes                13
current enrollments           144
G9 section pending             31

Study Planner target tables    13
Computer Lab tables             8

external auth linked            0
local Core auth linked          0
department definitions          0
```

이 숫자의 의미는 중요하다.

처음에는 Daniel's Scale 안에 Core table을 만든 수준이었지만, 이제 같은 DB에:

```text
core.*
discipline.*
study_planner.*
computer_lab.*
```

가 실제 schema로 존재한다.

아직 Study Planner의 live 데이터와 Computer Lab 운영 데이터 전체가 완전히 cut-over된 것은 아니다.

하지만 architecture 관점에서는:

> **DICS Core가 더 이상 미래 계획이 아니라 여러 domain이 실제로 공존하는 중앙 데이터 플랫폼의 형태를 갖추기 시작했다.**

다음 단계의 핵심은 schema 생성이 아니라 **identity와 운영 데이터를 정확히 연결하는 것**이다.


---

# 27. 학생뿐 아니라 교사 Auth도 외부 namespace였다

Study Planner target schema를 처음 만들 때 학생 identity는 Core UUID로 분리했지만,
교사 profile은 기존 SP schema의 습관을 따라 Auth UUID를 PK로 둘 수 있었다.

그러나 같은 원칙을 다시 적용하면 교사도 예외가 아니다.

현재 SP의 교사 Auth UUID 역시:

    legacy SP Supabase project

에 속한다.

따라서 Core project의 auth.users FK로 직접 사용할 수 없다.

## 수정된 staff target

    study_planner.staff.id
    = domain staff profile UUID

    study_planner.staff.auth_user_id
    = optional DICS Core LOCAL Auth UUID

    study_planner.external_staff_identities
    = legacy/external staff Auth bridge

학생 identity에서 발견한 namespace 문제를 교사 identity까지 일반화한 것이다.

중요한 점은 실제 SP staff/comment data가 아직 target에 들어오기 전 구조를 수정했다는 점이다.

이미 데이터가 들어간 뒤 PK semantics를 바꾸는 것보다,
shadow target 단계에서 오류를 발견하는 편이 훨씬 안전했다.

---

# 28. Security Advisor가 “논리적으로 막혀 있음”과 “노출 자체가 없음”의 차이를 보여주다

Core provisioning과 외부 identity 연결 RPC는 모두 함수 내부에서:

    private.current_admin_is_lead()

를 검사하도록 작성돼 있었다.

따라서 anonymous 사용자가 실제 작업을 성공시키기는 어려웠다.

하지만 Supabase Security Advisor는 별도의 문제를 지적했다.

    SECURITY DEFINER function
    + default PUBLIC EXECUTE

조합 때문에 anonymous role이 RPC endpoint를 호출할 수 있는 상태였다.

## 판단

“호출하면 내부 권한검사에서 실패한다”와
“호출권한 자체가 없다”는 동일한 보안 수준이 아니다.

따라서 Core admin 계열 함수에 대해:

    REVOKE EXECUTE FROM PUBLIC
    REVOKE EXECUTE FROM anon
    GRANT EXECUTE TO authenticated

를 명시했다.

대상:

- current academic term 초기화
- G9-A/B 배정
- external Auth identity 연결

재검사 결과 이 세 함수의 anon 경고는 사라졌다.

남은 anonymous SECURITY DEFINER 경고는 Computer Lab의 dics_device_rpc 하나였는데,
이 함수는 server-key/session 기반 별도 domain 설계이므로
Daniel/Core lane에서 임의 변경하지 않았다.

## 교훈

보안 경계는:

    UI에서 버튼을 숨김
    < 함수 내부 role check
    < DB privilege + 함수 role check

순으로 더 명확해진다.

Advisor는 “코드가 논리적으로 안전해 보이는가”가 아니라
실제 DB privilege surface를 별도로 검증하는 역할을 했다.

---

# 29. 28/29 student_no reconciliation 이후 — Auth는 따로 이동한다

SP pilot 29명 가운데 검증된 28명의 student_no가 Core에 들어간 뒤 readiness는:

    active Core students        175
    student_no linked            28
    current enrollment          144
    Core-local Auth linked        0
    external Auth linked          0

가 되었다.

이 수치가 중요한 이유는 student_no와 Auth migration을 하나의 작업으로 뭉개지 않았기 때문이다.

    human identifier
    ≠ external login identity
    ≠ Core-local login identity

를 별도 단계로 다룬다.

따라서 Core readiness 화면도 Auth를:

    Core Auth
    External Auth

두 축으로 분리했다.

기존 SP Auth가 연결되어도 Core-local Auth count는 0으로 남을 수 있고,
그 상태 자체가 migration reality를 정확하게 표현한다.

---

# 30. Cross-project identity migration을 수작업 복사에서 repeatable tooling으로 전환

외부 SP Auth identity를 Core로 가져오려면 실제로는 다음 민감한 관계를 다뤄야 한다.

    SP auth UUID
    ↔ student_no
    ↔ Core student UUID

이 값을 GitHub Issue나 PR comment로 옮기는 방식은 사용하지 않기로 했다.

대신 두 Supabase 프로젝트에 직접 연결하는 one-time migration runner를 작성했다.

    scripts/migrate-sp-external-identities.mjs

## 기본 동작

명시적인 --apply가 없으면 무조건 DRY RUN이다.

읽는 필드도 최소화했다.

SP:

    id
    student_no
    core_student_id

Core:

    id
    student_no

이름, 이메일, PIN, DOB는 읽지 않는다.

출력도 실제 identity 값을 보여주지 않고 aggregate count만 표시한다.

## 자동 hard-stop

다음 중 하나라도 있으면 write 전에 중단한다.

- source student_no duplicate
- Core student_no duplicate
- SP core_student_id가 기대 Core 학생과 충돌
- 한 external Auth가 다른 Core 학생에 이미 연결
- 한 Core 학생이 같은 source의 다른 external Auth와 이미 연결

## distributed transaction 문제

SP와 Core는 서로 다른 database이므로 하나의 SQL transaction으로 묶을 수 없다.

이 현실을 숨기지 않고 두 write를 **idempotent**하게 설계했다.

중간에 실패해 한쪽만 반영되더라도:

    rerun
    → already-correct mapping 확인
    → 빠진 쪽만 완성

할 수 있다.

CI에도:

    node --check scripts/migrate-sp-external-identities.mjs

를 추가해 migration tooling 자체도 PR 검증 대상이 되었다.

---

# 31. Study Planner migration 검증도 content가 아니라 count부터

Study Planner target schema에는 실제 운영 학습데이터가 아직 0건이다.

실제 copy가 시작되기 전에 lead-only aggregate inventory RPC를 추가했다.

    get_study_planner_target_inventory()

이 함수는 다음 row count만 반환한다.

- staff
- external staff identities
- weeks
- reference tables
- goals
- plans
- items
- execution records
- comments

학생의 계획 내용이나 교사 코멘트 본문은 노출하지 않는다.

이는 migration 검증의 우선순위를 보여준다.

    먼저 count / FK / unique constraint parity
    그 다음 제한된 sample behavior
    마지막에 frontend cut-over

즉 “데이터를 복사했다”가 완료가 아니라
**source와 target이 설명 가능한 방식으로 일치한다**가 완료 기준이다.

---

# 32. 2026-09-25 Integration Checkpoint

현재 DICS Core는 다음 상태에 도달했다.

    canonical Core students       180
    active students               175
    verified student_no            28

    current academic term           1
    classes                         13
    current enrollments            144
    G9 A/B pending                  31

    Core-local student Auth          0
    external student Auth            0

    Study Planner target tables     13+
    Study Planner live copied rows   0

    Computer Lab schema          present
    Discipline domain           active

즉 플랫폼은 이제:

    schema integration

단계를 상당 부분 지나:

    identity enrichment
    → verified data migration
    → domain cut-over

단계로 이동하고 있다.

다음 중요한 evidence point는 SP live bridge migration을 적용한 뒤
29명 중 몇 명이 실제 source↔Core 양쪽 bridge를 완성하는지다.


---

# 33. Department Merit 운영화 — Excel 의존에서 운영 DB 관리로

부서활동 자동 상점 엔진은 이미 존재했지만 실제 운영 데이터는 0건이었다.

초기 요구는 부서활동 Excel을 기반으로 매주 월요일 상점을 자동 부여하는 것이었다.
하지만 장기 운영을 생각하면 Excel 파일을 매번 개발자가 읽어 DB seed로 옮기는 구조는 적절하지 않았다.

## 문제

파일 중심 운영은 다음 위험을 가진다.

- 부서원 변경 때마다 개발 작업 필요
- 실제 명단을 Git에 잘못 올릴 위험
- 어느 날짜부터 학생이 소속됐는지 이력 관리 어려움
- 상점 점수 변경 시 과거 규칙과 현재 규칙의 경계가 불명확

## 결정

부서/소속/주간 상점 규칙 자체를 운영 DB에서 관리한다.

선도부장은 사이트에서:

    부서 생성
    → 주간 상점 규칙 지정
    → 학생 소속 추가/종료
    → 이번 주 자동상점 반영

을 직접 수행한다.

실제 학생 소속 row는 Supabase에만 존재하고 Git에는 들어가지 않는다.

## 데이터 모델 원칙

소속은 삭제하지 않는다.

    starts_on
    ends_on

으로 이력을 보존한다.

규칙 변경도 overwrite보다 versioning을 우선한다.

    기존 rule
       effective_to 종료

    새 rule
       effective_from 시작

따라서 나중에 특정 주에 왜 몇 점이 부여됐는지 설명할 수 있다.

## 권한

읽기:

    SEONDO

쓰기:

    lead only

SASAENG에는 부서 명단/상점 규칙 접근이 필요하지 않으므로 RLS를 좁혔다.

## 실제 운영 안전성

기능을 production DB에 적용한 직후 확인:

    departments              0
    memberships              0
    merit rules              0
    generated weekly records 0

즉 기능은 live지만 실제 학생 데이터나 점수는 자동 생성되지 않았다.

운영자가 검증된 명단을 입력하는 순간부터만 데이터가 생긴다.

---

# 34. UI 자동 치환 오류를 merge 전에 잡은 사례

부서 상점 페이지에 “이번 주 반영” 상태를 넣는 과정에서
범용 문자열 치환이 예상보다 넓은 첫 번째 matching block을 잡았다.

결과적으로 해당 UI 조각이 잠시 벌점 입력 페이지에 삽입됐다.

이 변경은 branch에만 있었고 production data에는 영향이 없었다.

즉시 source를 다시 읽어 실제 삽입 위치를 확인했고:

    잘못된 block 제거
    → Department Merit page의 명시적 PageHeader anchor 사용
    → 재삽입
    → CI 재실행

으로 수정했다.

GitHub Actions 결과:

    erroneous commit   FAIL
    corrected commit   SUCCESS

## 교훈

대형 단일 파일을 문자열 기반으로 수정할 때는:

1. write 이후 source 위치 검증
2. typecheck/build
3. branch CI

세 단계 모두 필요하다.

특히 AI 병렬개발에서는 “도구 호출 성공”을 “기능 위치까지 정확함”으로 간주하지 않는다.

---

# 35. Department Merit — 현재 완료선

현재 부서 자동 상점 흐름은 다음까지 준비됐다.

    lead가 부서 생성
    → 주간 점수/기록명 지정
    → 학생 소속 추가
    → 필요 시 이번 주 반영
    → ensure_weekly_department_merits()
    → deterministic source_key
    → 중복 생성 방지

자동반영 상태는 화면에서:

    generated / expected

숫자로 확인할 수 있다.

실제 부서활동 명단과 점수는 아직 의도적으로 입력하지 않았다.

다음 운영 단계는 실제 담당자가 명단을 검증한 뒤 UI에서 직접 등록하는 것이다.


---

# 36. Shared account에서 Personal accountability로

Daniel's Scale는 초기에 역할 기반 shared account 두 개로 운영되었다.

이 구조는 빠른 MVP 운영에는 충분했지만,
created_by / updated_by와 audit log가 실제로 들어오기 시작하면서
“누가 했는가”의 의미가 달라졌다.

공유계정 상태에서는:

    auth.uid()
    = 한 사람의 identity가 아니라 여러 사람이 공유하는 role identity

이므로 audit trail이 완전한 개인 책임성을 제공하지 못한다.

## 결정

기존 shared account를 즉시 삭제하지 않고 개인계정을 병행한다.

이유:

- 현재 학교 운영을 끊지 않는다.
- 개인계정 provisioning 오류가 있어도 fallback이 남는다.
- 실제 담당범위 권한을 하나씩 검증할 수 있다.
- audit actor가 개인 이름으로 남는지 운영 중 확인할 수 있다.

개인계정이 안정화된 뒤에만 shared account를 inactive 처리한다.

---

# 37. Auth Admin API를 브라우저에서 분리

개인계정을 만들려면 Supabase Auth user를 생성해야 한다.

공식 Auth Admin API는 service credential을 필요로 하며,
이 key는 browser에 노출하면 안 된다.

따라서:

    browser
      ↓ authenticated JWT
    provision-admin-account Edge Function
      ↓ service credential
    Supabase Auth Admin API
      ↓
    auth.users
      ↓ caller JWT
    register_admin_profile()
      ↓
    public.admins

구조를 만들었다.

Edge Function은 user 생성 전에 caller가 실제 활성 SEONDO lead인지 확인한다.

Auth user 생성 후 profile 등록이 실패하면:

    auth.admin.deleteUser()

로 보상 cleanup을 수행해 orphan Auth account를 남기지 않는다.

## Temporary credential

새 계정의 temporary password는 server에서 cryptographic random 값으로 생성한다.

이 값은:

- Git에 저장하지 않음
- admins table에 저장하지 않음
- 한 번만 UI에 반환
- 사용자가 첫 로그인하면 즉시 변경

하는 방향으로 설계했다.

현재 운영 DB의 실제 admin profile 수는 그대로 2개이며,
개인 실직원 계정은 아직 생성하지 않았다.

---

# 38. “비밀번호 바꿨음” flag 자체도 신뢰하면 안 됐다

첫 설계는:

    browser에서 Auth password 변경
    → mark_admin_password_changed() RPC

순서였다.

기능적으로는 동작하지만 문제를 발견했다.

RPC 자체를 authenticated user가 직접 호출할 수 있다면
실제 password 변경 없이:

    must_change_password = false

만 만들 수 있다.

이건 UI가 올바른 순서로 호출한다는 가정에 의존한다.

## 수정

client-side completion RPC를 제거했다.

대신:

    change-admin-password Edge Function

을 만들었다.

이 함수가:

1. JWT session 검증
2. 활성 admin profile 확인
3. password complexity 확인
4. 실제 Supabase Auth password update
5. 성공 후에만 must_change_password 해제

를 수행한다.

따라서 완료상태는 UI event가 아니라 실제 Auth mutation 결과에 연결된다.

---

# 39. 첫 로그인 강제 흐름

신규 개인계정은:

    must_change_password = true

로 시작한다.

ProtectedRoutes는 이 flag가 true인 동안 일반 운영화면을 렌더하지 않는다.

사용자는 바로 password change screen으로 이동한다.

비밀번호 조건:

    12자 이상
    uppercase
    lowercase
    number
    special character

변경이 성공하면 admin profile을 reload하고 정상 dashboard로 진입한다.

비활성 admin account 역시 별도 차단화면에서 운영화면 접근을 막는다.

---

# 40. 관리자 권한 self-protection

개인계정 관리 화면은 lead-only다.

설계 보호장치:

- SASAENG는 SEONDO lead가 될 수 없음
- lead account는 discipline scope가 항상 ALL
- 마지막 활성 SEONDO lead는 해제/비활성화할 수 없음
- login_id는 account 생성 후 UI에서 변경하지 않음
- 계정 비활성화 후에도 과거 audit/provenance는 보존

이 구조의 목적은 편의보다 “운영자 스스로 전체 admin access를 실수로 제거하지 못하게 하는 것”이다.

---

# 41. Personal Admin checkpoint

현재 상태:

    admin profiles                   2
    active admins                    2
    active leads                     1
    must-change-password accounts    0
    newly provisioned real accounts  0

Edge Functions:

    provision-admin-account     ACTIVE / JWT required
    change-admin-password       ACTIVE / JWT required

Frontend:

    관리자 계정 console
    temporary credential one-time display
    first-login password enforcement
    inactive account lockout

CI:

    personal-admin final branch state
    typecheck/build SUCCESS

다음 실제 운영 action은 코드를 더 만드는 것이 아니라
검증된 담당자부터 개인계정을 순차 provision하는 것이다.


---

# 42. Discipline Record도 Core UUID를 직접 갖기 시작

학생 master는 이미 Core UUID로 통합됐지만,
생활지도 원본 record는 여전히:

    point_records.student_id
    punishments.student_id

정수형 legacy 학생 ID를 FK로 사용하고 있었다.

Dashboard와 report에서는 bridge view를 통해 Core UUID를 보여줄 수 있었지만,
원본 record 자체가 canonical identity를 직접 갖지 않는다는 차이가 남아 있었다.

## 왜 바로 FK를 교체하지 않았는가

기존 frontend, reflection trigger, weekly/settlement 계산, reports가
legacy integer ID를 기반으로 이미 운영되고 있었다.

한 번에:

    integer FK 제거
    → UUID FK 교체
    → 모든 query/RPC/view 수정

을 하면 rollback surface가 너무 커진다.

따라서 dual-key transition을 선택했다.

    legacy student_id
    + core_student_id

두 값을 일정 기간 함께 저장한다.

## Backfill

운영 DB 당시:

    point_records       1
    reflection_records  1
    punishments         0

기존 point record 1건의 Core UUID를 legacy student bridge에서 backfill했다.

검증:

    point_records total        1
    Core linked                1
    mismatch                   0

    punishments total          0
    mismatch                   0

---

# 43. Dual-key는 “두 개를 믿는 구조”가 아니다

두 ID를 함께 저장하면 오히려 불일치 가능성이 생길 수 있다.

따라서:

    private.sync_discipline_core_student_id()

trigger를 만들었다.

규칙:

1. legacy student_id에서 canonical UUID를 조회
2. core_student_id가 비어 있으면 자동 채움
3. core_student_id가 이미 있는데 다른 학생을 가리키면 insert/update 거부

즉 transition 동안에도 source of truth는:

    core.students.id

이고 legacy integer는 호환용 locator다.

Rollback insert test에서:

    core_uuid_auto_filled = true

를 확인했다.

테스트 record는 transaction rollback으로 운영 데이터에 남지 않았다.

---

# 44. Write Path가 먼저 Canonical UUID로 이동

dual-key 저장이 안정화된 뒤,
새 write entrypoint를 추가했다.

    create_point_record_core(core_student_uuid, ...)
    create_punishment_core(core_student_uuid, ...)

이 함수들은 business rule을 복제하지 않는다.

    Core UUID
      ↓ legacy bridge lookup
    existing create_point_record / create_punishment
      ↓
    기존 validation 한 곳 유지

이렇게 기존 규정 검증은 그대로 유지하면서
frontend가 더 이상 legacy integer를 새로운 write identity로 사용할 필요가 없게 했다.

## 실제 authenticated rollback test

활성 SEONDO Auth context를 transaction 안에서 설정하고:

    create_point_record_core(...)

를 호출했다.

결과:

    created              true
    core_matches_legacy  true
    core_uuid_present    true

이후 rollback.

운영 record count는 변하지 않았다.

---

# 45. Frontend write cut-over

API type을 먼저 Core UUID로 변경하자 CI가 실패했다.

    PointRecordInput.studentId
    PunishmentInput.studentId

가 제거됐는데 App.tsx가 아직 legacy integer를 보내고 있었기 때문이다.

CI error:

    Object literal may only specify known properties
    'studentId' does not exist ...

이 실패는 의도한 compile-time migration gate 역할을 했다.

App call-site를 다음처럼 수정했다.

    selectedStudent.coreStudentId
      ↓
    create_point_record_core

    selectedStudent.coreStudentId
      ↓
    create_punishment_core

Core UUID가 없는 학생은 submit 자체를 막고 오류를 표시한다.

수정 후:

    typecheck SUCCESS
    build SUCCESS

따라서 2026-09-25 기준 새 생활지도 기록 생성 경로는
이미 canonical Core UUID를 입력 identity로 사용한다.

legacy integer ID는 아직 read/route compatibility를 위해 남아 있다.


---

# 42. Discipline 기록 자체를 Core Identity에 연결

통합 초기에는 화면의 학생 목록만 Core student와 bridge되어 있었다.

즉 UI에서는:

    core_student_id

를 볼 수 있었지만 실제 생활지도 원본 기록은 여전히:

    public.students.id (integer)

만 저장했다.

통합 플랫폼 관점에서는 이것이 마지막 legacy boundary 중 하나였다.

## Dual-key 적용

다음 컬럼을 추가했다.

    point_records.core_student_id
    punishments.core_student_id

기존 기록은 legacy student bridge를 사용해 backfill했다.

적용 직후 production 상태:

    point_records total       1
    Core linked               1
    mismatch                  0

    punishments total         0
    Core linked               0
    mismatch                  0

즉 기존 운영기록 손실 없이 canonical UUID가 병행 저장됐다.

---

# 43. DB가 두 Identity의 일치를 강제한다

단순히 Core UUID 컬럼을 추가하는 것만으로는 충분하지 않다.

legacy student_id와 core_student_id가 서로 다른 학생을 가리키면
조용한 data corruption이 된다.

따라서 trigger:

    private.sync_discipline_core_student_id()

를 추가했다.

insert/update 시:

1. legacy student row에서 canonical Core UUID 조회
2. core_student_id가 비어 있으면 자동 채움
3. 값이 이미 있으면 legacy mapping과 비교
4. 다르면 exception

즉 migration 기간 동안:

    old ID
    new ID

가 동시에 존재하지만 의미상 반드시 같은 학생이다.

---

# 44. 새 write path는 Core UUID가 출발점

Dual-key 적용 후 다음 단계는 frontend가 계속 integer student_id를 보내지 않게 하는 것이었다.

새 RPC:

    create_point_record_core(core_student_id, ...)
    create_punishment_core(core_student_id, ...)

를 추가했다.

이 wrapper는 Core UUID를 받아 transition 기간에만 legacy integer ID를 해석한 뒤,
기존 business-rule RPC를 호출한다.

중요한 이유:

- 기존 벌점/상점/반성문 rule을 복제하지 않는다.
- canonical UUID가 새 write request의 source identity가 된다.
- legacy integer는 내부 compatibility detail로 내려간다.

Frontend의 새 점수/처분 생성도 이 Core UUID RPC로 전환했다.

학생 상세 route 같은 read compatibility는 아직 integer ID를 유지한다.

---

# 45. Rollback 기반 live verification

production DB에 migration을 적용한 뒤 실제 record를 남기지 않는 rollback test를 실행했다.

인증된 SEONDO context를 임시 설정하고:

    create_point_record_core(...)

호출 후 확인:

    record created           true
    Core UUID present        true
    Core ↔ legacy match      true

그 뒤 transaction을 rollback했다.

따라서 test evidence는 얻되
실제 학생 상벌점에는 테스트 record가 남지 않았다.

Frontend 전환 후 GitHub Actions:

    typecheck SUCCESS
    build SUCCESS

현재 새 discipline write는 canonical Core UUID를 기준으로 출발한다.

---

# 46. 아직 legacy integer FK를 제거하지 않는 이유

현재 point/punishment 원본 record는 Core UUID를 모두 갖지만,
다음 영역은 아직 legacy integer를 사용한다.

- student detail route
- 일부 기존 views / aggregation
- 기존 RPC 내부 signature
- historical compatibility

따라서 지금 바로 integer student_id를 drop하지 않는다.

최종 cut-over 조건은:

    모든 기존 record Core UUID linked
    mismatch = 0
    신규 write Core UUID only
    주요 read path Core UUID 기반
    rollback / report 결과 동일

을 모두 충족한 뒤다.


---

# 47. Read Path도 Core UUID로 이동

write path가 canonical UUID로 바뀐 뒤에도 학생 상세 route와 점수 history filtering은:

    student_id integer

를 사용하고 있었다.

즉 새 데이터 생성 identity는 Core였지만,
조회 contract의 중심은 아직 legacy ID였다.

## 전략

URL 모양 자체는 유지했다.

    /students/:id

다만 새 링크가 넣는 `:id`의 의미를:

    legacy integer
    ↓
    Core UUID

로 바꿨다.

과거 숫자 URL은 즉시 깨지지 않도록 fallback resolver를 유지했다.

    숫자면 legacy lookup
    UUID면 canonical lookup

따라서 새 traffic은 Core UUID로 이동하면서
기존 bookmark/링크는 transition 기간 동안 계속 작동한다.

반성문 view에도 core_student_id를 append하여
reflection → student detail 링크도 Core UUID를 사용하게 했다.

---

# 48. 계산식은 바로 갈아끼우지 않고 Shadow Parity부터

weekly / settlement 계산은 출력에 Core UUID가 보이더라도
실제 GROUP BY / JOIN은 integer student_id 기반이었다.

이 계산식을 바로 교체하지 않았다.

먼저:

    v_weekly_scores_core_shadow
    v_weekly_penalties_core_shadow
    v_settlement_scores_core_shadow

를 만들었다.

기존 계산과 Core 계산을 동시에 실행하고:

    v_discipline_core_calc_parity

에서 aggregate 비교했다.

첫 production 결과:

    weekly
    1 legacy / 1 Core / mismatch 0

    weekly penalties
    1 legacy / 1 Core / mismatch 0

    settlement
    0 legacy / 0 Core / mismatch 0

mismatch=0을 확인한 뒤에만
public contract 이름인:

    v_weekly_scores
    v_weekly_penalties
    v_settlement_scores

가 Core 계산을 source로 사용하도록 promotion했다.

---

# 49. Dashboard 중심 View도 175/175 Parity 확인

가장 위험한 부분은 student summary였다.

이 view는 단순 점수 합계가 아니라:

- lifetime 상·벌점
- 주간 NET
- 체력훈련 대상
- 정산기간 NET
- 징계위원회 대상
- 반성문 미제출/2배
- 기숙사 처분
- 귀가금지 조건

을 모두 조합한다.

따라서:

    v_student_summary_core_shadow

를 별도로 만들고 기존 summary와 비교했다.

production result:

    legacy rows 175
    Core rows   175
    mismatch      0

그 뒤 기존 구현을 frozen shadow로 보존하고
`v_student_summary`를 Core UUID 기반 구현으로 promotion했다.

promotion 전후:

    summary rows        175 → 175
    weekly report rows  175 → 175

Dashboard counts:

    students            175 → 175
    weekly targets        0 → 0
    missing reflections   0 → 0
    double reflections    0 → 0
    active punishments    0 → 0
    committee targets     0 → 0

즉 public contract는 그대로인데 내부 identity만 Core로 이동했다.

---

# 50. 문자열 검색이 아니라 PostgreSQL Dependency Graph

legacy integer column을 drop하기 전
처음에는 function/view definition 문자열에서 `student_id`를 검색했다.

하지만 이 방식은:

    core_student_id

안의 문자열까지 잡아 false positive를 만들었다.

최종 판단에는:

    pg_depend

를 사용했다.

실제 physical column dependency는:

point_records.student_id:

    v_discipline_core_fk_readiness
    v_settlement_scores_legacy_shadow
    v_student_summary_legacy_shadow
    v_weekly_penalties_legacy_shadow
    v_weekly_scores_legacy_shadow

punishments.student_id:

    v_discipline_core_fk_readiness
    v_student_summary_legacy_shadow

뿐이었다.

이 확인을 통해 “어떤 객체를 먼저 끊어야 column drop이 안전한가”가 명확해졌다.

---

# 51. Trigger가 마지막 숨은 Legacy Dependency였다

View와 RPC를 거의 전부 Core UUID로 옮긴 뒤
trigger를 별도로 조사했다.

그 과정에서:

    private.create_reflection_for_penalty()

가 여전히:

    new.student_id

로 학생 학년을 찾고 있음을 발견했다.

만약 이 상태에서 integer column을 삭제했다면
새 벌점 입력 시 반성문 자동생성이 깨졌을 것이다.

따라서 trigger를:

    new.core_student_id
      ↓
    public.students.core_student_id
      ↓
    grade lookup

으로 변경했다.

이 사례는 schema dependency와 runtime trigger dependency를
별도로 점검해야 한다는 중요한 근거가 되었다.

---

# 52. Destructive Cut-over 직전 Evidence를 남기다

최종 drop 직전 production preflight:

    point_records          1 / 1 Core linked
    point mismatch         0

    punishments            0 / 0 Core linked
    punishment mismatch    0

    weekly                 1 / 1, mismatch 0
    weekly penalties       1 / 1, mismatch 0
    settlement             0 / 0, mismatch 0

    student summary        175 / 175, mismatch 0

를 확인했다.

이 값을:

    discipline.core_cutover_evidence

에 aggregate-only row로 저장했다.

실제 학생 이름·학번·Auth UUID·mapping row는 저장하지 않았다.

이 evidence가 존재한 뒤에만 destructive migration을 실행했다.

---

# 53. Physical Integer FK 제거 완료

최종 migration에서:

    point_records.student_id
    punishments.student_id

를 실제로 drop했다.

현재 physical student identity:

    point_records.core_student_id UUID NOT NULL
    punishments.core_student_id   UUID NOT NULL

두 테이블 모두 canonical Core UUID만 저장한다.

legacy API compatibility는:

    core_student_id
      ↓
    public.students bridge
      ↓
    derived student_id

방식으로 view에서 계산한다.

즉:

    저장 identity = Core UUID 하나
    표시 compatibility = 필요할 때만 legacy integer 계산

구조가 되었다.

## Post-cutover verification

기존 운영 데이터:

    point record       1
    point sum          5
    reflection         1
    punishment         0
    weekly report    175

모두 유지됐다.

Dashboard counts도 동일했다.

### Core + legacy wrapper rollback test

column 삭제 후 다시 테스트했다.

점수:

    core path           Core match true
    legacy wrapper      Core match true
    reflection created  true / true

처분:

    core path           Core match true
    legacy wrapper      Core match true

모든 테스트 transaction은 rollback하여
운영 상벌점에는 테스트 row가 남지 않았다.

최종 status:

    stage = POST_LEGACY_COLUMN_DROP_VERIFIED
    legacy_columns_removed = true
    cutover_completed = true

---

# 54. Business Rule의 방향도 뒤집다

초기 transition에서는:

    create_point_record_core(UUID)
      ↓
    create_point_record(integer)

처럼 Core RPC가 legacy 함수의 wrapper였다.

최종 cut-over 전 이 방향을 뒤집었다.

현재:

    create_point_record_core(UUID)
    = authoritative implementation

    create_point_record(integer)
    = compatibility wrapper

처분도 동일하다.

    create_punishment_core(UUID)
    = authoritative implementation

    create_punishment(integer)
    = compatibility wrapper

부서 자동상점도 point_records insert 시
Core UUID만 물리적으로 저장한다.

따라서 앞으로 legacy wrapper를 제거해도
business rule 본체에는 영향이 없다.

---

# 55. Migration Ledger까지 Production과 맞추다

Core cut-over를 마치고 migration history를 비교하던 중
Git에서 미리 만든 filename timestamp와
Supabase live history version이 다른 구간을 발견했다.

예:

    Git draft timestamp
    ≠ live applied version

이 상태는 지금 DB가 동작하더라도
향후 CLI가 migration을 재적용하려 할 수 있다.

따라서 recent 15개 migration을:

    migration name
    + live version

기준으로 다시 대조했다.

결과:

    15 / 15 Git filename = live Supabase version

으로 reconciliation했다.

추가 admin RLS optimization migration도
live version:

    20260926172018

로 Git filename을 맞췄다.

이 과정에서 migration 내용은 바꾸지 않고
기존 blob SHA를 재사용해 path만 이동한 경우도 있었다.

---

# 56. Advisor Cleanup — 의미 있는 Warning만 고친다

Supabase performance advisor에서:

    admins_read_self_or_lead

policy가 auth.uid()를 row마다 다시 평가할 수 있다는 warning이 있었다.

정책을:

    user_id = (select auth.uid())
    or (select private.current_admin_is_lead())

형태로 바꿨다.

재검사 결과:

    auth_rls_initplan warning
    → 0

남은 performance finding은 현재 모두:

    unused_index INFO

다.

아직 데이터량과 query history가 작은 단계이므로
“unused”라는 이유만으로 index를 삭제하지 않았다.

security advisor의 남은 주요 warning은
Computer Lab의 intentional RPC surface와
Auth leaked-password protection 설정 등
다른 lane / platform setting 영역으로 분리해 유지한다.


---

# 57. Production Migration History 전체를 다시 맞추다

Core cut-over 직후 최근 migration만 Git ↔ Supabase version을 맞췄지만,
전수 비교를 하자 초기/중기 구간에도 timestamp drift가 남아 있었다.

첫 비교:

    Git SQL files     48
    live migrations  52

version 기준:

    missing from Git  20
    extra in Git      16

이 숫자만 보면 큰 drift처럼 보이지만,
name/content를 대조하자 대부분은:

    같은 structural migration
    + 다른 draft timestamp

였다.

예:

    Git draft
    20260925000007_settlement_and_net_scoring.sql

    production ledger
    20260924192707_settlement_and_net_scoring

따라서 SQL blob 자체는 바꾸지 않고
live version/name으로 path만 rename했다.

초기:

    schema
    logic
    rls
    function search_path

Core foundation:

    dics_core_student_bootstrap
    settlement_and_net_scoring
    reflection_due_times
    core_aware_student_summary_v2
    core_hardening

운영 확장:

    notice/report
    department merit
    responsibility scopes
    auth provenance
    department merit admin/security

까지 production ledger에 맞췄다.

재검사 결과:

    Git structural SQL 48
    live migrations    52

차이는 정확히 4개만 남았다.

---

# 58. 남은 4개는 “누락”이 아니라 LIVE_ONLY_DATA였다

남은 live migration 네 개는 구조 migration이 아니었다.

성격:

- historical demo/seed data
- environment-specific Auth/admin binding
- private student roster import
- private roster correction

즉 SQL을 Git에 복구하는 것이 오히려 잘못된 방향이었다.

여기서 migration governance에 새 구분을 도입했다.

    TRACKED
    LIVE_ONLY_DATA

TRACKED:

    구조를 재현하는 SQL
    → exact live version/name으로 Git에 존재

LIVE_ONLY_DATA:

    운영환경 데이터 변경
    → production history에는 존재
    → public Git SQL은 의도적으로 없음

현재 checkpoint:

    production migrations 52
    TRACKED structural    48
    LIVE_ONLY_DATA         4
    extra Git migrations   0

---

# 59. Migration 이름 자체도 PII가 될 수 있었다

migration ledger를 처음 생성할 때
live history의 version/name을 그대로 snapshot하려 했다.

그 과정에서 private roster correction migration은
**migration name 자체가 실제 학생 식별정보를 포함할 수 있음**을 발견했다.

SQL을 Git에 넣지 않는 것만으로는 충분하지 않았다.

즉:

    migration SQL = private
    migration name = always safe

라는 가정도 틀릴 수 있었다.

즉시 ledger entry를:

    name_redacted = true
    private_label = private_roster_correction

형태로 수정했다.

실제 live migration name은 Git ledger에서 제거했다.

이 경험으로 LIVE_ONLY_DATA contract에:

> sensitive live migration name itself may be redacted

규칙을 추가했다.

---

# 60. Migration Ledger를 CI Contract로 만들다

새 파일:

    supabase/migration-ledger.json

새 checker:

    scripts/check-migration-ledger.mjs

새 명령:

    npm run check:migration-ledger

CI가 강제하는 규칙:

TRACKED:

    version 14자리
    unique version
    exact version_name.sql
    실제 Git file 존재

LIVE_ONLY_DATA:

    rationale 필수
    해당 version SQL이 Git에 있으면 실패
    redacted entry에는 실제 name이 있으면 실패

그리고:

    Git의 모든 migration SQL
    → 반드시 TRACKED ledger entry가 있어야 함

따라서 앞으로는:

    migration file만 추가
    ledger 안 고침
    → CI FAIL

    private-data migration SQL commit
    → CI FAIL

    live timestamp와 Git filename mismatch
    → CI FAIL

로 전환됐다.

첫 GitHub Actions 실행:

    migration ledger check SUCCESS
    typecheck SUCCESS
    build SUCCESS

이 시점부터 migration governance가 문서 규칙이 아니라
실제 merge gate가 되었다.


---

# 61. G9 A/B 배정도 Core UUID로 전환

discipline 원본 record의 integer FK를 제거한 뒤,
Core Setup 화면에 남아 있던 G9 A/B 수동 배정 write path를 점검했다.

DB에는 이미:

    assign_current_grade9_section_core(uuid, text)

가 authoritative implementation으로 존재했고,

    assign_current_grade9_section(integer, text)

는 legacy compatibility wrapper로 정리돼 있었다.

하지만 frontend hook은 아직:

    studentId: number
    → assign_current_grade9_section(integer, ...)

를 호출하고 있었다.

이를:

    coreStudentId: string
    → assign_current_grade9_section_core(uuid, ...)

로 전환했다.

UI의 row key와 test id도 Core UUID를 사용하도록 바꿨다.

## Migration ledger reconciliation

병렬 세션이 live DB에 먼저 적용한 migration:

    grade9_core_assignment_rpc

의 실제 production version은:

    20260926173405

였지만 Git draft filename은 다른 timestamp였다.

따라서 Git migration filename을:

    20260926173405_grade9_core_assignment_rpc.sql

로 맞추고,
migration ledger에 TRACKED entry를 추가했다.

checkpoint:

    production migrations 53
    TRACKED structural    49
    LIVE_ONLY_DATA         4

## Rollback verification

실제 G9 학생 1명을 transaction 안에서만 사용해:

    Core UUID RPC → G9-A
    legacy wrapper → G9-B

를 차례로 호출했다.

두 경로 모두 동일 canonical Core 학생의 enrollment를 수정하는 것을 확인했다.

결과:

    Core path student match    true
    Legacy wrapper match       true

transaction은 rollback하여 실제 학생의 반 배정은 변경되지 않았다.

## CI behavior

API hook만 먼저 UUID로 바꾼 intermediate commit에서는
App call-site가 아직 integer를 보내고 있어 typecheck가 실패했다.

App까지 Core UUID로 수정한 다음 commit에서:

    migration ledger check SUCCESS
    typecheck SUCCESS
    build SUCCESS

로 복구됐다.

이 사례는 frontend type system이 identity migration의 stale call-site를 잡는
compile-time gate로 계속 작동하고 있음을 보여준다.


---

# 62. Legacy student master를 Browser Read-only로 잠그다

discipline record와 G9 assignment가 Core UUID 기준으로 이동한 뒤,
남은 위험한 우회경로를 점검했다.

Frontend 화면에서는 학생 명부를 이미 Core read-only 관점으로 사용하고 있었지만,
API module 안에는 예전 MVP의:

    useCreateStudent()
    useUpdateStudent()
    useDeleteStudent()

hook이 남아 있었다.

이 hook들은:

    public.students

를 직접 INSERT/UPDATE했다.

문제는 public.students가 이제 canonical student master가 아니라:

    legacy compatibility bridge

라는 점이다.

직접 새 row를 만들면:

    core.students canonical identity
    ↕
    public.students legacy bridge

관계가 깨질 수 있다.

## DB lock-down

production에서 다음 write RLS policy를 제거했다.

    students_write
    students_update

그리고 browser roles의 table privilege를 줄였다.

authenticated:

    SELECT  true
    INSERT  false
    UPDATE  false
    DELETE  false

anon:

    SELECT  false
    INSERT  false
    UPDATE  false
    DELETE  false

legacy sequence usage도 authenticated에서 제거했다.

RLS:

    SELECT policy 1
    write policy 0

현재 public.students는 browser 기준 완전한 read-only bridge다.

## Frontend cleanup

미사용:

    StudentInput
    useCreateStudent
    useUpdateStudent
    useDeleteStudent

를 api.ts에서 제거했다.

따라서 앞으로 Daniel frontend가 실수로 app-local 학생 master를 만들 수 있는
정상 코드 경로도 사라졌다.

## Identity ownership

현재 원칙:

    core.students
    = canonical student master

    public.students
    = legacy read-only compatibility bridge

실제 학생 추가/명부 수정은
Core provisioning/import workflow에서만 수행한다.

## Migration governance

live version:

    20260926175058_legacy_students_read_only

Git filename과 production ledger를 일치시켰다.

checkpoint:

    production migrations 54
    TRACKED structural    50
    LIVE_ONLY_DATA         4

최종 frontend cleanup push에서
migration-ledger check / typecheck / build가 모두 성공했다.


---

# 63. Legacy G9 Wrapper의 Privilege를 낮추다

G9 A/B 배정 frontend가 Core UUID RPC를 직접 사용하게 된 뒤,
legacy integer wrapper의 실행 권한을 다시 점검했다.

구조:

    assign_current_grade9_section(integer, text)
      ↓
    assign_current_grade9_section_core(uuid, text)

integer wrapper는:

1. public.students에서 Core UUID를 읽고
2. authoritative Core RPC에 delegate

만 수행한다.

따라서 wrapper 자체가 SECURITY DEFINER일 이유가 없었다.

## 변경

legacy wrapper를:

    SECURITY DEFINER
    ↓
    SECURITY INVOKER

로 변경했다.

Core UUID authoritative RPC는
lead-only authorization과 core.enrollments privileged write를 수행하므로
현재 SECURITY DEFINER를 유지한다.

## 결과

Supabase advisor:

    authenticated SECURITY DEFINER warnings
    11 → 10

legacy wrapper:

    security_definer = false

즉 compatibility path는 유지하면서
불필요한 privileged surface 하나를 제거했다.

## Migration governance

live migration:

    20260926175410_grade9_legacy_wrapper_invoker

Git filename과 production version을 맞추고
TRACKED ledger entry를 추가했다.

checkpoint:

    production migrations 55
    TRACKED structural    51
    LIVE_ONLY_DATA         4

---

# 운영 배포 출처를 화면에서 확인하기 — 2026-09-27

## 문제

PR #1은 병합되고 `main` CI는 통과했지만, Netlify production은 9월 21일 빌드에 머물러 있었다. Git 연결 설정만으로는 현재 운영 화면이 어느 커밋으로 만들어졌는지 확인하기 어려웠다.

## 조치

Netlify의 Git 빌드가 제공하는 `COMMIT_REF`를 Vite 빌드 시점에 주입하고, 로그인한 관리자 화면에 짧은 커밋 ID를 표시한다. 전체 40자리 값은 화면 요소의 제목에 남긴다. 커밋 메타데이터가 없는 로컬/수동 빌드는 `커밋 미확인`으로 표시해 출처를 추정하지 않는다. 인쇄물에는 배포 정보를 넣지 않는다.

이 변경은 학생 데이터나 Supabase 스키마를 건드리지 않는다. 다음 `main` 반영 후 Netlify가 자동으로 production deploy를 생성하는지 확인하고, 화면의 커밋 ID와 GitHub `main`을 대조한다.

## 운영 날짜 표시는 서울 시간으로 고정

업무 날짜 기본값은 이미 KST였지만 상단 날짜 배지는 브라우저의 로컬 시간대를 따르고 있었다. 해외 접속이나 기기 시간대 변경 시 같은 화면에서 입력 기본 날짜와 상단 날짜가 달라질 수 있어 상단 표시도 `Asia/Seoul`로 명시했다. 이 작은 수정의 `main` 반영을 Git 자동배포 트리거 재연결 검증에도 사용한다.


---

# 64. 주간 부서상점을 한국 시간 월요일에 무인 반영 — 2026-09-28

## 발견

기존 `ensure_weekly_department_merits` RPC는 선도부가 대시보드에 접속할 때만 호출됐다.
2026-09-27 UI 개편에서 앱 어느 화면으로 들어와도 선도부 첫 접속 시 호출하도록 옮겼지만,
월요일 시작 시각에 아무도 접속하지 않으면 자동 상점은 생성되지 않았다.

운영 DB의 `pg_cron`은 설치 가능하지만 비활성 상태였다. Cron 시간대는 GMT이고,
기존 공개 RPC는 `private.current_admin_role() = 'SEONDO'`를 요구하므로
인증 사용자가 없는 백그라운드 작업에서 그대로 호출할 수 없었다.

## 변경

`pg_cron`을 활성화하고 `department-merits-monday-kst` 작업을 등록했다.
매주 일요일 15:00 UTC, 즉 한국 시간 월요일 00:00에
`private.run_weekly_department_merit_job()`을 postgres 소유 작업으로 실행한다.
이 함수는 기존 RPC와 같은 부서/소속/규칙 조건을 사용하고
`department-weekly:<membership UUID>:<Monday date>` 키로 중복을 막는다.
브라우저 역할(anon, authenticated, service_role)에는 새 함수의 실행 권한이 없다.
기존 선도부 RPC와 화면의 ‘이번 주 반영’ 버튼은 누락 복구 경로로 남긴다.

## 검증

마이그레이션 SQL을 운영 DB 트랜잭션 안에서 시험 실행하고 rollback했다.
이후 최종 마이그레이션 `20260927153350_department_merits_monday_cron`을 한 번 적용했다.

- pg_cron 1.6.4 설치, 이름/시간표/명령/활성 여부 확인
- 작업 실행자 postgres, 브라우저 역할 실행 권한 없음 확인
- 1분 주기의 임시 무해한 Cron 작업(`select 1`)이 `succeeded`로 기록됨을 확인하고 즉시 `cron.unschedule`로 제거
- 이번 주(2026-09-28) 함수 수동 실행 두 번 모두 0건, 오류 없음
- 이번 주 부서상점 예상 대상 0명, 생성 0명

따라서 예약 엔진은 준비됐지만, 실제 상점이 생성되려면 부서, 학생 소속,
주간 상점 규칙을 운영 화면에 등록해야 한다. 예상 대상이 생기는 다음 월요일의
`cron.job_run_details` 및 생성 건수 확인이 실제 비어 있지 않은 실행의 검증 지점이다.


## 2026-09-28 — ‘디자인팀이 맡은 느낌’을 만드는 대시보드 디자인

### 요청과 판단
Josh는 글꼴과 시인성 개선에 이어, 전체적인 완성도와 업무 흐름을 설계한 느낌을 원했다.
날짜·요일·주차와 5개 대상자 카드 순서는 유지하고, 한 화면에서 현황 확인과 실제 업무를 이어가도록 했다.
일괄 색상 변경보다 업무 중요도, 반복 요소의 간격과 정렬, 조회 상태를 구분하는 데 집중했다.

### 구현
기존 DashboardPage의 쿼리와 담당 학년 필터는 연결 계층에 유지하고 화면을 DashboardView로 분리했다.
주간 달력과 부서상점 반영을 녹색 패널에 배치하고 반성문 제출·공지·정산으로 가는 링크를 옆에 정리했다.
학생 목록은 하나의 카드 안에서 제목·필터·검색·표·요약이 이어진다.
표의 NET 열은 옅은 배경, 숫자는 우측 정렬로 읽는 위치를 안정화했다.
정산기간을 학생 첫 행에서 추론하던 방식을 전용 기존 query 사용으로 바꾸어, 학생이 없어도 기간이 표시되게 했다.

### 검증 과정
로컬 typecheck/build는 성공했다. agent-browser daemon이 socket bind 권한 오류로 시작되지 않아,
임시 Netlify Deploy Preview에서 실제 컴포넌트를 가상 데이터로 렌더링하여 검증했다.
데스크톱·320px·390px 및 다크모드, 검색/카드 필터, 빈 상태, 설정 전과 조회 실패, 역할별 링크를 확인했다.
가상 데이터와 임시 검증 페이지는 운영 병합 전에 제외했다. 실계정 로그인 후 실데이터 화면 확인은 후속 운영 점검에 남는다.
디자인 근거와 검증 이미지는 `UI_DESIGN_SYSTEM.md`에 함께 보관한다.


## 2026-10-28 — 상점으로 상쇄된 벌점에는 반성문 의무가 생기지 않아야 한다

### 운영 요구

상점 10점을 확보한 학생이 벌점 5점을 받았다면 주간 NET은 +5이다. 벌점 발생만 보고 반성문과 미제출·2배 제출 처리가 자동 생성되는 기존 화면의 의미가 실제 규칙과 충돌했다. 특히 이후에 추가 벌점으로 NET이 음수가 될 때 기존 상쇄된 벌점까지 과거 마감으로 소급되어 2배가 되면 불공정해진다.

### 설계 결정

정규화된 점수 원장(`point_records`)과 기존 반성문 기록(`reflection_records`)은 보존하고, 조회 시점의 주간 NET과 벌점 입력 당시의 running NET 두 조건을 만족하는 건만 반성문 업무에서 활성화한다. 월~일 주차는 원장의 `recorded_at`, 동일 주차 입력 순서는 `created_at, id`로 결정한다. 이에 따라 월~일 주간 NET이 0 이상일 때는 학생 상태·공지·제출 명단이 함께 사라지며, 이후 다시 음수가 되면 해당 시점 이후의 벌점이 대상이 된다.

### 구현과 검증

읽기 계약 유지형 DB view 마이그레이션으로 반영하였고 기존 반성문 제출 마감·훈련·징계 규칙은 수정하지 않았다. 실제 운영 DB에서 81건 중 12건이 구기준의 오판정으로 제외되며 2배 표시 오판정 2건을 제거하는 것이 확인되었다. 실제 DB에서 `BEGIN/ROLLBACK`로 +10, -5, -6, +1, -1 사례를 검증해 데이터 변경은 남기지 않았다. 새 회귀 테스트는 `supabase/tests/reflection_weekly_net.sql`에 보존한다.
