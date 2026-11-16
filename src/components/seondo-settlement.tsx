import type { SeondoSettlement } from '@/lib/api';

const formatTime = new Intl.DateTimeFormat('ko-KR', {
  dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Seoul',
});

export function SeondoSettlementRows({ report, weekly, homeroom = 'ALL' }: {
  report: SeondoSettlement | null | undefined;
  weekly: boolean;
  homeroom?: string;
}) {
  if (!report) return <p>확정된 {weekly ? '주간' : '월간'} 결산이 없습니다.</p>;
  const students = report.students.filter(row => homeroom === 'ALL' || (row.homeroom ?? 'G' + row.grade) === homeroom);
  return <>
    <p className="muted">결산 기준 {formatTime.format(new Date(report.closes_at))}
      {report.delivered_at && <> · 받은 시각 {formatTime.format(new Date(report.delivered_at))}</>}
    </p>
    {students.length === 0 ? <p>대상 학생이 없습니다.</p> : <div className="table-wrap">
      <table className="data-table print-table">
        <thead><tr><th>학생</th><th>학급</th><th>{weekly ? '주간 상벌NET' : '체력훈련 횟수'}</th>{weekly && <th>사유</th>}</tr></thead>
        <tbody>{students.map((row, index) => <tr key={index}>
          <td>{row.name}</td><td>{row.homeroom ?? 'G' + row.grade}</td>
          <td>{weekly ? row.net : row.count}</td>{weekly && <td>{row.reasons?.join(' · ')}</td>}
        </tr>)}</tbody>
      </table>
    </div>}
  </>;
}
