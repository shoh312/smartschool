import { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { loadSession, publicWsBase } from '../../api/client'
import { family } from '../../api/endpoints'
import type { GradeDto, StudentAssignmentDto } from '../../api/types'
import { useSession } from '../../App'
import { useT } from '../../i18n'
import { Avatar, ErrorBox, fmtAvg, Grade, gradeClass, Skeleton, useAsync, useErrorMessage, useFmt, addDays, todayIso } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'
import { Ill } from '../../ui/illustrations'
import { IcBack, IcNext, IcPlay } from '../../ui/icons'
import { Ring, TrendLine } from '../../ui/charts'

type Tab = 'overview' | 'grades' | 'attendance' | 'diary' | 'assignments' | 'live'

/** One pupil's whole picture: what a parent (or the pupil) sees, tab by tab. */
export function Child() {
  const { t } = useT()
  const session = useSession()
  const nav = useNavigate()
  const params = useParams()
  const studentId = Number(params.id ?? session?.id ?? 0)
  const isParent = session?.role === 'parent'
  const [tab, setTab] = useState<Tab>('overview')

  const kids = useAsync(() => family.children(), [])
  const child = kids.data?.find((c) => c.id === studentId)
  const name = child ? `${child.last_name} ${child.first_name}` : (session?.role === 'student' ? session.fullName : '')

  const tabs: { id: Tab; label: string }[] = [
    { id: 'overview', label: t('tab_overview') },
    { id: 'grades', label: t('tab_grades') },
    { id: 'attendance', label: t('tab_attendance') },
    { id: 'diary', label: t('tab_diary') },
    { id: 'assignments', label: t('tab_assignments') },
    ...(isParent ? [{ id: 'live' as Tab, label: t('tab_live') }] : []),
  ]

  return (
    <>
      <TopBar title={name || t('nav_home')} sub={child?.class_name || session?.className || ''} back={isParent ? () => nav('/') : undefined} />
      <div className="tabs mb16">
        {tabs.map((x) => (
          <button key={x.id} className={'tab' + (tab === x.id ? ' active' : '')} onClick={() => setTab(x.id)}>{x.label}</button>
        ))}
      </div>
      {tab === 'overview' && <Overview studentId={studentId} />}
      {tab === 'grades' && <Grades studentId={studentId} />}
      {tab === 'attendance' && <Attendance studentId={studentId} />}
      {tab === 'diary' && <Diary studentId={studentId} />}
      {tab === 'assignments' && <Assignments studentId={studentId} onOpen={(a) => nav(isParent ? `/child/${studentId}/test/${a.id}` : `/test/${a.id}`)} />}
      {tab === 'live' && isParent && <LiveLesson studentId={studentId} />}
    </>
  )
}

// -------------------------------------------------------------- overview

function Overview({ studentId }: { studentId: number }) {
  const { t } = useT()
  const a = useAsync(() => family.analytics(studentId).catch(() => null), [studentId])
  const g = useAsync(() => family.grades(studentId), [studentId])
  if (a.loading || g.loading) return <Skeleton rows={3} h={90} />
  const an = a.data
  const recent = (g.data ?? []).slice(0, 8)
  const attPct = an?.lesson_attendance_rate != null ? Math.round((an.lesson_attendance_rate || 0) * 100) : null
  return (
    <div className="grid c2" style={{ alignItems: 'start' }}>
      <div className="col" style={{ gap: 16 }}>
        <div className="card">
          <div className="card-title"><Ill name="trophy" size={30} /> {t('tab_overview')}</div>
          {!an && <div className="small muted">{t('family_no_analytics')}</div>}
          {an && (
            <>
              <div className="row" style={{ gap: 18 }}>
                <Ring value={an.overall_average ?? 0} max={10} size={104} color="var(--brand)"
                  center={<b style={{ fontSize: 24 }}>{fmtAvg(an.overall_average)}</b>} sub={t('avg_overall')} />
                <div className="grow row" style={{ gap: 16, justifyContent: 'space-around' }}>
                  <Rank label={t('rank_class')} r={an.class_rank} />
                  <Rank label={t('rank_parallel')} r={an.parallel_rank} />
                  <Rank label={t('rank_school')} r={an.school_rank} />
                </div>
              </div>
              {attPct != null && (
                <div className="mt16"><div className="small muted mb8">{t('attendance_rate')}: <b>{attPct}%</b></div>
                  <div className="bar"><span style={{ width: `${attPct}%`, background: attPct >= 90 ? 'var(--mint)' : attPct >= 75 ? 'var(--amber)' : 'var(--rose)' }} /></div></div>
              )}
              {an.subject_breakdown?.length > 0 && (
                <div className="mt16">
                  {an.subject_breakdown.map((s) => (
                    <div key={s.subject} className="row" style={{ padding: '7px 0' }}>
                      <span className="grow ellipsis">{s.subject}</span>
                      <span className="bar" style={{ width: 120 }}><span style={{ width: `${(s.average / 10) * 100}%`, background: s.average >= 8 ? 'var(--mint)' : 'var(--brand)' }} /></span>
                      <b style={{ width: 34, textAlign: 'right' }}>{fmtAvg(s.average)}</b>
                    </div>
                  ))}
                </div>
              )}
            </>
          )}
        </div>
        {an && an.trend && an.trend.length > 1 && (
          <div className="card">
            <div className="card-title"><Ill name="trophy" size={28} /> {t('trend_title')}</div>
            <TrendLine points={an.trend.map((q) => ({ label: `${t('quarter_short')}${q.quarter}`, value: q.overall_average ?? null }))} />
          </div>
        )}
      </div>
      <div className="card">
        <div className="card-title"><Ill name="notebook" size={30} /> {t('recent_grades')}</div>
        {recent.length === 0 && <div className="small muted">{t('no_grades')}</div>}
        {recent.map((gr) => (
          <div key={gr.id} className="row" style={{ padding: '8px 0', borderBottom: '1px solid var(--border)' }}>
            <Grade v={gr.value} />
            <div className="grow"><div className="bold">{gr.subject}</div>{gr.comment && <div className="small muted">{gr.comment}</div>}</div>
            <div className="small faint">{gr.grade_date?.slice(5)}</div>
          </div>
        ))}
      </div>
    </div>
  )
}

function Rank({ label, r }: { label: string; r?: { position?: number | null; out_of: number } }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <div style={{ fontSize: 18, fontWeight: 800 }}>{r?.position ?? '—'}<span className="faint" style={{ fontSize: 12 }}>/{r?.out_of ?? '—'}</span></div>
      <div className="tiny muted">{label}</div>
    </div>
  )
}

