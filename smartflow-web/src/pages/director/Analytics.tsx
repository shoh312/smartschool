import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { director } from '../../api/endpoints'
import { useT } from '../../i18n'
import { Avatar, ErrorBox, Grade, Skeleton, useAsync } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function Analytics() {
  const { t } = useT()
  const nav = useNavigate()
  const [quarter, setQuarter] = useState<number | null>(null)
  const [tab, setTab] = useState<'ranking' | 'attention'>('ranking')
  const ranking = useAsync(() => director.schoolRanking(quarter), [quarter])
  const attention = useAsync(() => director.needsAttention(quarter), [quarter])
  return (
    <>
      <TopBar title={t('nav_analytics')} sub={t('analytics_sub')}>
        <div className="seg">
          {[null, 1, 2, 3, 4].map((q) => <button key={String(q)} className={quarter === q ? 'active' : ''} onClick={() => setQuarter(q)}>{q == null ? t('current') : `${q} ${t('quarter_short')}`}</button>)}
        </div>
      </TopBar>
      <div className="tabs mb16">
        <button className={'tab' + (tab === 'ranking' ? ' active' : '')} onClick={() => setTab('ranking')}>🏆 {t('school_ranking')}</button>
        <button className={'tab' + (tab === 'attention' ? ' active' : '')} onClick={() => setTab('attention')}>⚠️ {t('needs_attention')}</button>
      </div>
      {tab === 'ranking' && (
        <div className="card" style={{ padding: 0 }}>
          <ErrorBox error={ranking.error} onRetry={ranking.reload} />
          {ranking.loading && !ranking.data && <div style={{ padding: 20 }}><Skeleton rows={8} h={48} /></div>}
          <table className="table">
            <thead><tr><th style={{ width: 60 }}>#</th><th></th><th>{t('name')}</th><th>{t('class')}</th><th style={{ textAlign: 'right' }}>{t('average')}</th></tr></thead>
            <tbody>
              {ranking.data?.map((s) => (
                <tr key={s.student_id} className="clickable" onClick={() => nav(`/students/${s.student_id}`)}>
                  <td className="bold" style={{ fontSize: 16, color: s.position <= 3 ? 'var(--amber)' : 'var(--ink-3)' }}>{s.position <= 3 ? ['🥇', '🥈', '🥉'][s.position - 1] : s.position}</td>
                  <td style={{ width: 48 }}><Avatar first={s.first_name} last={s.last_name} id={s.student_id} size="sm" /></td>
                  <td className="bold">{s.last_name} {s.first_name}</td>
                  <td><span className="chip">{s.class_name}</span></td>
                  <td style={{ textAlign: 'right' }}><Grade v={s.overall_average} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {tab === 'attention' && (
        <div className="grid c2">
          <div className="card">
            <div className="card-title">📉 {t('bottom_performers')}</div>
            <ErrorBox error={attention.error} onRetry={attention.reload} />
            {attention.data?.bottom_performers.length === 0 && <div className="muted small">{t('all_good')}</div>}
            <div className="col" style={{ gap: 6 }}>
              {attention.data?.bottom_performers.map((s) => (
                <div key={s.student_id} className="row" style={{ cursor: 'pointer', padding: '6px 0' }} onClick={() => nav(`/students/${s.student_id}`)}>
                  <Avatar first={s.first_name} last={s.last_name} id={s.student_id} size="sm" />
                  <div className="grow"><div className="bold small">{s.last_name} {s.first_name}</div><div className="tiny faint">{s.class_name} · #{s.position}/{s.out_of}</div></div>
                  <Grade v={s.overall_average} />
                </div>
              ))}
            </div>
          </div>
          <div className="card">
            <div className="card-title">🔻 {t('biggest_decliners')}</div>
            {attention.data?.biggest_decliners.length === 0 && <div className="muted small">{t('all_good')}</div>}
            <div className="col" style={{ gap: 6 }}>
              {attention.data?.biggest_decliners.map((s) => (
                <div key={s.student_id} className="row" style={{ cursor: 'pointer', padding: '6px 0' }} onClick={() => nav(`/students/${s.student_id}`)}>
                  <Avatar first={s.first_name} last={s.last_name} id={s.student_id} size="sm" />
                  <div className="grow"><div className="bold small">{s.last_name} {s.first_name}</div><div className="tiny faint">{s.class_name} · {s.previous_average.toFixed(1)} → {s.current_average.toFixed(1)}</div></div>
                  <span className="chip rose">▼ {Math.abs(s.delta).toFixed(1)}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </>
  )
}
