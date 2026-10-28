# Legacy Initial Build — 다니엘의 저울

**Language / 언어:** [English](LEGACY_INITIAL_BUILD.md) | [한국어](LEGACY_INITIAL_BUILD.ko.md)

DICS 상·벌점 관리 콘솔.
학생은 로그인하지 않는다. 관리자 역할은 선도부(`SEONDO`)와 사생회(`SASAENG`) 두 개.

> **FROZEN LEGACY DOCUMENT — 2026-09-21**
>
> 이 문서는 Lovable → Replit → Cursor → Supabase/Netlify로 이어진 **초기 구축 과정의 역사 기록**이다.
> 2026-09-21 이후의 기능 개선, 정책 변경, GPT 작업, Cursor 재작업은 이 파일에 추가하지 않는다.
> 이후 변경 과정은 [CHANGELOG.md](./CHANGELOG.ko.md)에 기록한다.
>
> 당시 설계 결정은 [architecture.md](./architecture.ko.md), 원본 규칙은 [spec.md](./spec.ko.md).

이 문서는 **초기 운영 프로토타입이 만들어지기까지 어떻게 왔는지**를 보존한다.

---

## 지금 돌아가는 것

| | |
|---|---|
| 앱 | https://dics-daniels-scale.netlify.app |
| GitHub | https://github.com/shualoalumin/danielyi-jeoul (`main`, public) |
| Supabase | DICS org · 프로젝트 `daniels-scale` · ref `jgrzsfomcwfiukkaqtos` · Seoul |
| 로그인 | 아이디 `seondo` / `sasaeng` → `{id}@scale.dics.kr` |
| 로컬 개발 | `.env.example`을 `.env`로 복사 후 `npm install && npm run dev` |

`main`에 푸시하면 Netlify가 다시 빌드한다. Vite는 빌드 시점에 `VITE_SUPABASE_*`를 넣으므로, 키를 바꾸면 재배포가 필요하다.

---

## 연표

### 1. Lovable 목업

화면을 Lovable에서 먼저 만들었다. 배포본은 아직 살아 있다.

- https://pixel-perfect-match-0249.lovable.app/dashboard
- `/students` `/reflections` `/punishments` `/penalty-items`

코드 추출이 안 돼서 이 주소는 **UI 레퍼런스**로만 쓴다.

### 2. Replit에서 다시 빌드하다 limit

같은 앱을 Replit에서 풀스택으로 다시 짰다. Drizzle 스키마, Express API, OpenAPI/orval 클라이언트, React 화면 8개가 나왔다. Auth는 Replit 기본값인 Clerk.

Limit에 걸려 중단. 그때까지 나온 파일을 이 워크스페이스로 가져왔다. 포팅이 끝난 뒤 덤프는 `_replit/`에 **원본 두 개만** 남겼다 (`school.ts`, Drizzle `schema/`). git에 안 올림.

스펙 원문은 Replit `attached_assets/`에 35개 섹션짜리 프롬프트로 들어 있었고, 그걸 정리한 것이 `docs/spec.md`다.

### 3. 아키텍처 결정 (2026-09-18)

Express를 호스팅하지 않기로 했다.

- Clerk도, Express도 바꿔야 했음
- 비즈니스 룰이 전부 “읽기 집계” 또는 “쓰기 검증” → 뷰 / 트리거 / RPC로 옮길 수 있음
- 이미 운영 중인 SP Manager와 같은 모델 (Supabase + RLS + Netlify)

버린 선택: Supabase를 Postgres 호스트로만 쓰고 Express+Drizzle 유지.

### 4. 리포 정리와 프론트 포팅 (2026-09-18)

목표 리포는 원래 https://github.com/hylen707/daniels-scale 이었으나, 이 머신 `gh`는 `shualoalumin`이라 푸시가 막혔다. 로컬에 커밋만 쌓아 뒀다.

그 사이:

- Clerk → Supabase Auth (아이디+비밀번호, `sessionStorage`)
- orval REST 클라이언트 → `src/lib/api.ts`
- 마이그레이션 SQL 작성 (`schema` / `logic` / `rls`) + 가상 seed

NextSnap 조직은 무료 슬롯이 가득 차서 프로젝트 생성은 못 했다.

### 5. 로컬 작업 유실과 복구 (2026-09-21)

zip을 다시 풀면서 로컬 커밋 3개가 사라졌다. GitHub에는 한 번도 안 올라가 있었다. 이전 세션 대화 기록에서 파일 내용을 복구했다.

같은 날 빈 리포 https://github.com/shualoalumin/danielyi-jeoul 가 origin이 됐고, 여기는 푸시가 됐다.

### 6. GitHub + Netlify (2026-09-21)

- 사이트: `dics-daniels-scale`
- `netlify.toml` SPA rewrite (`/*` → `index.html`)
- GitHub deploy key로 `main` 자동 배포

이 시점엔 Supabase 키가 없어서 앱은 “환경변수 없음” 안내만 보였다.

### 7. DICS 조직에 프로젝트 (2026-09-21)

무료 한도를 비우려고 [dics-placement-test-dev](https://supabase.com/dashboard/project/qghstnfqbvacesarbmzv)를 pause (`INACTIVE`).

DICS org에 `daniels-scale` 생성 (`ap-northeast-2`, $0/월). 마이그레이션 적용, 가상 학생/항목 seed, Netlify에 `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` 넣고 재배포.

Auth 유저 두 명을 대시보드에서 만든 뒤 `admins`에 역할을 붙였다.

| 아이디 | email | 역할 |
|---|---|---|
| seondo | seondo@scale.dics.kr | 선도부 |
| sasaeng | sasaeng@scale.dics.kr | 사생회 |

Confirm email은 꺼 둔 상태여야 바로 로그인된다.

---

## 폴더가 이렇게 된 이유

| 경로 | git | 역할 |
|---|---|---|
| `src/` | 커밋 | 운영 앱 |
| `supabase/` | 커밋 | 스키마 소스. 원격에 적용한 SQL의 원본 |
| `docs/` | 커밋 | spec / architecture / 이 파일 |
| `_replit/` | 무시 | 포팅 원본만. `school.ts` + Drizzle `schema/` (`audit-logs`는 아직 미구현) |
| `_local/` | 무시 | 명단·엑셀. 미성년 개인정보. 절대 푸시하지 않음 |
| `.env` | 무시 | 로컬 키. 예시는 `.env.example` |

루트에 `danielyi-jeoul/`이 중첩돼 있던 것은 `_replit/`로 바꿨다가, Clerk·orval·중첩 git·node_modules는 지우고 원본 두 개만 남겼다.

원래 만들려던 `hylen707/daniels-scale` 리포는 비어 있다. 운영 원본은 `shualoalumin/danielyi-jeoul`이다.

---

## 원격에만 있고 이 폴더 SQL과 다른 것

마이그레이션 파일 세 장(`schema` / `logic` / `rls`)이 소스다. 적용 직후 MCP로 넣은 추가분:

- 가상 seed (`seed.dev.sql`과 동일 내용)
- `admins` 역할 연결 (이메일로 lookup — UUID를 파일에 안 넣음)
- 함수 `search_path` 고정 + RPC `GRANT` → `20260921000004_function_grants_search_path.sql`

프로덕션 데이터를 리셋하면 `seed.dev.sql`을 다시 넣고, Auth 유저를 만든 다음 `admins`를 email로 다시 연결하면 된다.

---

## 아직 안 한 것

- 실제 학생 명단 Excel 가져오기 (`_local/student-roster-26Fall.xlsx`). 지금은 seed 가상 4명
- 벌점 항목 고정 점수 설정 (spec: 처음 세 항목은 관리자가 나중에 넣음)
- 감사 로그 (spec §31)
- 커스텀 도메인
- `hylen707/daniels-scale` 동기화 여부 — 필요하면 그때 미러
