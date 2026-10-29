# 다니엘의 저울 — 변경 이력

**Language / 언어:** [English](CHANGELOG.md) | [한국어](CHANGELOG.ko.md)

2026-10-29 현재 main `30f90a4`까지 대조했다. 최신 항목을 먼저 표시한다. 날짜는 Asia/Seoul의 커밋 시각 기준이며 실제 처리일이 다르면 본문에 구분한다. 과거 검증 기록은 새로운 운영 감사 결과가 아니다.

## 2026년 10월 — 커밋 대조표

| 한국 날짜 | 커밋 | 변경 |
| --- | --- | --- |
| 2026-10-29 | [30f90a4](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/30f90a4168ae97df69a201cb0089d80f14be8fce) | 미래일 상·벌점 저장과 KST 발생일 효력 |
| 2026-10-28 | [0b375c3](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/0b375c32a45605f3bd14d1b1ae0e0b93db9ac48f) | 영어 기본 영·한 문서와 검사 |
| 2026-10-28 | [e682248](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/e682248d717b042fb8074ed32a4c9e3819a2daf3) | 2배 반성문 미제출의 익일 체력훈련 |
| 2026-10-28 | [6db9325](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6db932596db56c6c654f04a0c5e62e38372fc931) | 미제출 공지 이월·G9 고등 담당 전환 |
| 2026-10-28 | [beb53fd](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/beb53fdd0cd7a3381cc6c532060ec0be5eba0f79) | 주간 음수 NET 기반 반성문 대상 |
| 2026-10-27 | [5223116](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/5223116c37219a93e7bddd11a43d202da97c8045) | 부서 소속 즉시 종료·자동 상점 재개 |
| 2026-10-27 | [cd9fe25](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/cd9fe25670e508c9e2b74e04968dfd5ff398b3a9) | 연속 체력훈련 주차·누적 NET |
| 2026-10-27 | [6370422](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6370422106d1fa907ce64202dd4f8eafd7923f07) | 주간 상점−벌점 NET 표시 |
| 2026-10-27 | [56a8296](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/56a8296c81210d7e698c3364c0ac956eeba7ec17) | 점수 기록 보유 학생 우선 정렬 |
| 2026-10-27 | [6c5036e](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6c5036e59aafc5e2cc30191b68085e6009f58236) | 수기 입력의 과거 발생일 허용 |
| 2026-10-27 | [0ecda8b](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/0ecda8b948aa4dd665b01cf7fdbec79164f54eb2) | 주간 확정 원장 이관·일별 운영 전환 |
| 2026-10-15 | [537b3db](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/537b3dbbb728f5aa76efd07b7b8a1bf08e9a541a) | Core 명부 자동 동기화 |
| 2026-10-06 | [c4a26a5](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/c4a26a5f76ecd5bf6d43804558397dfb5c6da8ed) | 과거 계정 안내 추가·후속 가상 양식 대체 |
| 2026-10-04 | [7a0622c](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/7a0622c17390bae6be63a037dbce0af55ff07037) | 조직 저장소 Netlify CLI 배포 경로 |

## 2026-10-29 — 미래일 상·벌점과 발생일 효력

상점·벌점 입력의 HTML 오늘 상한과 DB 미래일 금지를 제거하고 대체된 과거 원본의 수정 방지·감사 기록은 보존했다. 미래 행은 즉시 저장하지만 KST 발생일까지 주간·누적·정산 점수, 벌점 횟수, 반성문과 체력훈련·위원회 판정에는 반영하지 않는다. 미래 벌점은 입력 시 제출완료를 선택할 수 없으며 최근 입력·상세 이력에 예정으로 표시한다.

운영 이관 20261028185513_future_point_records_effective_date와 20261028185542_future_point_records_allow_write를 기록했다. 기존 기록에 따르면 실제 관리자 RPC의 미래 상·벌점 저장을 롤백 시험하고 현재 점수·반성문·훈련·위원회 상태가 변하지 않음을 확인했다. 이번 문서 갱신에서 운영 시험을 새로 실행한 것은 아니다.


관련 커밋: [30f90a4](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/30f90a4168ae97df69a201cb0089d80f14be8fce).

## 2026-10-28 — 반성문 주간 NET 음수 판정

