# SP 외부 인증 신원 이관 규약

**Language / 언어:** [English](SP_IDENTITY_MIGRATION_PROTOCOL.md) | [한국어](SP_IDENTITY_MIGRATION_PROTOCOL.ko.md)

기존 Study Planner 로그인과 정규 Core 학생을 안전하게 연결한다. 실제 연결표·PIN·서비스 키를 Git에 넣지 않는다.

## 옮기는 것

SP public.students.id(외부 인증 UUID), student_no(기존 로그인 번호), Core core.students.id(정규 UUID)의 참조 관계만 처리한다. 결과는 core.external_auth_identities에 기록하고 SP public.students.core_student_id에도 정규 UUID를 쓴다.

## 옮기지 않는 것

PIN·비밀번호·이메일·학생 이름·생년월일·학부모·임의 프로필은 읽거나 옮기지 않는다. 실행기는 SP id/student_no/core_student_id와 Core id/student_no만 조회한다.

## 사전 조건

SP 연결 컬럼 이관 적용, 대상 학생의 검증된 Core 학번, T01–T05·DEV1 비학생 계정의 명시적 제외, 신뢰 실행환경의 서비스 키가 필요하다. 키를 이슈·PR·파일에 붙여 넣지 않는다.

## 환경변수

SP_SUPABASE_URL, SP_SUPABASE_SERVICE_ROLE_KEY, CORE_SUPABASE_URL, CORE_SUPABASE_SERVICE_ROLE_KEY를 로컬 또는 신뢰 비밀 저장소에 설정한다. SP_PROJECT_REF는 선택이다. .env와 .env.*를 커밋하지 않는다.

## 1단계 — 사전 모의 실행

`npm run migrate:sp-identities`의 기본값은 DRY RUN이다. 원본·제외·실학생·Core 학번 보유·정확 일치·미일치·기존 정상 연결·충돌 건수만 출력한다. 실제 학번·Auth UUID·Core UUID는 출력하지 않는다.

## 즉시 중단 조건

SP 또는 Core 학번 중복, 기존 SP 연결의 다른 학생 지시, 외부 Auth의 다른 학생 연결, 같은 Core 학생의 다른 SP Auth 연결이 있으면 쓰기 전에 중단한다. 사람이 원인을 확인한다.

## 2단계 — 반영

집계 결과 검토 후 `npm run migrate:sp-identities -- --apply`를 실행한다. Core 외부 연결표 → SP core_student_id 순으로 쓴다. 서로 다른 DB는 단일 트랜잭션으로 묶을 수 없어 한쪽만 앞설 수 있다. 따라서 동일 작업을 재실행해도 안전하도록 멱등성을 보장한다.

## 3단계 — 확인

실학생·일치·미일치·외부 연결·원본 연결 완료 수와 충돌 0을 집계로만 남긴다. 실제 행을 Git이나 조정 이슈에 쓰지 않는다.

## 수작업 복사 대신 실행기를 쓰는 이유

사람·계정 혼동, 개인정보 유출, 재현 불가, 충돌 검증 누락을 줄인다. 운영 신원 값은 버전관리 밖에 둔다.

## 최초 대상의 과거 상태

실학생 29, 정확 일치 28, 미해결 1, 모호 0이었다. 미해결 행은 원본 신원 확인 전까지 보류하며 첫 반영은 정확 일치 집단에 한정한다.
