# 영어 커밋 이력 — Owner 실행 절차

**Language / 언어:** [English](HISTORY_MAINTENANCE.md) | [한국어](HISTORY_MAINTENANCE.ko.md)

## 준비 결과

main의 537b3dbbb728f5aa76efd07b7b8a1bf08e9a541a에서 접근 가능한 280개 커밋을 검사해 한국어 메시지 7개를 찾았다. 대응표에는 각 제목·본문의 영어 번역이 있다. 새 문서 커밋은 영어다.

scripts/prepare-english-history.py는 기본 모의 실행이다. --apply를 주어도 새 로컬 review 브랜치만 만든다. 파일 트리·부모 순서·작성자/커미터의 이름·이메일·시각과 수정하지 않는 메시지는 보존한다. 바뀐 커밋의 서명은 유효할 수 없어 서명/mergetag 헤더를 제거한다. 영향 없는 조상 해시는 유지한다. 얕은 복제·누락 번역·기존 미리보기 브랜치·review 밖 대상은 거부한다.

문서 PR은 기존 main 이력을 바꾸지 않는다. 현재 GitHub 커밋 생성 연결 도구는 과거 작성자·시각 지정 기능이 없어 그대로 재생성하면 기여 정보가 바뀐다. Owner용 도구는 이를 보존하며 가상 병합 그래프로 검증했다. 실제 반영 전 인증된 전체 복제에서도 확인한다.

## 문서 PR 검토 후 준비

```bash
git fetch origin
git switch main
git pull --ff-only
python3 scripts/prepare-english-history.py
python3 scripts/prepare-english-history.py --apply
git diff --exit-code main review/english-commit-history
git log review/english-commit-history --format=fuller
```

번역·기여자/날짜·그래프·동일 트리를 검토한다. 새 한국어 메시지가 있으면 대응표에 검증된 번역을 추가한다. 원하면 main 대신 미리보기만 원격에 올린다.

```bash
git push origin review/english-commit-history
```

## 공동 main 교체

일반 PR 병합은 과거 메시지를 제거하지 못한다. Owner가 공동 작업자와 일정을 조정하고 예상 main SHA·백업을 확보한 뒤 조건부 강제 갱신해야 한다. 다른 브랜치·태그에 남은 이력은 별도 범위다. 정확한 명령은 영어판에 있다.

파일 차이 검사는 트리가 같은 새 원격 커밋을 놓칠 수 있으므로 도구가 출력한 source_head와 현재 원격 SHA가 정확히 같은지도 확인한다. 다르면 중단하고 다시 준비한다. 무조건 --force는 사용하지 않는다. 작업자는 이후 로컬 브랜치 재정렬이 필요하고 과거 해시 참조·서명도 검토한다.

메시지 번역은 민감 파일의 과거 복사본 삭제가 아니다. 인증정보 교체와 승인된 데이터 이력 정리는 별도다. 백업 브랜치에도 과거 객체가 남으므로 접근을 통제한다.