- 벌점 1건만으로 자동으로 반성문 대상자로 표시하던 읽기 경로를 수정. 월~일 주간 상벌NET이 **0 미만**이며, 해당 벌점 입력 당시 NET도 0 미만으로 전환/유지된 건만 반성문 대상으로 조회.
- 상점을 먼저 확보한 학생의 초기 벌점이 사후에 소급 미제출/2배 대상으로 처리되지 않도록 방지.
- `v_reflections`·공지·포인트 기록·학생 상태(대시보드 포함)를 같은 DB 기준으로 동기화. 2배 마감 시간 규칙 및 체력훈련 규칙은 별도 유지. 벌점 원장과 감사 기록은 수정하지 않음.
- 운영 DB에 마이그레이션 `20261028003013_reflection_weekly_net_eligibility` 적용. 변경 전 활성 반성문 81건 중 12건 판정 제외(이중 2건 기존의 2배 미제출 상태), 적용 후 69건으로 확인. 트랜잭션 롤백 테스트 통과.

관련 커밋: [beb53fd](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/beb53fdd0cd7a3381cc6c532060ec0be5eba0f79).

## 2026-10-28 — 공지 이월 / G9 담당 변경 / 인쇄·대시보드 UI

- 공지 날짜가 오늘이면 오늘 미제출 반성문 대상과 이전 날짜에 발생해 현재 2배 제출 대상인 미제출 건을 함께 표시. 제출 완료와 NET 상계된 대상은 자동 제외. 과거 날짜 선택 시 이월하지 않음. 60초 폴링과 제출 상태 변경 시 캐시 무효화 적용.
- 반성문 페이지의 오늘 대상 필터 및 대시보드 오늘 대상 카드도 신규 미제출과 이월된 2배 대상으로 일치. 실제 주간 NET의 DB eligibility view는 유지.
- 주간 벌점 `−0` 형식, 체력훈련 다크 네이비 상태 배지·대시보드 카드, 2배 제출 기존 빨간 배지 적용.
- 담당 범위 G9를 고등부로 변경 (DB view 및 discipline history RPC / 프런트 전체 범위 필터); 학생 학적 자체는 변경하지 않음.
- 인쇄 A4 여백 16×17mm, 표 12.5px·출력 헤더·셀 여백 확장, 페이지 간 분할 안정화, 과거 발생일·2배 제출 표시 강조.
- 운영 DB migration `20261028012114_move_grade9_to_high_scope` 적용 및 G9 reflection scope=HIGH 검증.

관련 커밋: [6db9325](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6db932596db56c6c654f04a0c5e62e38372fc931).

## 2026-10-28 — 체력훈련 세 번째 기준 적용

- 2배 반성문 17시 미제출 시 익일부터 체력훈련 대상으로 추가 분류.
- 주간 벌점 횟수·NET 기존 기준은 유지하며 사유를 각각 표기.
- 17시 제출 기한과 제출 완료 후 자동 해제, 중복 주차 방지 검증.
- 대시보드, 학생 상세, 주간 출력물 및 정기 조회 반영.

관련 커밋: [e682248](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/e682248d717b042fb8074ed32a4c9e3819a2daf3).

## 2026-10-28 — 영·한 문서 병합 (10/26 준비 시작)

모든 유지 Markdown에 언어 선택과 한국어판을 적용하고 사례 연구·언어 검사·과거 첨부 읽기판을 추가했다. 실명/PIN 계정 안내는 가상 빈 양식으로 대체했다. 과거 Git 객체와 인증정보는 Owner가 별도 확인해야 한다. 새 커밋은 영어이며 기존 메시지 재작성은 별도 미리보기 절차로 준비했다.

관련 커밋: [0b375c3](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/0b375c32a45605f3bd14d1b1ae0e0b93db9ac48f).

## 2026-10-27 — 주간 이력·일별 운영과 후속 교정

이 날짜의 커밋은 10/26 UTC에 적용한 이관을 기록한다. 원본 898행·연결 주간값 873건·비공개 미해결 22행을 보존하고 기존 중고등 사건 170건을 공식 집계에서 대체했다. 초등과 당시 현재 사건 40건은 유지했다. 주간 확정값을 일점수로 오인하지 않도록 표시하며 누락·비운영 주를 0으로 채우지 않는다. XLSX 미리보기·수정 이관·재시도 중복방지·취소·범위별 이력 조회를 추가했다. [이력 전환](HISTORY_AND_BACKFILL.ko.md)을 참조한다.

후속 수기 시험 초기화는 사건 42건을 논리삭제하고 주간값 873건을 비현재로 표시하되 원본과 비공개 점검값을 보존했다. 학기 이전을 포함한 과거 발생일을 허용했으며 당시 미래일은 거부했다. 이 제한은 10/29 효력일 변경으로 대체됐다. [초기화 기록](OPERATIONS_2026-10-27.ko.md)을 참조한다.

