import { Link, useParams } from 'wouter';

// Deliberately not StudentSummary objects: these fictional fixtures must never
// enter CORE UUID writes, official counts, reports, or the roster bridge.
export const TEST_PROFILES = [
  { slug: 'amalek-elementary', name: '아말렉초G0', grade: 'G0', school: '초등용' },
  { slug: 'amalek-secondary', name: '아말렉고G13', grade: 'G13', school: '중고등용' },
] as const;

export function findTestProfiles(search: string) {
  const needle = search.trim().normalize('NFKC').toLowerCase();
  return TEST_PROFILES.filter(profile =>
    `${profile.name} ${profile.grade} ${profile.school} 테스트`.normalize('NFKC').toLowerCase().includes(needle));
}

export function TestProfileResults({ search }: { search: string }) {
  const profiles = findTestProfiles(search);
  if (!profiles.length) return null;
  return <section className="card card-pad" style={{ marginTop: 18 }} aria-label="다니엘 전용 테스트 인물" data-testid="test-profile-results">
    <h2 className="section-title">테스트 인물 <span className="muted">{profiles.length}명</span></h2>
    <p className="section-copy">다니엘 사이트 전용 가상 인물입니다. DICS 명부와 공식 집계에 포함되지 않습니다.</p>
    <div className="activity-list">{profiles.map(profile => <Link
      key={profile.slug} href={'/test-profiles/' + profile.slug}
      className="activity-row" data-testid={'link-test-' + profile.slug}
    ><strong>{profile.name}</strong><span className="pill pill-neutral">{profile.school} · 테스트</span></Link>)}</div>
  </section>;
}

export function TestProfilePage() {
  const { slug } = useParams<{ slug: string }>();
  const profile = TEST_PROFILES.find(item => item.slug === slug);
  return <div>
    <Link href="/students" className="btn btn-outline">학생 검색으로 돌아가기</Link>
    {profile ? <section className="card card-pad" style={{ marginTop: 24 }}>
      <div className="eyebrow">다니엘 사이트 전용 · 가상 테스트 인물</div>
      <h1 className="heading">{profile.name}</h1>
      <p className="subheading">{profile.school} · {profile.grade}</p>
      <p>검색 및 프로필 확인용 테스트 인물입니다. 실제 학생 계정이나 DICS 명부 항목이 아닙니다.</p>
      <div className="side-note">현재는 검색·프로필 확인을 지원합니다. 상벌점 저장, 반성문, 체력훈련 및 정산 시뮬레이션은 아직 연결되지 않았습니다.</div>
    </section> : <p role="alert">테스트 인물을 찾을 수 없습니다.</p>}
  </div>;
}
