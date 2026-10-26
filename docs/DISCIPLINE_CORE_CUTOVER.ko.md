# 생활지도 Core UUID 전환 실행 기록

**Language / 언어:** [English](DISCIPLINE_CORE_CUTOVER.md) | [한국어](DISCIPLINE_CORE_CUTOVER.ko.md)

> 기록상 상태: 완료·검증. 학생 FK를 core.students.id로 통일한 과거 전환의 근거이며 이번 번역 작업에서 새 운영 시험을 실행한 것은 아니다.

## 최종 구조와 호환성

point_records와 punishments는 core_student_id UUID NOT NULL만 저장한다. 두 테이블의 물리 student_id 정수 컬럼은 제거했다. 필요한 기존 숫자는 Core UUID → public.students.core_student_id → public.students.id를 통해 계산한다. 반성문은 reflection_records.point_record_id로 계속 연결된다.

## 운영 상태 조회

```sql
select * from public.v_discipline_core_cutover_status;
```

기록된 결과는 POST_LEGACY_COLUMN_DROP_VERIFIED, legacy_columns_removed=true, cutover_completed=true였다. 점수 1/1 연결·불일치 0, 처분 0/0·불일치 0, 주간·주간 벌점·정산·요약 불일치 모두 0이다.

## A — 쓰기 경로 완료

create_point_record_core(...)와 create_punishment_core(...)가 규칙의 본체다. 정수형 기존 RPC는 UUID를 해석한 뒤 위 함수에 위임한다. 프론트엔드와 부서상점 생성도 UUID만 저장한다.

## B — 과거 기록 완료

삭제 전 점수 총 1·Core 연결 1·불일치 0, 처분 총 0·연결 0·불일치 0을 확인했다. 기존 생활지도 기록의 신원 연결이 먼저 완료됐다.

## C — 조회 완료

학생 상세, 점수 필터, 처분, 반성문, 일일 공지, 주간 점수/이력, 정산, 학생 요약, 보고, 현황판이 내부적으로 UUID를 사용한다. 공개 뷰에 남은 정수는 계산된 호환 값이다.

## D — URL/API 완료

새 링크는 /students/:coreStudentId다. URL 형태를 유지하며 값 의미만 UUID로 바꿨다. 숫자 URL은 기존 조회, UUID URL은 Core 조회로 처리해 과거 즐겨찾기를 보존한다.

## E — 부서상점 완료

core.department_memberships.student_id는 Core 학생 FK다. 자동 상점은 point_records.core_student_id에 쓰며 결정적 source_key가 중복을 막는다.

## F — 반성문 트리거 완료

private.create_reflection_for_penalty()에 남아 있던 new.student_id 학년 조회를 new.core_student_id → public.students.core_student_id → grade로 변경했다. 삭제 후 롤백 시험에서 새 벌점의 반성문 생성이 확인됐다.

## G — 계산 동등성 완료

교체 전 Core 그림자 계산과 기존 계산을 비교했다. 주간 1/1, 주간 벌점 1/1, 정산 0/0, 학생 요약 175/175, 모두 불일치 0이었다. 확인 후에만 안정된 공개 뷰 이름을 Core 구현으로 교체했다.

## 집계 근거 원장

삭제 전 discipline.core_cutover_evidence에 집계만 저장했다. 학생 이름·학번·Auth UUID·개별 연결표는 포함하지 않는다. 그림자 뷰와 컬럼 삭제 후에도 근거가 남는다.

## 삭제 후 롤백 시험

Core/기존 점수 경로의 UUID 일치와 반성문 생성, Core/기존 처분 경로의 UUID 일치를 확인했다. 모든 시험 트랜잭션을 롤백해 운영 기록에 남기지 않았다.

## 보존된 상태

점수 기록 1, 합계 5, 반성문 1, 처분 0, 주간 보고 175행과 현황판 수치가 전후 같았다. 소량 데이터에서의 검증이며 대규모 성능·전체 경우의 무결성을 증명하지는 않는다.

## 의존성과 이관 이력

student_id 문자열 검색은 core_student_id까지 잡으므로 최종 근거로 사용하지 않았다. pg_depend로 실제 물리 의존성을 확인하고 별도 트리거 본문도 검사했다. 운영 이관 버전과 Git 파일명을 일대일로 맞춰 이미 적용된 SQL의 재적용 위험을 줄였다.

## 남은 호환 경계와 중단 조건

public.students.id는 숫자 URL, 전환 도구, 과거 API, 정수 RPC에 남을 수 있으나 생활지도 원본 FK는 아니다. 제거하려면 숫자 ID를 기대하는 현행 화면이 없고, 기존 링크 정책이 있으며, G9 도구가 UUID를 쓰고, 다른 도메인 의존성이 없고, CI와 완료 상태가 유지되고, 복구 전략이 확인되어야 한다.

준비도·불일치 수·커밋·CI·롤백·삭제 전 집계·PostgreSQL 의존성·전후 상태·운영/Git 대조 기록을 보존한다. 이 근거에 학생 개인정보는 필요하지 않다.
