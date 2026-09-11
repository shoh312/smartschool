import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { teacher } from '../../api/endpoints'
import { useT } from '../../i18n'
import { IcSend } from '../../ui/icons'
import { Confirm, ErrorBox, errorText, gradeClass, Skeleton, useAsync, useFmt, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function Results() {
  const { t } = useT()
  const f = useFmt()
  const nav = useNavigate()
  const toast = useToast()
  const id = Number(useParams().id)
  const r = useAsync(() => teacher.results(id), [id])
  const [marks, setMarks] = useState<Map<number, number>>(new Map())
  const [confirm, setConfirm] = useState(false)
  const [busy, setBusy] = useState(false)
  useEffect(() => {
    if (!r.data) return
    setMarks(new Map(r.data.rows.filter((x) => x.suggested_grade != null && !x.transferred).map((x) => [x.student_id, x.suggested_grade!])))
  }, [r.data])

  const a = r.data?.assignment
  const rows = r.data?.rows ?? []
  const pending = rows.filter((x) => !x.transferred && x.score != null)
  const avgPct = pending.length ? Math.round(pending.reduce((s, x) => s + (x.percent ?? 0), 0) / pending.length) : null

  async function transfer() {
    setConfirm(false); setBusy(true)
    try {
      const items = pending.filter((x) => marks.has(x.student_id)).map((x) => ({ student_id: x.student_id, value: marks.get(x.student_id)! }))
      await teacher.transfer(id, items); toast(t('transferred_ok', items.length)); r.reload()
    } catch (e) { toast(errorText(e)) } finally { setBusy(false) }
  }

  return (
    <>
      <TopBar title={a?.material_title ?? '…'} sub={a ? `${a.class_name} · ${a.mode === 'control' ? t('mode_control') : t('mode_practice')}${a.due_at ? ` · ${t('due')} ${f.dateTime(a.due_at)}` : ''}` : ''} back={() => nav('/materials')}>
        {pending.length > 0 && marks.size > 0 && <button className="btn primary" disabled={busy} onClick={() => setConfirm(true)}><IcSend /> {t('put_in_journal', marks.size)}</button>}
      </TopBar>
      <ErrorBox error={r.error} onRetry={r.reload} />
      {r.loading && !r.data && <Skeleton rows={6} h={52} />}
      {a && (
        <>
          <div className="grid c4 mb24">
            <div className="card tight"><div className="stat-v">{a.submitted_count}/{a.student_count}</div><div className="stat-l">{t('submitted')}</div></div>
            <div className="card tight"><div className="stat-v">{avgPct != null ? `${avgPct}%` : '—'}</div><div className="stat-l">{t('avg_result')}</div></div>
            <div className="card tight"><div className="stat-v">{a.max_score}</div><div className="stat-l">{t('max_points')}</div></div>
            <div className="card tight"><div className="stat-v">{a.question_count}</div><div className="stat-l">{t('questions')}</div></div>
          </div>
          {!r.data?.results_visible && <div className="card tight small muted mb16">{t('results_hidden')}</div>}
          <div className="card" style={{ padding: 0 }}>
            <table className="table">
              <thead><tr><th>{t('name')}</th><th>{t('submitted_at')}</th><th>{t('attempts')}</th><th>{t('score')}</th><th style={{ width: 200 }}>{t('grade')}</th><th></th></tr></thead>
              <tbody>
                {rows.map((x) => (
                  <tr key={x.student_id}>
                    <td className="bold">{x.student_name}</td>
                    <td className="small muted">{x.submitted_at ? f.dateTime(x.submitted_at) : <span className="faint">{t('not_submitted')}</span>}</td>
                    <td className="small muted">{x.attempt_count || '—'}</td>
                    <td>{x.score != null ? <span className="row"><span className="bold">{x.score}/{x.max_score}</span><span className={'chip ' + ((x.percent ?? 0) >= 80 ? 'mint' : (x.percent ?? 0) >= 50 ? 'amber' : 'rose')}>{x.percent}%</span></span> : '—'}</td>
                    <td>
                      {x.score != null && !x.transferred && (
                        <div className="row" style={{ gap: 3 }}>
                          {Array.from({ length: 10 }, (_, i) => i + 1).map((v) => {
                            const on = marks.get(x.student_id) === v
                            return <button key={v} className={'grade ' + (on ? gradeClass(v) : 'g-none')} style={{ minWidth: 26, height: 26, fontSize: 11, padding: 0, opacity: on ? 1 : .6, outline: on ? '2px solid currentColor' : 'none' }} onClick={() => { const n = new Map(marks); on ? n.delete(x.student_id) : n.set(x.student_id, v); setMarks(n) }}>{v}</button>
                          })}
                        </div>
                      )}
                    </td>
                    <td style={{ textAlign: 'right' }}>{x.transferred && <span className="chip mint">{t('in_journal')}</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
      {confirm && <Confirm title={t('put_in_journal', marks.size)} body={t('transfer_body')} onNo={() => setConfirm(false)} onYes={transfer} />}
    </>
  )
}