// ---------------------------------------------------------------- grades

function Grades({ studentId }: { studentId: number }) {
  const { t } = useT()
  const g = useAsync(() => family.grades(studentId), [studentId])
  if (g.loading) return <Skeleton rows={4} h={54} />
  if (g.error) return <ErrorBox error={g.error} onRetry={g.reload} />
  const rows = g.data ?? []
  const bySubject = new Map<string, GradeDto[]>()
  for (const gr of rows) { const a = bySubject.get(gr.subject) ?? []; a.push(gr); bySubject.set(gr.subject, a) }
  if (bySubject.size === 0) return <div className="card"><div className="small muted">{t('no_grades')}</div></div>
  return (
    <div className="col" style={{ gap: 12 }}>
      {[...bySubject.entries()].map(([subject, list]) => {
        const vals = list.map((x) => x.value)
        const avg = vals.reduce((a, b) => a + b, 0) / vals.length
        const sorted = [...list].sort((a, b) => (a.grade_date < b.grade_date ? 1 : -1))
        return (
          <div key={subject} className="card">
            <div className="row mb8"><div className="bold grow">{subject}</div><span className={'grade ' + gradeClass(avg)}>{fmtAvg(avg)}</span></div>
            <div className="row wrap" style={{ gap: 6 }}>
              {sorted.map((gr) => <span key={gr.id} className={'grade ' + gradeClass(gr.value)} title={`${gr.grade_date}${gr.comment ? ' · ' + gr.comment : ''}`}>{gr.value}</span>)}
            </div>
          </div>
        )
      })}
    </div>
  )
}

// ------------------------------------------------------------ attendance

