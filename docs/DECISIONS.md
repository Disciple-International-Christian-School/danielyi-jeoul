# DICS Core — Decision Log

> **Architecture & operations decisions**
>
> 이 문서는 “무엇을 만들었는가”보다 **어떤 선택지를 두고 왜 이 결정을 했는가**를 보존한다.
> Development Journal이 서사라면, 이 문서는 나중에 빠르게 의사결정 근거를 찾기 위한 ledger다.
>
> 상태: `ACCEPTED`, `TRANSITION`, `OPEN`, `SUPERSEDED`

---

| ID | 상태 | 결정 | 핵심 이유 |
|---|---|---|---|
| D-001 | ACCEPTED | 학생 자체 UUID와 로그인 Auth UUID를 분리 | 로그인 없는 학생도 존재하며 Auth provider가 학생 identity를 정의하면 안 됨 |
| D-002 | ACCEPTED | 한 학생 master는 `core.students` 하나 | SP/discipline/lab/assessment의 중복 학생 master 방지 |
| D-003 | ACCEPTED | 학년/반은 student row가 아니라 term enrollment | 진급·분반 변경 이력 보존 |
| D-004 | ACCEPTED | 생활지도 판정은 raw 점수 보존 + 파생 NET | 상점/벌점 원기록을 지우지 않으면서 정책 판정 가능 |
| D-005 | ACCEPTED | calendar month 대신 관리자 종료형 settlement | 실제 귀가 주기가 2–3주로 변동 |
| D-006 | ACCEPTED | 반성문 deadline은 `timestamptz due_at` | 17:00 / 21:00 / 익일 등교 같은 시간 규칙 필요 |
| D-007 | ACCEPTED | 운영 날짜는 명시적 Asia/Seoul | UTC 날짜가 아침 업무에서 전날로 보이는 오류 방지 |
| D-008 | ACCEPTED | 자동 상점은 scheduler보다 idempotent RPC 우선 | 실행 시각보다 중복 없는 결과가 핵심, scheduler 교체 가능 |
| D-009 | ACCEPTED | 실데이터 migration에서 추정 매칭 금지 | 동명이인·오타가 canonical identity 오염으로 이어질 수 있음 |
| D-010 | ACCEPTED | 기존 과거 작성자를 추정 backfill하지 않음 | 감사로그는 모르는 값을 null로 남기는 편이 정확 |
| D-011 | ACCEPTED | SP 외부 Auth UUID와 Core local Auth UUID를 분리 | 서로 다른 Supabase project의 Auth namespace는 FK 공유 불가 |
| D-012 | TRANSITION | 기존 SP pilot ID 28건을 Core student_no로 보강 | 이미 학생 로그인에 사용 중이며 1:1 검증 완료된 값만 우선 보존 |
| D-013 | OPEN | 전교생 human-facing student number 발급정책 | 기존 `GGNN` 형식은 학년을 포함해 진급 시 stable ID 원칙과 충돌 |
| D-014 | OPEN | 기존 SP `GGNN`을 permanent student_no로 유지할지 legacy login alias로 전환할지 | 기존 사용자 경험 보존과 장기 identity 안정성을 함께 고려해야 함 |
| D-015 | TRANSITION | Daniel 내부에 Core provisioning console 유지 | Core Admin이 별도 앱으로 분리되기 전 안전한 provisioning 경로 필요 |
| D-016 | TRANSITION | shared Core DB는 중앙 migration ledger를 둔다 | 여러 domain/AI lane이 live DB를 동시에 바꾸면 Git↔DB drift가 발생 |
| D-017 | ACCEPTED | 외부 Auth mapping 값은 Git/Issue/채팅 handoff 대신 secure migration path로 이동 | Auth UUID·student_no 매핑은 운영 identity data이며 공개 개발 기록과 분리해야 함 |
| D-018 | ACCEPTED | 공유 관리자 계정은 즉시 삭제하지 않고 개인계정으로 staged transition | 운영 연속성을 보존하면서 audit actor를 개인화하기 위함 |
| D-019 | ACCEPTED | 개인계정 Auth 생성과 첫 비밀번호 변경 완료 처리는 Edge Function에서 수행 | service credential을 브라우저에 노출하지 않고 실제 Auth 변경 성공을 server-side에서 검증해야 함 |

---

## D-001 — Canonical Student Identity ≠ Login Identity

### 선택

```text
core.students.id
= canonical student UUID

core.students.auth_user_id
= optional local DICS Core Auth UUID
```

### 배제한 선택

```text
students.id = auth.users.id
```

### 근거

- 초등학생 등 로그인 계정이 없는 학생 존재
- 인증 교체/통합이 학생 PK를 바꾸면 안 됨
- 여러 domain이 동일 학생을 참조해야 함

---

## D-009 — “28/29면 29로 만들어버리지 않는다”

SP pilot identity reconciliation에서:

```text
29 source
28 exact
1 unmatched
0 ambiguous
```

가 확인됐다.

1건을 가장 비슷한 이름에 자동 배정하지 않았다.

결정:

- 28 exact만 운영 Core에 반영
- 1건은 별도 원본 확인 전 pending
- reconciliation에 PIN 미사용

이 규칙은 이후 모든 roster import/mapping에 적용한다.

---

## D-011 — External Auth Namespace

현재:

```text
SP Supabase Project
└─ auth.users.id

DICS Core Supabase Project
└─ auth.users.id
```

는 별도 namespace다.

따라서:

```text
SP external UUID
  ↓
core.external_auth_identities
  ↓
core.students.id
```

로 transition mapping을 보존한다.

학생 계정이 실제 DICS Core Auth에 provision된 뒤에만:

```text
core.students.auth_user_id
→ local auth.users.id
```

를 사용한다.

---

## D-013 / D-014 — Student Number Policy — OPEN

기존 SP pilot ID 예:

```text
0801
0901
1101
```

은 당시:

```text
현재 학년 2자리 + 순번
```

으로 생성됐다.

이 형식은 현재 학년을 직관적으로 알 수 있다는 장점이 있지만,
진급 시 문제가 생긴다.

예:

```text
2026: G8 → 0802
2027: G9 → ?
```

번호를 `090x`로 바꾸면 cross-system stable key가 아니게 된다.

### 검토 중인 선택지 A — 기존 GGNN을 permanent student_no로 유지

장점:
- 현재 사용자 익숙함
- 기존 SP login 유지 쉬움

문제:
- 번호 속 grade가 시간이 지나며 실제 grade와 달라짐
- 번호를 “현재 학년”으로 오해할 가능성

### 선택지 B — GGNN은 legacy/login alias로 보존 + 별도 stable school ID

장점:
- canonical human ID도 장기간 안정
- 기존 SP 로그인 호환 가능

문제:
- 전환기에 식별자가 두 개 존재
- 운영 설명 필요

### 선택지 C — grade-independent 새 번호로 전체 재발급

장점:
- 가장 깨끗한 장기구조

문제:
- 기존 29명 login/배부자료/습관 변경 필요

### 현재 결정

**아직 확정하지 않는다.**

이미 검증된 28개 기존 번호는 운영 Core에 보존하되,
나머지 전교생 번호를 기계적으로 생성하기 전에 school-wide numbering policy를 확정한다.

Canonical UUID는 이미 별도로 존재하므로 이 결정을 서두를 기술적 이유가 없다.


---

## D-016 — Shared Core Migration Ownership

DICS Core가 실제로 다음 schema를 동시에 담기 시작했다.

```text
core.*
discipline.*
study_planner.*
computer_lab.*
```

병렬 작업 중 live migration이 Git보다 먼저 적용되는 drift가 실제로 발생했다.

따라서 현재는 Daniel repo의 `supabase/migrations/`를 임시 ledger로 사용하되,
장기적으로는 별도 `DICS-Core` repository가 중앙 migration ordering과 `core.*`를 소유하도록 한다.

완료 기준은 단순히 production DB가 동작하는 것이 아니라:

> Git migration history만으로 새 환경의 구조를 재현할 수 있는가?

이다.

---

## D-017 — External Identity는 Secure Migration Data

SP의 기존 Auth UUID와 student_no를 Core에 연결해야 하지만,
이 mapping row 자체는 schema가 아니라 **운영 identity data**다.

따라서 다음 방식은 사용하지 않는다.

```text
❌ Git SQL seed에 실제 mapping 작성
❌ GitHub Issue에 UUID/student_no 목록 첨부
❌ PR comment로 실데이터 전달
```

허용되는 방향:

```text
trusted source read
        ↓
verified mapping
        ↓
authenticated/service migration path
        ↓
Core guarded RPC
        ↓
core.external_auth_identities
```

Core RPC는:

- student_no가 실제 Core 학생인지 확인
- external identity가 다른 학생에게 연결되어 있으면 거부
- 한 학생이 같은 source의 다른 identity를 이미 가지면 거부
- 동일 mapping 재실행은 verification timestamp만 갱신

하도록 설계한다.

PIN/password는 이 과정에 참여하지 않는다.


---

## D-018 — Shared Role Account → Individual Account

기존 운영은:

```text
seondo
sasaeng
```

같은 role-centered shared account로 시작했다.

초기 MVP에서는 단순했지만 audit trail이 실제로 필요해지면서 한계가 생겼다.

```text
entered_by_name
= 사람이 입력한 문자열

auth.uid()
= 실제 로그인 actor
```

는 동일한 신뢰수준이 아니다.

따라서 개인계정으로 이동한다.

다만 기존 공유계정을 먼저 삭제하지 않는다.

```text
개인계정 provision
→ 실제 운영 검증
→ 책임범위 확인
→ audit actor 확인
→ 공유계정 비활성화
```

순서로 staged transition 한다.

---

## D-019 — Password Completion은 Client Flag가 아니다

처음 구현에서는 신규 계정이 비밀번호를 바꾼 뒤:

```text
mark_admin_password_changed()
```

RPC로 profile flag를 내리는 구조가 가능했다.

하지만 이렇게 하면 기술적으로는 실제 password change 없이 RPC만 호출해 flag를 우회할 수 있다.

따라서 이 설계를 폐기했다.

최종 구조:

```text
JWT-authenticated Edge Function
  → Supabase Auth password 실제 변경
  → 성공 확인
  → must_change_password = false
```

service credential은 Edge Function에만 존재하고 브라우저에는 노출하지 않는다.

개인 계정 생성도 같은 이유로:

```text
provision-admin-account
```

Edge Function에서만 Auth Admin API를 호출한다.
