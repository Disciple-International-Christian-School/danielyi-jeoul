# Study Planner → DICS Core Migration Plan

> **Working cut-over plan · 2026-09-25**
>
> 목적은 기존 SP 운영을 중단시키지 않고, 검증 가능한 단위로 데이터를 DICS Core의 `study_planner.*` target에 이관하는 것이다.
>
> 이 문서는 실제 data copy 전에 dependency order, identity mapping, validation gate, rollback 기준을 명확히 한다.

---

## 1. 현재 구조

### Legacy SP project

```text
public.students.id = SP auth.users.id
public.staff.id    = SP auth.users.id

public.terms
public.weeks
public.time_blocks
public.entry_windows
public.subject_tags
public.term_goals
public.week_plans
public.week_goals
public.plan_items
public.item_records
public.block_records
public.task_templates
public.teacher_comments
```

### DICS Core target

```text
core.students.id
core.academic_terms.id

study_planner.staff.id
study_planner.weeks
study_planner.time_blocks
study_planner.entry_windows
study_planner.subject_tags
study_planner.term_goals
study_planner.week_plans
study_planner.week_goals
study_planner.plan_items
study_planner.item_records
study_planner.block_records
study_planner.task_templates
study_planner.teacher_comments
```

학생 master와 term master는 target에 복제하지 않는다.

---

## 2. Identity contracts

### Student

Source:

```text
SP public.students.id
= external SP Auth UUID
```

Target:

```text
core.students.id
= canonical student UUID
```

Migration bridge:

```text
SP student_no
   ↓ verified mapping
core.students.student_no
   ↓
core.students.id
```

External Auth provenance:

```text
SP auth UUID
   ↓
core.external_auth_identities
   ↓
core.students.id
```

PIN/password는 migration dataset에 포함하지 않는다.

### Staff

Source:

```text
SP public.staff.id
= external SP Auth UUID
```

Target:

```text
study_planner.staff.id
= independent staff profile UUID

study_planner.staff.auth_user_id
= optional LOCAL DICS Core Auth UUID
```

External SP staff Auth:

```text
SP staff Auth UUID
   ↓
study_planner.external_staff_identities
   ↓
study_planner.staff.id
```

---

## 3. Data-copy dependency order

실데이터 이관은 아래 순서를 지킨다.

### Stage A — Preconditions

반드시 통과해야 한다.

- Core student mapping source rows 모두 exact 또는 명시적 pending
- ambiguous mapping = 0
- SP source inventory 확보
- Core target inventory = expected empty/baseline
- current academic term 확인
- production backup/recovery point 확인
- source SP 서비스는 계속 운영

### Stage B — Static/reference tables

먼저 학생별 데이터와 독립적인 설정을 옮긴다.

```text
time_blocks
entry_windows
subject_tags
```

검증:

```text
source count = target count
primary/code uniqueness 유지
```

### Stage C — Academic weeks

Legacy `terms` 자체를 복사하지 않는다.

기존 SP term을 Core `core.academic_terms`에 명시적으로 매핑한 뒤:

```text
weeks
```

를 복사한다.

주의:

- legacy term UUID를 Core term UUID라고 가정하지 않음
- `week_no / monday`을 통해 verified term mapping 사용

### Stage D — Staff profiles

SP staff를:

```text
study_planner.staff
```

에 새 profile UUID로 생성한다.

그 다음 기존 SP Auth UUID는:

```text
study_planner.external_staff_identities
```

에 기록한다.

아직 Core local Auth가 없다면 `auth_user_id = null` 유지.

### Stage E — Student-level roots

학생 mapping이 검증된 학생만:

```text
term_goals
week_plans
task_templates
```

를 복사한다.

source `student_id`는 반드시:

```text
legacy SP student
→ verified core_student_id
```

로 변환한다.

학생 이름으로 join하지 않는다.

### Stage F — Plan children

부모 ID/FK가 준비된 뒤:

```text
week_goals
plan_items
```

를 복사한다.

가능한 경우 source record UUID는 그대로 보존해 migration traceability를 높인다.

### Stage G — Execution records

```text
item_records
block_records
```

를 복사한다.

이 단계는 plan item / week plan parent parity가 100%일 때만 진행한다.

### Stage H — Teacher comments

마지막에:

```text
teacher_comments
```

를 복사한다.

source staff ID를 target staff profile ID로 변환한다.

---

## 4. Validation gates

각 stage 후 다음을 비교한다.

### Count parity

SP source:

```text
public.v_core_migration_inventory
```

Core target:

```text
public.get_study_planner_target_inventory()
```

내용을 노출하지 않고 entity별 row count만 비교한다.

### Referential integrity

모든 migrated record에 대해:

- student FK가 Core 학생을 가리키는가
- week → Core academic term 관계가 맞는가
- week plan parent가 존재하는가
- teacher comment의 target staff가 존재하는가

를 검사한다.

### Sampling

자동 count parity 뒤에도 운영자가 소수의 실제 학생을 UI에서 직접 확인한다.

예:

- 학기목표
- 한 주 계획
- plan item
- 실행 기록
- 교사 comment

이 단계에서 학생 이름 자체를 Git/Issue에 기록하지 않는다.

---

## 5. Cut-over strategy

한 번에 source를 종료하지 않는다.

```text
Phase 1  source SP 계속 운영
         Core target shadow copy

Phase 2  parity/read-only verification

Phase 3  Core-backed preview frontend

Phase 4  selected pilot login/operation

Phase 5  write cut-over

Phase 6  legacy SP DB read-only retention

Phase 7  archival/decommission decision
```

---

## 6. Rollback principle

Cut-over 전에는 source SP가 operational source of truth다.

Target migration 중 문제가 생기면:

- source 데이터 수정 금지
- target batch만 rollback/remove
- mapping table과 error reason 보존
- mapping ambiguity 해결 후 재실행

**source를 target에 맞추기 위해 수정하지 않는다.**

---

## 7. Blockers as of 2026-09-25

- SP live aggregate inventory는 Claude lane에서 조회 대기
- 29 pilot 학생 중 28명 student_no Core 보강 완료
- 1명은 name discrepancy로 pending
- G9-A/B 31명은 section source 대기
- Core local student Auth 0명
- external student Auth mapping 0명
- target Study Planner content rows 0

따라서 현재는 **schema/precondition phase**이며 live SP content copy는 아직 시작하지 않는다.

---

## 8. Completion definition

Study Planner Core migration이 완료되었다고 부를 수 있는 기준:

```text
verified student mapping for all migrated SP students
source ↔ target count parity
referential integrity checks pass
sample UI verification pass
Core local/external Auth strategy verified
no PIN/password copied
production frontend uses Core student UUID
legacy SP writes disabled only after successful pilot
```

이 완료선 이전에는 “통합 완료”라고 표현하지 않는다.