점수 기록 보유 학생 우선 정렬, 화면 NET의 상점−벌점 표기, 현재 학기의 달력 주차 3주 연속 체력훈련에 따른 위원회 판정을 반영했다. 중간 주가 빠지면 연속이 끊기고 기존 20점·비연속 3주 대안은 제거됐다. 소속 종료일은 미포함으로 통일하고 자동상점 규칙 4개·월요일 Cron을 재개했다. 기록된 생성 38/38건은 중복 없이 유지됐으며 현재 명단과 월요일 대상 인원은 다른 시점을 나타낸다. [현재 규칙](DISCIPLINE_RULES.ko.md)과 [부서상점](DEPARTMENT_MERITS.ko.md)을 참조한다.

이는 저장소의 당시 기록이며 이번 작업에서 운영 DB를 새로 감사한 결과가 아니다. 상단 커밋표의 날짜와 본문에 기록한 실제 처리 날짜를 구분한다.


관련 커밋: [5223116](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/5223116c37219a93e7bddd11a43d202da97c8045), [cd9fe25](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/cd9fe25670e508c9e2b74e04968dfd5ff398b3a9), [6370422](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6370422106d1fa907ce64202dd4f8eafd7923f07), [56a8296](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/56a8296c81210d7e698c3364c0ac956eeba7ec17), [6c5036e](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/6c5036e59aafc5e2cc30191b68085e6009f58236), [0ecda8b](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/0ecda8b948aa4dd665b01cf7fdbec79164f54eb2).

## 2026-10-15 — CORE 명부 실시간 동기화

- 다니엘의 저울 학생 명부 호환행을 DICS CORE의 활성 학생과 현재 학적에서 자동 생성·갱신하도록 production migration 적용.
- CORE 학생의 이름·활성상태 변경과 현재 학적의 추가·변경·종료를 trigger로 반영.
- 활성 학생 + 현재 학적이면 명부에 즉시 표시하고, 비활성 또는 현재 학적 종료 상태이면 명부에서 자동으로 숨김.
- 새 학기 전환 시 전체 학생 bridge를 다시 동기화.
- 기존에 CORE에만 있던 활성 학생 1명을 backfill하여 다니엘의 저울 명부에 반영.
- 호환 테이블은 기존 화면과 numeric URL을 위한 bridge로만 유지하며, 학생 원본은 계속 `core.students.id`를 사용.
- live migration: `20261015101921_sync_daniel_roster_from_core.sql`.

관련 커밋: [537b3db](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/537b3dbbb728f5aa76efd07b7b8a1bf08e9a541a).

## 2026-10-06 — 과거 계정 안내 추가

메시지가 빈 커밋의 파일 차이에서 계정 배부 HTML 추가를 확인했다. 빈 메시지를 배포 성공 근거로 삼지 않는다. 이후 영·한 문서 변경에서 현재 파일을 가상 양식으로 대체했다. 과거 객체와 인증정보 유효성은 Owner의 별도 확인 대상이며 값은 이 변경 이력에 재기재하지 않는다.


관련 커밋: [c4a26a5](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/c4a26a5f76ecd5bf6d43804558397dfb5c6da8ed).

## 2026-10-04 — 조직 저장소 배포 경로

비공개 조직 저장소를 위한 GitHub Actions 검증과 고정 버전 Netlify CLI 배포를 추가했다. 기존 사이트·운영 환경을 사용하며 PR은 검증만 수행하고 main 앱·빌드 변경은 배포할 수 있다. 설정 커밋만으로 실제 배포 성공을 단정하지 않는다. 10/4는 UTC 10/3 커밋의 한국 날짜다. [배포 절차](netlify-deployment.ko.md)를 참조한다.

