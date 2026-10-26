# 다니엘의 저울

**Language / 언어:** [English](README.md) | [한국어](README.ko.md)

**DICS — 제자국제크리스천학교**의 내부 생활지도 운영 콘솔이다. 관리자가 상·벌점, 반성문 제출, 사생회 처분, 반별 공지, 주간·정산기간 후속 업무를 관리한다. 학생은 이 앱에 로그인하지 않는다.

[프로젝트 사례 연구](docs/PROJECT_CASE_STUDY.ko.md) · [문서 목차](docs/README.ko.md) · [핵심 이슈](docs/KEY_ISSUES.ko.md) · [개발 일지](docs/DEVELOPMENT_JOURNAL.ko.md)

**앱:** https://dics-daniels-scale.netlify.app

## 학교 업무에서 공통 학생 신원으로

종이 벌점표를 전산화하면서 시작했다. 학습·학교 서비스 앱을 연결하는 과정에서 같은 학생을 앱마다 다르게 식별한다는 문제가 드러났다. DICS Core는 영구 학생 UUID와 로그인 계정·학기별 소속을 분리한다.

이 저장소는 프로토타입에서 DB 규칙 강제, 인증된 감사 주체, 단계적 UUID 이관, 동등성 검사, 이관 원장으로 발전한 과정을 기록한다. [사례 연구](docs/PROJECT_CASE_STUDY.ko.md)는 과거 근거와 한계를 구분하며 계획·당시 운영 수치·완료된 구현을 별도로 설명한다.

## 읽는 순서

| 독자 | 시작 문서 |
| --- | --- |
| 학교 운영자 | [운영 로드맵](docs/OPERATIONS_ROADMAP.ko.md), [개인 관리자 계정](docs/ADMIN_ACCOUNT_OPERATIONS.ko.md) |
| 기술 검토자 | [Core 구조](docs/DICS_CORE_ARCHITECTURE.ko.md), [설계 판단](docs/DECISIONS.ko.md), [UUID 전환](docs/DISCIPLINE_CORE_CUTOVER.ko.md) |
| EC 검토자 | [사례 연구](docs/PROJECT_CASE_STUDY.ko.md), [개발 일지](docs/DEVELOPMENT_JOURNAL.ko.md), [변경 이력](docs/CHANGELOG.ko.md) |
| 유지보수자 | [배포](docs/netlify-deployment.ko.md), [이관 관리](docs/CORE_MIGRATION_GOVERNANCE.ko.md), [언어 정책](docs/DOCUMENTATION_POLICY.ko.md) |

모든 유지 문서는 영어 기본판과 한국어판을 갖고 상단 링크로 이동한다. 과거 첨부와 번역 자료도 문서 목차에서 찾을 수 있다.

## 로컬 개발

```bash
cp .env.example .env
# VITE_SUPABASE_URL과 VITE_SUPABASE_ANON_KEY를 설정한다.
npm ci
npm run dev
```

React 19·Vite·supabase-js를 사용한다. PostgreSQL 뷰/RPC/트리거가 업무 규칙을, RLS가 권한을 강제한다. 기존 seondo/sasaeng ID는 {login_id}@scale.dics.kr로 연결한다. 개인계정 실제 보급은 학교 확인이 필요하며 계정 운영서를 따른다.

## 근거 있는 프로젝트 제출

개발 기록에는 Lovable·Replit·Cursor·Claude Code·GPT 지원 작업이 포함된다. EC 제출 시 지원자의 실제 판단·구현을 특정 PR/커밋으로 설명하고 저장소 전체의 단독 저작이나 측정하지 않은 효과를 주장하지 않는다.

가상 예시와 집계 결과를 사용한다. 브라우저 서비스 키, 실제 명부·PIN·인증정보·연결표를 Git에 두지 않는다. 과거 인증정보 안내는 빈 양식으로 대체했으나 접근 공유 전 Owner가 과거 Git 객체와 인증정보 유효성을 확인해야 한다. 저장소 공개 여부는 Owner가 결정하며 현재 비공개다.
