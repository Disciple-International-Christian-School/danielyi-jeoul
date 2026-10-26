# Netlify 배포 연결

**Language / 언어:** [English](netlify-deployment.md) | [한국어](netlify-deployment.ko.md)

Organization의 비공개 저장소를 Netlify 자체 Git 빌드에 연결하려고 하면 현재 팀의 무료 플랜에서 Pro 업그레이드가 요구됩니다. 2026-10-04 Netlify UI에서 직접 확인했으며 유료 전환은 하지 않았습니다.

이 프로젝트의 배포 경로는 **GitHub Actions → Netlify CLI → 기존 Netlify 사이트**입니다. 저장소는 비공개 Organization에 두고 사이트 주소와 기존 production 환경변수를 유지합니다.

- 저장소: `Disciple-International-Christian-School/danielyi-jeoul`
- 기존 site ID: `df6ae713-42c1-4e56-bb5a-e134553fcb24`
- 워크플로: `.github/workflows/netlify-deploy.yml`
- CLI: `27.10.2` 고정. npm 의존성과 CLI 설치가 끝난 뒤 배포 단계에만 토큰을 전달합니다.
- main의 앱·빌드 파일 변경으로 실행하며 Actions의 Run workflow로도 실행할 수 있습니다.
- PR에서는 검증만 실행합니다. 토큰을 읽거나 배포하지 않습니다.
- 동일 브랜치 실행은 순서대로 진행하며 진행 중 배포를 취소하지 않습니다.

## 최초 연결

1. 이 저장소의 Settings → Secrets and variables → Actions에 `NETLIFY_AUTH_TOKEN` repository secret을 저장합니다. 토큰을 코드·문서·채팅에 넣지 않습니다.
2. PR 검증이 성공한 뒤 main으로 병합합니다.
3. Actions에서 검증과 실제 배포 성공을 확인합니다.
4. Actions 배포 로그의 deploy ID를 Netlify에서 조회해 production ready와 대상 site ID를 확인합니다.
5. 운영 화면을 확인한 뒤 Netlify의 기존 개인 Git 주소 연결에서 Git 빌드를 중지하여 중복 배포를 방지합니다. 사이트 자체를 삭제하지 않습니다.

토큰이 없으면 배포 전에 명확한 오류로 중단합니다. 설정 파일 병합이나 CI 성공만으로 배포가 완료됐다고 판단하지 않습니다.

## 빌드와 환경변수

CLI의 `deploy --prod --context=production`은 기존 `netlify.toml`을 읽고 production 설정으로 빌드한 뒤 `dist`만 게시합니다. 저장소 루트, 문서, SQL, 명부를 공개 폴더로 게시하지 않습니다.

`VITE_SUPABASE_URL`과 `VITE_SUPABASE_ANON_KEY`는 기존 Netlify production 환경변수를 사용합니다. 클라이언트에는 publishable/anon 키만 허용하며 service_role 키를 넣지 않습니다. 이 변경은 DB 마이그레이션을 적용하지 않습니다.

## 검증 범위

PR에서 `npm ci`, `npm run typecheck`, `npm run build`를 실행합니다. 운영 Netlify 환경변수·Functions·배포 인증의 유효성은 토큰 등록 후 실제 배포로 확인해야 합니다.

공식 CLI 문서: https://cli.netlify.com/commands/deploy/