관련 커밋: [7a0622c](https://github.com/Disciple-International-Christian-School/danielyi-jeoul/commit/7a0622c17390bae6be63a037dbce0af55ff07037).

## 2026년 9월 — 설계·구축 기록

> **ACTIVE DOCUMENT — 2026-09-21 이후 계속 갱신**
>
> 이 문서는 `docs/spec.md`의 원래 요구사항을 대체하지 않는다.
> 초기 구축 이전의 상세 과정은 [LEGACY_INITIAL_BUILD.md](./LEGACY_INITIAL_BUILD.ko.md)에 동결 보존한다.
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

### 공지·출력 Phase — 2026-09-25

**Production DB applied**

- `v_daily_discipline_notice` 적용.
  - 날짜별 벌점 기록
  - 학생 학년/반
  - 벌점 사유/점수
  - 반성문 상태/마감 시각
- `v_weekly_discipline_report` 적용.
  - 주간 상점/벌점/NET
  - 벌점 발생 횟수
  - 체력훈련 대상
  - 열린 정산기간 NET
  - 체력훈련 판정 주차 수
  - 징계위원회 대상
- 운영 DB 검증 결과:
  - daily notice view 정상 조회
  - weekly report view 활성 학생 175명 정상 조회
  - 현재 실제 체력훈련/징계위원회 대상 0명

**Frontend in branch**

- 선도부 메뉴에 `공지·출력` 추가.
- 일일 반별 공지:
  - 날짜 선택
  - 학년/반 필터
  - 벌점/반성문 상태
  - A4 인쇄
- 주간 정산 보고:
  - 체력훈련/징계위원회 대상만 추출
  - 주간 raw 점수 + NET
  - 정산기간 NET
  - 학년/반별 묶음
  - A4 인쇄
- 현재 Core homeroom이 없는 학생은 `G{grade}`로 fallback하며, G9-A/B enrollment 보강 후 자동으로 분반 표기.
- GitHub Actions CI 추가: `npm ci → typecheck → build`.

### 부서활동 자동 상점 Phase — 2026-09-25

**Production DB applied**

- `core.departments`, `core.department_memberships` 추가.
- `discipline.department_merit_rules` 추가.
- `point_records.source_type / source_key` 추가.
- 주간 자동 상점은 `source_key` unique index로 중복 생성 방지.
- `ensure_weekly_department_merits()` RPC 추가.
- 현재 실제 부서/소속/규칙 데이터는 0건이며, 따라서 자동 생성 기록도 0건.
- `pg_cron`은 설치하지 않고, 첫 선도부 Dashboard 접속 시 해당 주 월요일 기록을 idempotent하게 보장하는 방식으로 운영.
- 추후 scheduler 도입 시 동일 데이터 모델/RPC를 그대로 재사용 가능.

**Frontend in branch**

- 선도부 Dashboard 진입 시 그 주의 부서활동 상점 누락 여부 자동 확인.
- 신규 생성이 있을 때만 Dashboard/학생 합계 재조회 및 완료 알림.
- 현재 규칙 데이터가 없으면 UI에 불필요한 자동상점 상태를 표시하지 않음.

### 아침 벌점 연속입력 Phase — 2026-09-25

- 학생 검색을 이름뿐 아니라 학번/반까지 확장.
- 검색 결과가 한 명이면 Enter로 바로 학생 선택 가능.
- `연속 입력 모드` 추가.
  - 저장 후 학생만 초기화.
  - 항목/점수/날짜/기입자는 유지.
  - 검색창으로 자동 포커스.
- 최근 입력 6건을 현재 세션 화면에 표시.
- 종이 벌점 시트 여러 건을 오전에 빠르게 전산화하는 흐름을 우선 최적화.
- 사진 시트 인식은 별도 P2로 유지.

### 반성문 담당범위 / 선도부장 Phase — 2026-09-25

**Production DB applied**

- `admins.discipline_scope` 추가.
  - `ELEMENTARY` = G1–6
  - `MIDDLE` = G7–9
  - `HIGH` = G10–12
  - `ALL` = 선도부장/legacy shared account
- `admins.is_lead`, `admins.is_active` 추가.
- 기존 shared SEONDO 계정은 호환을 위해 `ALL + lead + active` 유지.
- 비활성 admin은 `private.current_admin_role()`에서 제외.
- 정산 시작/종료 RPC는 선도부장 권한으로 제한.
- `v_reflections.assigned_scope` 추가.

**Frontend in branch**

- Auth profile에 `disciplineScope / isLead / isActive` 노출.
- 반성문 화면을 담당범위별로 필터.
- 개인 담당 계정은 자기 학년군만 기본 표시.
- 선도부장은 전체 학년 조회.
- 정산 관리 메뉴/route는 선도부장만 접근.
- 일일 공지 출력은 담당 학년군으로 제한.
- 주간 정산 보고는 선도부장만 표시.

### Auth provenance / Audit Phase — 2026-09-25

**Production DB applied**

- `point_records / reflection_records / punishments`에 `created_by / updated_by` Auth UUID 추가.
- INSERT/UPDATE 시 서버 trigger가 `auth.uid()`를 자동 기록.
- 기존 기록은 작성자를 추정하지 않고 null 유지.
- `discipline.audit_logs` append-only 감사 로그 추가.
  - point records
  - reflection records
  - punishments
  - settlement periods
  의 INSERT/UPDATE/DELETE before/after를 기록.
- 기존 public RPC 시그니처는 유지하면서 role validation과 fixed `search_path` 적용.
- 향후 개인 admin 계정 전환 시 별도 schema 변경 없이 실제 작성자/수정자 추적 가능.
- Supabase security advisor 확인 결과 신규 경고 없음.
- 기존 Auth의 leaked-password protection 비활성 경고는 학생 6자리 PIN 정책 검토 전까지 보류.

### Core readiness / SP shadow schema Phase — 2026-09-25

**Production DB applied**

- `v_core_migration_readiness` 추가.
- `v_core_student_readiness` 추가.
- 현재 Core readiness:
  - Core total 180
  - active 175
  - Daniel bridge 175
  - current-term enrollment 144
  - student_no linked 28
  - Core-local Auth linked 0
  - external/legacy Auth linked 0
- 병렬 세션에서 live DB에 먼저 적용된 current-term/audit 구조를 Git migration으로 reconciliation.
- `study_planner` shadow target schema 생성.
  - 실제 SP data는 아직 0건.
  - student FK는 처음부터 `core.students.id`.
  - term master는 `core.academic_terms` 재사용.
  - 기존 SP 운영 프로젝트는 그대로 유지.

**Frontend in branch**

- Core 설정 화면을 provisioning console + integration readiness dashboard로 확장.
- Core Identity / 학번 / Auth / 현재 학적 / READY 수치를 표시.
- READY / PARTIAL / CORE_ONLY 상태 집계.
- 미완료 학생별로 어떤 연결이 빠져 있는지 표시.
- G9-A/B provisioning UI와 같은 화면에서 다음 병목을 확인.

**Documentation**

- `docs/DEVELOPMENT_JOURNAL.md`를 공식 개발 서사 원본으로 유지.
- 병렬 DB drift 발견/복구, readiness 계측, Study Planner shadow schema까지 서사 기록.
- `docs/SP_CORE_MIGRATION_RUNBOOK.md` 추가.
- Claude/GPT coordination Issue에 live SP aggregate inventory 요청.

### Secure cross-project identity migration — 2026-09-25

**Production DB applied**

- Core-local Auth와 외부/legacy Auth namespace를 명시적으로 분리.
- `core.external_auth_identities`를 version-controlled migration으로 reconciliation.
- `public.link_external_auth_identity(...)` lead-only guarded RPC 추가.
  - student_no 존재 검증
  - external identity의 다른 학생 재할당 거부
  - 동일 source에서 한 학생의 다른 identity 충돌 거부
  - 동일 mapping 재실행 시 idempotent verification
- Core admin SECURITY DEFINER RPC의 anonymous EXECUTE 권한 제거.
- `v_external_auth_mapping_status` PII-free aggregate progress view 추가.
- Study Planner staff도 external Auth namespace를 분리:
  - domain staff UUID
  - optional Core-local Auth
  - external staff identity bridge
- lead-only Study Planner target inventory 추가.
- Study Planner shadow FK advisor 지적 10개 인덱스 보강.

**Migration tooling**

- `scripts/migrate-sp-external-identities.mjs` 추가.
- 기본 DRY RUN, 명시적 `--apply`에서만 write.
- 이름/이메일/PIN/DOB를 읽거나 출력하지 않음.
- SP/Core student_no exact match만 사용.
- known test/developer login ID 명시 제외.
- conflicting identity/bridge 발견 시 write 전 hard stop.
- 두 Supabase 프로젝트 간 distributed transaction 부재를 idempotent rerun으로 대응.
- CI에 migration runner syntax check 추가.

### Department merit administration — 2026-09-25

**Production DB applied**

- lead-only 부서 생성 / 주간 상점 rule 관리 RPC.
- lead-only 학생 부서 소속 시작/종료 RPC.
- 소속은 starts_on / ends_on 이력으로 보존.
- 규칙 변경은 effective date 기반 version history 유지.
- 부서 read scope를 SEONDO로 제한, write는 lead-only.
- 현재 실제 운영 데이터는 departments 0 / memberships 0 / rules 0 / generated records 0.

**Frontend in branch**

- 선도부장 전용 `부서 상점` 메뉴.
- 부서 생성·수정·활성/중지.
- 이름/학번/반 검색 후 학생 소속 관리.
- 이번 주 자동상점 generated / expected 상태 표시.
- `이번 주 반영` 버튼으로 idempotent merit generation 실행.
- 실제 학생 부서 명단은 Supabase에만 저장하며 Git에는 포함하지 않음.

**Quality**

- UI 위치 오류가 CI에서 실패로 감지됨.
- source 위치 확인 후 department console로 이동.
- corrected branch CI 통과.

### Personal admin accounts — 2026-09-25

**Production DB applied**

- `admins.login_id` 추가 및 기존 공유계정 login ID backfill.
- `must_change_password`, `last_password_changed_at`, `provisioned_by` 추가.
- admin roster read를 self 또는 active SEONDO lead로 제한.
- lead-only `register_admin_profile(...)`, `update_admin_profile(...)`.
- 마지막 활성 SEONDO lead 제거 방지.
- lead는 항상 discipline scope `ALL`.
- admin profile 변경도 append-only audit trail에 포함.
- client에서 password-complete flag를 직접 내리는 RPC 제거.

**Edge Functions deployed**

- `provision-admin-account`
  - JWT required
  - lead 확인
  - server-side Auth Admin createUser
  - cryptographically random temporary password
  - profile 실패 시 Auth user compensating delete
- `change-admin-password`
  - JWT required
  - 실제 Auth password 변경 성공 후에만 first-login flag 해제

**Frontend in branch**

- lead-only 관리자 계정 console.
- 개인계정 생성 / 역할 / 담당범위 / 활성상태 관리.
- 임시 로그인정보 one-time display.
- 신규 계정 첫 로그인 password change 강제.
- 비활성 admin 운영화면 접근 차단.
- 기존 공유계정은 transition fallback으로 유지.

**Current operational state**

- admin profiles 2
- active admins 2
- active leads 1
- newly provisioned personal staff accounts 0
- must-change-password accounts 0

### Discipline Core UUID cut-over — 2026-09-25

**Production DB applied**

- `point_records.core_student_id` / `punishments.core_student_id` 추가.
- 기존 record canonical UUID backfill.
- Core UUID FK + indexes.
- legacy integer / Core UUID mismatch 방지 trigger.
- `v_discipline_core_fk_readiness` aggregate validation.
- Core UUID write entrypoints:
  - `create_point_record_core(...)`
  - `create_punishment_core(...)`
- 기존 business-rule RPC에 delegate하여 검증 로직 중복 방지.

**Validation**

- point records 1/1 Core-linked.
- mismatch 0.
- punishment mismatch 0.
- authenticated rollback RPC test:
  - created true
  - Core UUID present
  - legacy/Core identity match true
  - test data rollback 완료.

**Frontend**

- new point record / punishment creation now sends canonical Core UUID.
- legacy integer route/read compatibility는 다음 단계까지 유지.
- API type cut-over가 stale App call-site를 CI에서 탐지했고 수정 후 CI green.

### Discipline canonical Core UUID dual-key — 2026-09-25

**Production DB applied**

- `point_records.core_student_id` / `punishments.core_student_id` 추가.
- 기존 discipline records를 canonical `core.students.id`로 backfill.
- Core UUID FK + supporting indexes 추가.
- legacy student_id ↔ Core UUID mismatch 방지 trigger 추가.
- `v_point_records`, `v_punishments`에 Core UUID 노출.
- aggregate cut-over readiness view `v_discipline_core_fk_readiness` 추가.
- canonical write RPC:
  - `create_point_record_core(...)`
  - `create_punishment_core(...)`

**Verification**

- current point records: 1/1 Core linked, mismatch 0.
- current punishments: 0, mismatch 0.
- rollback insert trigger test: Core UUID auto-fill success.
- authenticated rollback RPC test: Core UUID/legacy ID same-student match success.
- test records were rolled back; no test discipline row remains.

**Frontend in branch**

- new point/penalty writes send canonical Core UUID.
- new punishment writes send canonical Core UUID.
- legacy integer route/read compatibility intentionally remains until final FK cut-over.

### Discipline canonical Core UUID final cut-over — 2026-09-27

**Production DB completed**

- `point_records.student_id` 물리 컬럼 제거.
- `punishments.student_id` 물리 컬럼 제거.
- 두 테이블의 유일한 학생 FK는 `core_student_id UUID NOT NULL`.
- legacy integer ID는 public view에서 Core UUID → legacy bridge로 계산하는 compatibility 값으로만 유지.
- `create_point_record_core(...)` / `create_punishment_core(...)`를 authoritative business-rule implementation으로 승격.
- 기존 integer RPC는 Core UUID를 resolve한 뒤 authoritative RPC에 delegate하는 compatibility wrapper로 전환.
- 부서 자동상점도 physical write 시 Core UUID만 저장.
- 반성문 자동생성 trigger의 학년 lookup을 `new.core_student_id` 기준으로 전환.

**Read / calculation cut-over**

- student detail route의 신규 링크를 Core UUID로 전환.
- legacy numeric URL은 fallback lookup으로 유지.
- weekly / weekly penalty / settlement Core shadow 계산 추가 후 parity 검증.
- production parity:
  - weekly 1 legacy / 1 Core / mismatch 0
  - weekly penalty 1 / 1 / mismatch 0
  - settlement 0 / 0 / mismatch 0
- student summary Core shadow:
  - 175 legacy / 175 Core / mismatch 0
- public `v_weekly_scores`, `v_weekly_penalties`, `v_settlement_scores`, `v_student_summary`를 Core UUID implementation으로 promotion.
- point/reflection/punishment/daily-notice read join을 Core UUID 기준으로 promotion.

**Destructive migration safety**

- PostgreSQL `pg_depend`로 실제 physical-column dependency를 식별.
- 반성문 trigger의 숨은 legacy dependency를 별도 발견 후 수정.
- drop 직전 aggregate evidence를 `discipline.core_cutover_evidence`에 저장.
- evidence에는 이름/학번/Auth UUID/개별 mapping 없음.
- post-drop status:
  - `legacy_columns_removed = true`
  - `cutover_completed = true`
- post-cutover rollback tests:
  - Core point write 성공
  - legacy point wrapper 성공
  - reflection trigger 성공
  - Core punishment write 성공
  - legacy punishment wrapper 성공
  - 테스트 row는 모두 rollback

**Production state preserved**

- point records 1
- point sum 5
- reflection records 1
- punishments 0
- weekly report rows 175
- Dashboard counts unchanged

**Migration governance**

- recent Core-cutover migration 15개를 live Supabase version과 Git filename 1:1 reconciliation.
- admin RLS optimization migration도 live version에 맞춰 filename reconciliation.
- Git migration content는 변경하지 않고 version/path만 production ledger와 정렬.
- CI migration version uniqueness 유지.

**Advisor follow-up**

- `admins_read_self_or_lead` RLS를 initplan-friendly form으로 변경.
- Supabase `auth_rls_initplan` performance warning 제거.
- 남은 performance findings는 현재 모두 unused-index INFO로, usage history가 충분하지 않아 삭제하지 않음.

### Production migration ledger enforcement — 2026-09-27

- 전체 production migration history를 Git과 재대조.
- 구조 migration 16개의 historical timestamp/name drift 추가 reconciliation.
- 최종 상태:
  - production migrations 52
  - TRACKED structural migrations 48
  - LIVE_ONLY_DATA migrations 4
  - extra Git migrations 0
- `supabase/migration-ledger.json` 추가.
- `scripts/check-migration-ledger.mjs` 추가.
- `npm run check:migration-ledger` 추가.
- GitHub Actions에서 migration ledger contract 자동 검증.
- TRACKED migration은 live version/name과 exact Git filename을 강제.
- LIVE_ONLY_DATA version에 SQL 파일이 Git에 들어오면 CI 실패.
- private roster correction처럼 migration name 자체가 민감할 수 있는 경우 name redaction 허용.
- 초기 ledger 작성 중 민감 가능 migration name을 발견해 즉시 redacted entry로 교정.
- ledger CI 첫 실행 성공.

### G9 section assignment Core UUID cut-over — 2026-09-27

- `assign_current_grade9_section_core(uuid,text)`를 authoritative assignment RPC로 사용.
- integer `assign_current_grade9_section(int,text)`는 compatibility wrapper로 유지.
- G9 Core Setup frontend write를 `studentId:number` → `coreStudentId:string`으로 전환.
- row key / test id도 Core UUID 기준으로 전환.
- live migration version `20260926173405_grade9_core_assignment_rpc.sql`로 Git filename reconciliation.
- migration ledger TRACKED 항목 추가.
- rollback 검증:
  - Core RPC G9-A 배정 성공
  - legacy wrapper G9-B 배정 성공
  - 두 경로 동일 Core 학생 확인
  - transaction rollback으로 실제 반 배정 변화 없음
- API-only intermediate commit의 typecheck failure를 stale integer call-site가 감지.
- App Core UUID 전환 후 CI green.

### Legacy student bridge browser read-only — 2026-09-27

- `public.students`를 canonical master가 아닌 legacy compatibility bridge로 확정.
- browser roles에서 `public.students` write 권한 제거.
- authenticated:
  - SELECT true
  - INSERT/UPDATE/DELETE false
- anon:
  - SELECT/INSERT/UPDATE/DELETE false
- `students_write`, `students_update` RLS policy 제거.
- legacy `students_id_seq` browser usage 제거.
- 미사용 frontend/API legacy student mutation 제거:
  - `StudentInput`
  - `useCreateStudent`
  - `useUpdateStudent`
  - `useDeleteStudent`
- 새 학생 master 생성/수정은 DICS Core provisioning/import 경로에서만 수행.
- live migration:
  - `20260926175058_legacy_students_read_only.sql`
- migration ledger:
  - production 54
  - TRACKED 50
  - LIVE_ONLY_DATA 4
- final frontend cleanup push CI green.

### G9 legacy wrapper privilege reduction — 2026-09-27

- legacy `assign_current_grade9_section(int,text)`를 `SECURITY DEFINER` → `SECURITY INVOKER`로 변경.
- Core UUID authoritative RPC는 privileged write + lead check 때문에 `SECURITY DEFINER` 유지.
- legacy wrapper compatibility는 유지하면서 불필요한 privileged surface 제거.
- Supabase authenticated SECURITY DEFINER advisor warning 11 → 10.
- live migration:
  - `20260926175410_grade9_legacy_wrapper_invoker.sql`
- migration ledger:
  - production 55
  - TRACKED 51
  - LIVE_ONLY_DATA 4

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


### 현황판 카드에서 대상 명단으로 이동 — 2026-09-28

- 선도부 대시보드의 반성문 대상자·미제출자·2배 제출 대상자 카드를 각 상태의 반성문 목록에 연결했다. 오늘 대상은 한국 시간의 기록 날짜로 필터링한다.
- 미제출 목록에는 기본 미제출과 마감 초과 2배 대상을 함께 표시한다. 대시보드 미제출 학생 수와 목록의 범위를 일치시킨다.
- 체력훈련·징계위원회 대상 카드는 대시보드의 학생 상태 목록을 해당 대상만 표시하도록 전환하고 목록으로 이동한다. 필터를 직접 바꾸거나 전체 학생으로 돌아갈 수 있다.
- 담당 학년군 제한은 명단에서도 유지한다. DB와 권한 스키마에는 변경이 없다.
- 학생 명부는 선도부장 메뉴에서 관리자 계정 아래 하위 항목으로 표시한다. 일반 선도부 계정에서는 접근 가능한 관리 메뉴로 표시한다.


### 한글 UI 가독성·시인성 개선 — 2026-09-28

- 여러 웹폰트 조합을 Pretendard Variable 동적 서브셋 1종으로 정리하고, 한글·영문·숫자의 글꼴 체계를 통일했다. 외부 폰트 로딩 실패 시 시스템 한글 글꼴로 대체한다.
- 본문·보조 설명·버튼·표·상태 배지·메뉴·반성문 기록의 기본 크기와 굵기를 키우고 숫자에는 tabular numerals를 적용했다.
- 밝은/어두운 테마의 본문, 보조 문구, 핵심 색, 입력 경계 대비를 조정했다. 대표 색 조합의 계산상 명암비는 일반 텍스트 4.5:1 및 입력 경계 3:1을 넘는다. 전 화면의 접근성 인증을 뜻하지는 않는다.
- Lucide SVG 아이콘의 표시 크기·선 굵기를 맞추고, 저울 브랜드 표식의 줄바꿈 문제를 수정했다. 화면 위의 노이즈 오버레이를 제거했다.
- 로그인 카드와 입력 칸 크기를 늘리고 모바일 화면 확대를 막던 viewport 제한을 제거했다. 인쇄물의 작은 주석·표 헤더도 읽기 좋게 조정했다.
- 글꼴: [Pretendard OFL 1.1](https://github.com/orioncactus/pretendard/blob/main/LICENSE). 아이콘: 기존 lucide-react 유지.

## 2026-09-28 — 대시보드 디자인 기준 화면 (PR #11)

- 날짜·주차 및 입력 바로가기, 5개 대상자 카드, 주간 업무, 학생 점수 순으로 정보 위계 재설계.
- 주간 달력과 부서상점 진행, 반성문 제출 확인·공지·정산 링크를 연결.
- 정산기간을 전용 query로 조회하고 부서상점/정산 조회 실패를 미설정 상태와 구분.
- 학생 목록의 필터·검색·정렬, 점수 정렬, 상태·빈 목록과 키보드 포커스 정비.
- 체력훈련/징계위원회 카드 클릭 시 검색을 초기화해 대상자가 검색어로 숨겨지는 문제 방지.
- 밝은/어두운 화면, 320/390px 모바일 시각 검증. 타입 검사·빌드 및 PR CI 통과.
- 디자인 원칙과 가상 데이터 검증 이미지: `docs/UI_DESIGN_SYSTEM.md`.
