# 다니엘의 저울

DICS 학생 상점·벌점 관리 콘솔. 관리자 전용 (선도부 / 사생회). 학생은 로그인하지 않는다.

**앱:** https://dics-daniels-scale.netlify.app

## 문서

- [초기 구축 기록 — Legacy](docs/LEGACY_INITIAL_BUILD.md)
- [현재 이후 변경 이력 — Change Log](docs/CHANGELOG.md)
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

Vite + React + supabase-js. 비즈니스 룰은 Postgres 뷰·트리거·RPC, 권한은 RLS. Netlify가 `main`을 배포한다. `service_role` 키는 클라이언트에 넣지 않는다.

명단 엑셀은 `_local/`에 두며 git에 올리지 않는다. Replit 덤프는 `_replit/`에 `school.ts`와 Drizzle 스키마만 남겨 두었다.
