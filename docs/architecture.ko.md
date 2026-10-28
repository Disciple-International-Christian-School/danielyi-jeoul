# 다니엘의 저울 — 초기 아키텍처

**Language / 언어:** [English](architecture.md) | [한국어](architecture.ko.md)

> 2026-10-28 이후의 판정·G9 담당범위는 [현재 생활지도 규칙](DISCIPLINE_RULES.ko.md)을 우선한다. 아래의 이전 설계·기록은 해당 시점의 근거로 보존한다.

> 2026-09-21의 역사적 구조다. 학년 1–6, 직접 입력 작성자, 월간 벌점, 학생 CRUD 등은 이후 변경됐다. 현재 구조는 Core 설계·변경 이력·전환 실행서를 참조한다.

DICS 관리자 전용 상·벌점 콘솔. SEONDO(선도부)와 SASAENG(사생회)만 로그인하며 학생은 로그인하지 않는다. 앱은 https://dics-daniels-scale.netlify.app, 당시 저장소는 shualoalumin/danielyi-jeoul, Supabase는 DICS 조직 daniels-scale(jgrzsfomcwfiukkaqtos, 서울)이었다.

## 당시 상태

Lovable 배포는 코드 추출 불가 UI 참고용, Replit은 한도 도달 후 school.ts·Drizzle 스키마만 무시 폴더에 보존, 현재 저장소는 Vite·supabase-js·PostgreSQL 뷰/RPC/RLS로 재구축했다. Clerk·Express 호스팅·orval·중첩 Git은 제거했다. 당시 main 자동 배포와 두 공유계정을 사용했다.

## Express 제거 판단

이미 동작하던 서버라도 호스트와 인증 교체가 필요했고 단독 유지보수에 두 번째 실행환경은 비용이었다. 읽기 집계와 쓰기 검증은 SQL에 적합했고 SP 운영 모델과 통일되며 학생별 N+1 집계를 뷰로 바꿀 수 있었다. Express 원본은 참고 구현이고 스펙/API 계약을 SQL이 만족해야 했다. Express+Drizzle 유지안은 배제했으나 복잡한 Excel 처리나 pg_cron 범위를 넘는 작업이 필요하면 재검토할 수 있다.

## 구성

React/Vite를 Netlify에 번들 배포한다. 학교망의 CDN 제한을 고려했다. Supabase ID/비밀번호 인증에서 ID는 {id}@scale.dics.kr로 연결하고 admins는 auth.users UUID와 역할을 가진다. 공용 PC를 고려해 sessionStorage를 사용했다. src/lib/api.ts는 뷰 조회·테이블/RPC 쓰기를 담당하며 공개 키만 사용한다.

## 초기 테이블

admins(사용자·역할), students(이름·학년 1–6·논리삭제), point_items(종류·고정 점수·활성), point_records(학생 FK·항목 스냅샷·직접 입력 이름), reflection_records(점수 FK 유일·당일 마감), punishments(기간·위반일). 별도 주간 요약 테이블 없이 원기록에서 계산했다. 이후 학생·작성자 구조가 개선됐다.

## 초기 규칙의 SQL 대응

음수 기록→반성문 트리거, 제출/미제출/2배→v_reflections 계산. 주간 3회 또는 8점 훈련·월간 20점 위원회·주간 5점 처분 필요→요약 뷰. 3주 연속 5점 귀가금지 조건→주간 뷰/윈도. 주간 5/10점 처분 1/2개→RPC. 위반→violated_at. 재량 벌점 1–5→트리거. 상/벌점 원본은 분리했다. 모든 시간은 Asia/Seoul, 주간은 월~일이다.

v_student_summary, v_reflections, v_point_records, v_punishments, v_weekly_penalties, v_dashboard_counts는 security_invoker=true다. 보조 함수는 private에 두어 공개 REST RPC 노출을 막았다.

## 초기 RLS

익명 접근 없음. 인증 사용자도 admins 행이 필요하다. SEONDO는 학생·항목·점수·반성문 쓰기, SASAENG는 처분 쓰기, 두 역할은 조회 가능했다. 삭제 정책 없이 이력을 논리 삭제했다. 이후 더 좁은 범위·읽기 전용 학생 연결표로 발전했다.

## 개인정보와 디렉터리

미성년 명부·점수표·실제 인증정보는 Git에 넣지 않는다. src는 앱, supabase/migrations는 구조, seed.dev.sql은 가상 예시, docs는 설계/이력, _replit은 무시된 원본 참고, _local은 무시된 비공개 엑셀이다.

## 당시 누락과 차이

Express의 UTC 주간/월간을 KST로 바꿨고 누락된 귀가금지 조건·처분 필요 상태를 구현했다. 당시 v1에는 감사로그와 실제 명부 Excel 가져오기가 없었고 point_items CSV만 있었다. 이는 과거 상태이며 현재 완료 여부는 후속 이력을 따른다.
