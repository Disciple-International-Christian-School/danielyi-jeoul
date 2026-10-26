# 다니엘의 저울

**언어 / Language:** [한국어](README.md) | [English](README.en.md)

DICS 학생 상점·벌점 관리 콘솔. 관리자 전용 (선도부 / 사생회). 학생은 로그인하지 않는다.

**앱:** https://dics-daniels-scale.netlify.app

## 시작하기

- [문서 목차 (한국어)](docs/README.md) · [Documentation index (English)](docs/README.en.md)
- [핵심 이슈 및 확인사항 (한국어)](docs/KEY_ISSUES.md) · [Key issues (English)](docs/KEY_ISSUES.en.md)

대표 README, 문서 목차, 핵심 이슈 요약은 한국어와 영어를 선택해서 볼 수 있습니다. 기존 상세 기술 문서는 원문 언어 그대로 유지됩니다.

## 문서

- [Organization 무료 Netlify 배포 연결](docs/netlify-deployment.md)

- [초기 구축 기록 — Legacy](docs/LEGACY_INITIAL_BUILD.md)
- [현재 이후 변경 이력 — Change Log](docs/CHANGELOG.md)
- [운영 개선 로드맵](docs/OPERATIONS_ROADMAP.md)
- [개발 서사 / Development Journal](docs/DEVELOPMENT_JOURNAL.md)
- [Architecture Decision Log](docs/DECISIONS.md)
- [DICS Core 통합 스키마](docs/DICS_CORE_ARCHITECTURE.md)
- [Core Migration Governance](docs/CORE_MIGRATION_GOVERNANCE.md)
- [SP → DICS Core Migration Runbook](docs/SP_CORE_MIGRATION_RUNBOOK.md)
- [Discipline Core UUID Cut-over](docs/DISCIPLINE_CORE_CUTOVER.md)
- [개인 관리자 계정 운영 Runbook](docs/ADMIN_ACCOUNT_OPERATIONS.md)
- [아키텍처](docs/architecture.md)
- [원본 스펙 (35절)](docs/spec.md)

## 로컬

```bash
cp .env.example .env   # VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY
npm install
npm run dev
```

로그인 아이디는 `seondo` (선도부) 또는 `sasaeng` (사생회). `{아이디}@scale.dics.kr`로 매핑된다.

## 스택

Vite + React + supabase-js. 비즈니스 룰은 Postgres 뷰·트리거·RPC, 권한은 RLS. Organization 무료 배포용 GitHub Actions·Netlify CLI 설정은 [배포 연결 문서](docs/netlify-deployment.md)를 따른다. `service_role` 키는 클라이언트에 넣지 않는다.

명단 엑셀은 `_local/`에 두며 git에 올리지 않는다. Replit 덤프는 `_replit/`에 `school.ts`와 Drizzle 스키마만 남겨 두었다.