function Attendance({ studentId }: { studentId: number }) {
  const { t } = useT()
  const f = useFmt()
  const a = useAsync(() => family.attendance(studentId), [studentId])
  if (a.loading) return <Skeleton rows={4} h={48} />
  if (a.error) return <ErrorBox error={a.error} onRetry={a.reload} />
  const rows = a.data ?? []
  const n = (s: string) => rows.filter((r) => r.status === s).length
  const present = n('present'), late = n('late'), absent = n('absent')
  const total = present + late + absent
  const rate = total ? Math.round(((present + late) / total) * 100) : 0
  return (
    <>
      <div className="grid c3 mb16">
        <Stat n={present} label={t('att_present')} cls="mint" />
        <Stat n={late} label={t('att_late')} cls="amber" />
        <Stat n={absent} label={t('att_absent')} cls="rose" />
      </div>
      <div className="card mb16"><div className="small muted mb8">{t('attendance_rate')}: <b>{rate}%</b></div><div className="bar"><span style={{ width: `${rate}%` }} /></div></div>
      <div className="card">
        <div className="card-title">{t('att_history')}</div>
        {rows.length === 0 && <div className="small muted">{t('att_empty')}</div>}
        {rows.slice(0, 60).map((r) => (
          <div key={r.id} className="row" style={{ padding: '9px 0', borderBottom: '1px solid var(--border)' }}>
            <span className={'chip ' + (r.status === 'absent' ? 'rose' : r.status === 'late' ? 'amber' : 'mint')}>
              {r.status === 'absent' ? t('att_absent') : r.status === 'late' ? t('att_late') : t('att_present')}
            </span>
            <div className="grow" />
            <div className="small">{f.date(r.attendance_date)}</div>
            {r.time_in && <div className="small faint" style={{ width: 56, textAlign: 'right' }}>{f.time(r.time_in)}</div>}
          </div>
        ))}
      </div>
    </>
  )
}

function Stat({ n, label, cls }: { n: number; label: string; cls: string }) {
  return <div className="card" style={{ textAlign: 'center' }}><div className={'stat-n ' + cls} style={{ fontSize: 32, fontWeight: 800 }}>{n}</div><div className="small muted">{label}</div></div>
}

// --------------------------------------------------------------- diary

function Diary({ studentId }: { studentId: number }) {
  const { t } = useT()
  const f = useFmt()
  const [on, setOn] = useState(todayIso())
  const d = useAsync(() => family.diary(studentId, on), [studentId, on])
  return (
    <>
      <div className="row mb16">
        <button className="btn ghost icon" onClick={() => setOn(addDays(on, -1))}><IcBack /></button>
        <div className="card tight" style={{ minWidth: 200, textAlign: 'center' }}><b>{f.dateLong(on)}</b></div>
        <button className="btn ghost icon" onClick={() => setOn(addDays(on, 1))}><IcNext /></button>
        {on !== todayIso() && <button className="btn soft sm" onClick={() => setOn(todayIso())}>{t('today')}</button>}
      </div>
      {d.loading && <Skeleton rows={3} h={70} />}
      {d.error && <ErrorBox error={d.error} onRetry={d.reload} />}
      {d.data && d.data.length === 0 && <div className="card"><div className="small muted">{t('diary_empty')}</div></div>}
      <div className="col" style={{ gap: 12 }}>
        {d.data?.map((e) => (
          <div key={e.lesson_id} className="card">
            <div className="row mb8">
              <div className="grow"><div className="bold">{e.subject}</div><div className="small muted">{e.start_time}{e.room ? ` · ${e.room}` : ''}{e.teacher_name ? ` · ${e.teacher_name}` : ''}</div></div>
              {e.grade != null && <Grade v={e.grade} />}
            </div>
            {e.homework && <div className="mt8"><div className="tiny bold muted">{t('homework')}</div><div className="small">{e.homework}</div></div>}
            {e.teacher_comment && <div className="mt8"><div className="tiny bold muted">{t('teacher_comment')}</div><div className="small">{e.teacher_comment}</div></div>}
          </div>
        ))}
      </div>
    </>
  )
}

// ----------------------------------------------------------- assignments

