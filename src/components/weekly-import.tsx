import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { Link } from 'wouter';
import { useCoreSetupStatus, useDisciplineHistory, useDisciplineImportStatus, useImportDisciplineWeekly } from '@/lib/api';
import { parseWeeklyWorkbook, type WeeklyPreview } from '@/lib/weekly-import';

export function WeeklyImportPage() {
  const cache = useQueryClient();
  const status = useDisciplineImportStatus();
  const term = useCoreSetupStatus();
  const history = useDisciplineHistory(term.data?.startsOn ?? '', term.data?.endsOn ?? '');
  const importer = useImportDisciplineWeekly();
  const [preview, setPreview] = useState<WeeklyPreview | null>(null);
  const [fileName, setFileName] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [confirmed, setConfirmed] = useState(false);
  const unmatched = preview?.rows.filter(r => !status.data?.aliases.some(a => a.source_name === r.source_name && a.grade === r.grade && a.section === r.section)
    && !history.data?.students.some(s => s.name === r.source_name && s.grade === r.grade && s.homeroom === `G${r.grade}${r.section ? '-'+r.section : ''}`)) ?? [];
  const unmatchedNames = [...new Set(unmatched.map(r => `G${r.grade}${r.section ? '-'+r.section : ''} ${r.source_name}`))];
  const read = async (file?: File) => {
    if (!file || !status.data?.settings) return;
    setPreview(null); setError(''); setConfirmed(false); importer.reset(); setLoading(true); setFileName(file.name);
    try {
      if (file.size > 10 * 1024 * 1024) throw new Error('10MB 이하의 .xlsx 파일을 선택해주세요.');
      const { default: readExcel } = await import('read-excel-file/browser');
      const sheets = await readExcel(file);
      setPreview(parseWeeklyWorkbook(sheets, status.data.settings.daily_starts_on));
    } catch (e) { setError(e instanceof Error ? e.message : '파일을 읽지 못했습니다.'); }
    finally { setLoading(false); }
  };
  return <div>
    <Link className="btn btn-outline" href="/dashboard">대시보드</Link>
    <h1 className="heading" style={{ marginTop: 24 }}>주간 확정 원장</h1>
    <p className="subheading">전환일 이전의 주차 전체를 가져옵니다. 수정 전 원본과 이관 이력은 보존됩니다.</p>
    {status.error && <p role="alert">{status.error.message}</p>}
    {status.isLoading && <p role="status">이관 설정을 확인하는 중입니다.</p>}
    {status.data && !status.data.settings && <p>현재 학기의 이관 설정이 없습니다.</p>}
    {status.data?.settings && <section className="card card-pad" style={{ marginTop: 24 }}>
      <p>일별 입력 시작: <strong>{status.data.settings.daily_starts_on}</strong> · 그 이전 주차만 이관</p>
      <label htmlFor="weekly-file">주간 시트 파일 (.xlsx)</label>
      <input id="weekly-file" className="input" type="file" accept=".xlsx" disabled={loading || importer.isPending} onChange={e => { void read(e.target.files?.[0]); }} />
      {loading && <p role="status">파일을 검증하는 중입니다.</p>}
      {(error || importer.error) && <p className="danger-text" role="alert">{error || importer.error?.message}</p>}
      {preview && <>
        <h2 className="section-title" style={{ marginTop: 24 }}>이관 미리보기</h2>
        <p>{preview.weeks.length}주 · 원본 {preview.rows.length}행 · CORE 연결 확인 필요 {unmatchedNames.length}명</p>
        {unmatchedNames.length > 0 && <p className="section-copy">연결 확인 필요: {unmatchedNames.join(', ')}. 원본은 보존하며 연결되기 전에는 학생 누계에 넣지 않습니다.</p>}
        <div className="table-wrap"><table className="data-table"><thead><tr><th>주차</th><th>원본 행</th><th>중복 통합 후</th><th>상점</th><th>벌점</th></tr></thead><tbody>{preview.weeks.map(w => <tr key={w.start}><td>{w.label}</td><td>{w.rows}</td><td>{w.students}</td><td>{w.positive}</td><td>{w.negative}</td></tr>)}</tbody></table></div>
        <p className="section-copy">위 점수는 연결 전 원본 합계입니다. 학생 누계에는 CORE가 확인된 행만 반영됩니다.</p>
        {preview.warnings.length > 0 && <ul>{preview.warnings.map((w,i) => <li key={i}>{w}</li>)}</ul>}
        {preview.skipped.length > 0 && <p className="section-copy">가져오지 않는 탭: {preview.skipped.join(', ')}</p>}
        <label className="check-row"><input type="checkbox" checked={confirmed} onChange={e => setConfirmed(e.target.checked)} /> 해당 주차 전체 명부이며, 위 확인 사항과 기존 주간값 대체를 검토했습니다.</label>
        <button className="btn btn-primary" disabled={!confirmed || importer.isPending || history.isLoading || history.isError || !term.data || !!importer.data} onClick={() => {
          if (!term.data) return;
          importer.mutate({ termId: term.data.termId, source: fileName.slice(0,250), rows: preview.rows, notes: { annotations: preview.notes, warnings: preview.warnings } }, { onSuccess: () => { cache.invalidateQueries({ queryKey: ['discipline-history'] }); status.refetch(); } });
        }}>{importer.isPending ? '이관 중…' : '검토한 주간값으로 저장'}</button>
      </>}
      {importer.data && <p role="status">{importer.data.reused ? '이미 반영된 파일입니다.' : '이관을 완료했습니다.'} 원본 {importer.data.source_rows}행 · 학생 주간값 {importer.data.balances}건 · 미연결 원본 {importer.data.unlinked}행</p>}
    </section>}
    <section className="card card-pad" style={{ marginTop: 20 }}><h2 className="section-title">이관 이력</h2>
      <div className="table-wrap"><table className="data-table"><thead><tr><th>이관 시각</th><th>원본</th><th>원본 행</th><th>현재 반영</th><th>미연결</th></tr></thead><tbody>{status.data?.batches.map(b => <tr key={b.id}><td>{new Date(b.created_at).toLocaleString('ko-KR',{timeZone:'Asia/Seoul'})}</td><td>{b.source_label}</td><td>{b.source_rows}</td><td>{b.current_balances}</td><td>{b.unlinked}</td></tr>)}</tbody></table></div>
    </section>
    {(status.data?.unlinked.length ?? 0) > 0 && <section className="card card-pad" style={{ marginTop: 20 }}><h2 className="section-title">CORE 미연결 원본</h2><p className="section-copy">전학·자퇴 등으로 현재 명부에서 빠진 학생도 원본은 남습니다. 이름이 비슷한 다른 학생에게 자동 연결하지 않습니다.</p><div className="table-wrap"><table className="data-table"><thead><tr><th>주차</th><th>반 / 이름</th><th>상점</th><th>벌점</th></tr></thead><tbody>{status.data?.unlinked.map((r,i) => <tr key={i}><td>{r.week_start}</td><td>G{r.grade}{r.section ? '-'+r.section : ''} / {r.source_name}</td><td>{r.positive_points}</td><td>{r.negative_points}</td></tr>)}</tbody></table></div></section>}
  </div>;
}
