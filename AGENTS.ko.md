# 에이전트 지침 — Daniel's Scale

**Language / 언어:** [English](AGENTS.md) | [한국어](AGENTS.ko.md)

DICS의 상점·벌점·선도 업무 흐름을 다루는 저장소입니다. `README.ko.md`, `docs/DECISIONS.ko.md`, `docs/IMPLEMENTATION_TODO.ko.md`부터 읽습니다. 이 저장소의 문서는 영어·한국어 두 판으로 관리하며 `npm run check:docs`로 검사합니다. `docs/DOCUMENTATION_POLICY.ko.md`를 따르고, 커밋 메시지는 영어로만 씁니다.

## DICS 조직 계약

이 저장소는 DICS Student 360° Growth OS의 한 구성 요소입니다. 전체 최신 내용은 `dics-core` 저장소의 `docs/architecture/`에 있습니다:
[조직 아키텍처](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/ORG_ARCHITECTURE.md),
[CORE 계약](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/CORE_CONTRACT.md),
[통합 레지스트리](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/INTEGRATION_REGISTRY.md),
[마이그레이션 원장](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/MIGRATION_LEDGER.md),
[로드맵과 미결 작업 원장](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/STUDENT_360_ROADMAP.md),
[에이전트 협업](https://github.com/Disciple-International-Christian-School/dics-core/blob/main/docs/architecture/AGENT_COORDINATION.md).
세션을 시작할 때 읽습니다. 세션에서 `dics-core`를 볼 수 없는데 작업이 신원, 인증, 명단, 공유 데이터베이스에 닿는다면 먼저 접근 권한을 확보합니다. 아래 규칙은 모든 에이전트에게 항상 적용되는 요약입니다.

1. 학생 한 명은 공유 CORE Supabase 프로젝트 `jgrzsfomcwfiukkaqtos`의 `core.students.id`(UUID) 하나를 가집니다. 학생 마스터, PIN 테이블, 앱 전용 학생 ID를 만들지 않습니다.
2. 학생은 그 프로젝트의 공유 Auth에 학번과 6자리 PIN으로 로그인합니다. 서버에서 `auth.uid()`를 CORE UUID로 변환합니다. 클라이언트가 보낸 학생 UUID, 학번, 이름을 소유 증명으로 받아들이지 않습니다.
3. 학생 소유 기록은 CORE UUID를 참조합니다. 이름과 학번은 표시용 값이지 키가 아닙니다. 저장해 둔 이름, 학번, 학년 사본은 그 시점의 스냅샷이지 명단이 아닙니다.
4. 신원, 명단, 재적, 학년, 반은 CORE가 소유합니다. 이 앱은 자기 도메인 데이터만 소유하고 CORE 명단 테이블에 쓰지 않습니다.
5. 데이터베이스는 스테이징 사본이 없는 공유 운영 환경입니다. 스키마를 바꾸기 전에 실제 적용된 마이그레이션 목록과 마이그레이션 원장을 확인합니다. 마이그레이션은 그 스키마를 소유한 저장소에 두고, 파일 이름은 실제 기록된 버전으로 하며, 롤백되는 트랜잭션에서 먼저 시험하고, 이미 적용된 마이그레이션은 고치지 않습니다. `core.*`나 다른 앱의 스키마를 바꾸는 일은 `dics-core`를 거칩니다.
6. 모든 테이블에 행 수준 보안을 적용하고, 최소 권한을 지키며, service-role 키를 브라우저에 두지 않습니다. 신원을 공유한다고 접근 권한까지 공유하는 것은 아닙니다.
7. 학생 이름, PIN, 명단 데이터, 인증 정보를 커밋하거나 게시하지 않습니다. 학생 기록, 계정, 인증 정보, 권한을 바꾸려면 그 작업에 대한 Josh의 승인이 필요합니다.
8. 기준의 순서는 실제 운영 상태, `dics-core/docs/architecture/`, 이 저장소의 인계 문서, 에이전트 메모리입니다. 주장하기 전에 확인합니다. 작업을 마치면 이 저장소의 인계 문서를 갱신하고, 통합 상태가 바뀌었다면 `dics-core`의 레지스트리 행도 갱신합니다.
9. Josh에게는 한국어로 설명합니다. 커밋, PR 제목, 문서는 영어로 씁니다.

### 2026-11-15 KST 기준 레지스트리 상태

VERIFIED INTEGRATED. 상벌점 기록은 CORE UUID를 참조하며 UUID가 없는 기록은 없습니다. 이 저장소는 공개 저장소입니다. 공개되면 안 되는 내용은 여기에 쓰지 않습니다. 공유 데이터베이스가 이 저장소에서 시작되었기 때문에 적용된 마이그레이션 99개 중 72개가 여기에 있습니다. 전체 목록은 `dics-core`의 마이그레이션 원장입니다. 이 저장소와 관련된 조직 미결 항목: ORG-11(CORE의 교직원 읽기 정책이 이 앱의 역할 헬퍼에 의존), ORG-13(이 저장소의 임시 원장은 이 저장소의 마이그레이션만 포함), ORG-15(`public`의 definer RPC).