function Assignments({ studentId, onOpen }: { studentId: number; onOpen: (a: StudentAssignmentDto) => void }) {
  const { t } = useT()
  const f = useFmt()
  const a = useAsync(() => family.assignments(studentId), [studentId])
  const session = useSession()
  const isStudent = session?.role === 'student'
  if (a.loading) return <Skeleton rows={3} h={80} />
  if (a.error) return <ErrorBox error={a.error} onRetry={a.reload} />
  const rows = a.data ?? []
  if (rows.length === 0) return <div className="card" style={{ textAlign: 'center', padding: 32 }}><Ill name="clipboard" size={110} /><div className="bold mt12">{t('asg_empty')}</div></div>
  return (
    <div className="col" style={{ gap: 12 }}>
      {rows.map((x) => {
        const done = x.submitted_at != null
        return (
          <div key={x.id} className={'card' + (isStudent && x.can_start ? ' clickable' : '')} onClick={() => isStudent && x.can_start && onOpen(x)}>
            <div className="row">
              <div className="grow">
                <div className="bold">{x.title}</div>
                <div className="small muted">{x.subject}{x.teacher_name ? ` · ${x.teacher_name}` : ''} · {x.question_count} {t('asg_questions')}</div>
                <div className="small faint mt8">
                  {x.due_at && <>{t('asg_due')}: {f.dateLong(x.due_at)} · </>}
                  {x.max_attempts != null && <>{t('asg_attempts')}: {x.attempts_used}/{x.max_attempts}</>}
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                {done && x.score_visible && x.percent != null && <div className={'grade ' + gradeClass((x.percent / 10))} style={{ fontSize: 15 }}>{x.percent}%</div>}
                {done && !x.score_visible && <span className="chip mint">{t('asg_done')}</span>}
                {!done && x.is_overdue && <span className="chip rose">{t('asg_overdue')}</span>}
                {!done && !x.is_overdue && isStudent && x.can_start && <span className="btn primary sm"><IcPlay /> {t('asg_start')}</span>}
                {!done && !x.is_overdue && !isStudent && <span className="chip amber">{t('asg_pending')}</span>}
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}

// ------------------------------------------------------------- live lesson

function LiveLesson({ studentId }: { studentId: number }) {
  const { t } = useT()
  const msg = useErrorMessage()
  const canvas = useRef<HTMLCanvasElement>(null)
  const [state, setState] = useState<'connecting' | 'live' | 'closed'>('connecting')
  const [reason, setReason] = useState('')

  useEffect(() => {
    const s = loadSession()
    if (!s) return
    let alive = true, pending: Blob | null = null, busy = false, live = false
    const pump = async () => {
      if (busy || !pending || !alive) return
      busy = true; const blob = pending; pending = null
      try {
        const bmp = await createImageBitmap(blob)
        const c = canvas.current
        if (c && alive) { if (c.width !== bmp.width || c.height !== bmp.height) { c.width = bmp.width; c.height = bmp.height } c.getContext('2d')!.drawImage(bmp, 0, 0); if (!live) { live = true; setState('live') } }
        bmp.close()
      } catch {}
      busy = false; if (pending) pump()
    }
    const ws = new WebSocket(`${publicWsBase()}parent/live?student_id=${studentId}&token=${encodeURIComponent(s.token)}`)
    ws.binaryType = 'blob'
    ws.onmessage = (ev) => { if (ev.data instanceof Blob) { pending = ev.data; pump() } }
    ws.onclose = (ev) => { if (alive) { setState('closed'); setReason(ev.reason || '') } }
    ws.onerror = () => { if (alive) setState('closed') }
    return () => { alive = false; pending = null; ws.close() }
  }, [studentId])

  return (
    <div className="card">
      <div className="video" style={{ aspectRatio: '16/9', maxWidth: 900, margin: '0 auto' }}>
        <canvas ref={canvas} width={960} height={540} style={{ display: state === 'live' ? 'block' : 'none', width: '100%' }} />
        {state !== 'live' && (
          <div style={{ textAlign: 'center' }}>
            <div style={{ marginBottom: 8, display: 'flex', justifyContent: 'center' }}>{state === 'closed' ? <Ill name="school" size={110} /> : <span className="spinner" />}</div>
            <div className="bold">{state === 'closed' ? (reason ? msg(reason) : t('live_no_lesson')) : t('connecting')}</div>
            {state === 'closed' && <div className="small" style={{ opacity: .7, marginTop: 4 }}>{t('live_parent_hint')}</div>}
          </div>
        )}
        {state === 'live' && <div className="badge"><span className="chip" style={{ background: 'rgba(0,0,0,.5)', color: '#fff' }}><span className="live-dot" /> LIVE</span></div>}
      </div>
    </div>
  )
}
