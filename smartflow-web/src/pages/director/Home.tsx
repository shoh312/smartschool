import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { director } from '../../api/endpoints'
import type { CameraStatusDto, LiveStatusDto } from '../../api/types'
import { useT } from '../../i18n'
import { useSession } from '../../App'
import { IcBook, IcCheck, IcNext } from '../../ui/icons'
import { Ill, type IllName } from '../../ui/illustrations'
import { Avatar, ErrorBox, fmtAvg, Grade, Skeleton, useAsync, useFmt } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'
import { BarChart, Delta, DonutChart, LineChart, Ring } from '../../ui/charts'

export function DirectorHome() {
  const { t } = useT()
  const f = useFmt()
  const session = useSession()
  const classes = useAsync(() => director.classes(), [])
  const students = useAsync(() => director.students(), [])
  const teachers = useAsync(() => director.teachers(), [])
  const attention = useAsync(() => director.needsAttention(), [])
  const ranking = useAsync(() => director.schoolRanking(), [])
  const events = useAsync(() => director.calendar(), [])
  const history = useAsync(() => director.attendanceHistory(), [])
  const [cams, setCams] = useState<CameraStatusDto[]>([])
  const [live, setLive] = useState<LiveStatusDto[]>([])

  useEffect(() => {
    let alive = true
    const tick = async () => {
      try {
        const [c, l] = await Promise.all([director.cameraStatus(), director.liveStatus()])
        if (alive) { setCams(c); setLive(l) }
      } catch {}
    }
    let timer = 0
    const loop = async () => { await tick(); if (alive) timer = window.setTimeout(loop, 5000) }
    loop()
    return () => { alive = false; window.clearTimeout(timer) }
  }, [])

  const today = new Date()
  const nPresent = live.filter((s) => s.status === 'present').length
  const nLate = live.filter((s) => s.status === 'late').length
  const nAbsent = live.filter((s) => s.status === 'absent').length
  const present = nPresent + nLate
  const totalPupils = students.data?.length ?? live.length
  const attRate = totalPupils ? Math.round((present / totalPupils) * 100) : 0
  const inLesson = live.filter((s) => s.class_lesson_state === 'running')
  const online = cams.filter((c) => c.connected).length
  // school average and per-class averages, straight from the ranking we already load
  const rank = ranking.data ?? []
  const schoolAvg = rank.length ? rank.reduce((s, r) => s + (r.overall_average ?? 0), 0) / rank.length : 0
  const classAvg = (() => {
    const m = new Map<string, number[]>()
    for (const r of rank) { const k = r.class_name ?? '—'; const a = m.get(k) ?? []; if (r.overall_average != null) a.push(r.overall_average); m.set(k, a) }
    return [...m.entries()].filter(([, v]) => v.length).map(([label, v]) => ({ label, value: v.reduce((s, x) => s + x, 0) / v.length }))
      .sort((a, b) => b.value - a.value)
  })()
  const todayIso = today.toISOString().slice(0, 10)
  const upcoming = (events.data ?? []).filter((e) => (e.end_date ?? e.start_date) >= todayIso).sort((a, b) => a.start_date.localeCompare(b.start_date)).slice(0, 4)

  // Daily attendance trend over the last two weeks, from the raw history: what
  // share came (present or late) each day, and what share was absent.
  const trend = (() => {
    const days: string[] = []
    for (let i = 13; i >= 0; i--) { const d = new Date(); d.setDate(d.getDate() - i); days.push(d.toISOString().slice(0, 10)) }
    const per = new Map<string, { came: number; absent: number }>()
    for (const r of history.data ?? []) {
      const day = r.attendance_date?.slice(0, 10); if (!day) continue
      const p = per.get(day) ?? { came: 0, absent: 0 }
      if (r.status === 'present' || r.status === 'late') p.came++
      else if (r.status === 'absent') p.absent++
      per.set(day, p)
    }
    const rows = days.map((d) => {
      const p = per.get(d); const tot = p ? p.came + p.absent : 0
      return { day: d, came: tot ? Math.round((p!.came / tot) * 100) : null, absent: tot ? Math.round((p!.absent / tot) * 100) : null, has: tot > 0 }
    })
    return rows
  })()
  const trendDays = trend.filter((r) => r.has)
  const lastPct = trendDays.length ? trendDays[trendDays.length - 1].came ?? 0 : 0
  const prevPct = trendDays.length > 1 ? trendDays[trendDays.length - 2].came ?? 0 : lastPct

  return (
    <>
      <TopBar title={t('greeting', session?.fullName.split(' ')[0] ?? '')} sub={f.dateLong(todayIso)} />
      <div className="hero mb24">
        <div className="hero-art"><Ill name="school" size={230} /></div>
        <h2>{t('home_hero_title')}</h2>
        <p>{t('home_hero_body')}</p>
        <div className="row wrap mt16" style={{ gap: 8 }}>
          <span className="pill-w"><span className="live-dot" /> {t('cams_online', online, cams.length)}</span>
          <span className="pill-w"><IcCheck /> {t('present_now', present)}</span>
          {inLesson.length > 0 && <span className="pill-w"><IcBook /> {t('in_lesson_now', new Set(inLesson.map((s) => s.class_name)).size)}</span>}
        </div>
      </div>

      <div className="grid c4 mb24 kpi-row">
        <Stat to="/classes" ill="school" tone="brand" v={classes.data?.length} l={t('nav_classes')} />
        <Stat to="/students" ill="backpack" tone="mint" v={students.data?.length} l={t('nav_students')} />
        <Stat to="/teachers" ill="family" tone="amber" v={teachers.data?.length} l={t('nav_teachers')} />
        <Stat to="/cameras" ill="door_check" tone="sky" v={`${online}/${cams.length}`} l={t('cams_online_l')} />
      </div>

      <div className="grid mb24" style={{ gridTemplateColumns: '1.4fr 1fr' }}>
        <div className="card">
          <div className="card-title">{t('attendance_today')}</div>
          <DonutChart size={168} stroke={28}
            segments={[
              { label: t('att_present'), value: nPresent, color: 'var(--mint)' },
              { label: t('att_late'), value: nLate, color: 'var(--amber)' },
              { label: t('att_absent'), value: nAbsent, color: 'var(--rose)' },
            ]}
            title={<b>{attRate}%</b>} total={t('present_l')} />
        </div>
        <div className="col" style={{ gap: 16 }}>
          <div className="card kpi">
            <Ring value={schoolAvg} max={10} size={104} color="var(--brand)"
              center={<b style={{ fontSize: 24 }}>{fmtAvg(schoolAvg)}</b>} sub={t('avg_overall')} />
            <div className="kpi-txt"><div className="kpi-v">{t('school_avg_title')}</div><div className="kpi-l">{t('school_avg_sub')}</div></div>
          </div>
          <div className="card kpi">
            <Ring value={present} max={totalPupils || 1} size={104} color="var(--mint)"
              center={<b style={{ fontSize: 20 }}>{present}<span style={{ fontSize: 12, color: 'var(--ink-3)' }}>/{totalPupils}</span></b>} sub={t('present_l')} />
            <div className="kpi-txt"><div className="kpi-v">{t('present_now_title')}</div><div className="kpi-l">{t('cams_online', online, cams.length)}</div></div>
          </div>
        </div>
      </div>

      {trendDays.length > 1 && (
        <div className="card mb24">
          <div className="row mb16" style={{ alignItems: 'flex-start' }}>
            <div className="grow">
              <div className="card-title" style={{ marginBottom: 2 }}>{t('att_trend_title')}</div>
              <div className="small muted">{t('att_trend_sub')}</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div className="row" style={{ gap: 8, justifyContent: 'flex-end' }}>
                <div style={{ fontSize: 30, fontWeight: 800, letterSpacing: '-.5px' }}>{lastPct}%</div>
                <Delta value={lastPct - prevPct} unit="%" />
              </div>
              <div className="tiny faint">{t('att_trend_today')}</div>
            </div>
          </div>
          <LineChart
            labels={trendDays.map((r) => f.ddmm(r.day))}
            unit="%" max={100} height={230}
            series={[
              { label: t('att_present'), color: 'var(--brand)', values: trendDays.map((r) => r.came) },
              { label: t('att_absent'), color: 'var(--rose)', dashed: true, values: trendDays.map((r) => r.absent) },
            ]}
          />
          <div className="legend" style={{ justifyContent: 'center' }}>
            <span><i style={{ background: 'var(--brand)' }} /> {t('att_present')}</span>
            <span><i style={{ background: 'var(--rose)', opacity: .7 }} /> {t('att_absent')}</span>
          </div>
        </div>
      )}

      {classAvg.length > 0 && (
        <div className="card mb24">
          <div className="card-title"><Ill name="trophy" size={30} /> {t('class_averages')}</div>
          <BarChart data={classAvg.slice(0, 10).map((c) => ({ label: c.label.replace(/[^A-Za-z0-9# ]/g, '').slice(0, 6) || c.label, value: c.value }))} max={10} height={210} />
        </div>
      )}

      <div className="grid c2">
        <div className="card">
          <div className="card-title"><Ill name="shield" size={34} /> {t('needs_attention')} <Link to="/analytics" className="btn sm ghost" style={{ marginLeft: 'auto' }}>{t('all')} <IcNext /></Link></div>
          <ErrorBox error={attention.error} onRetry={attention.reload} />
          {attention.loading && !attention.data && <Skeleton rows={4} h={48} />}
          {attention.data && (
            <div className="col" style={{ gap: 6 }}>
              {attention.data.bottom_performers.slice(0, 5).map((s) => (
                <Link key={s.student_id} to={`/students/${s.student_id}`} className="row" style={{ padding: '6px 0' }}>
                  <Avatar first={s.first_name} last={s.last_name} id={s.student_id} size="sm" />
                  <div className="grow">
                    <div className="bold small">{s.last_name} {s.first_name}</div>
                    <div className="tiny faint">{s.class_name}</div>
                  </div>
                  <Grade v={s.overall_average} />
                </Link>
              ))}
              {attention.data.biggest_decliners.slice(0, 3).map((s) => (
                <Link key={'d' + s.student_id} to={`/students/${s.student_id}`} className="row" style={{ padding: '6px 0' }}>
                  <Avatar first={s.first_name} last={s.last_name} id={s.student_id} size="sm" />
                  <div className="grow">
                    <div className="bold small">{s.last_name} {s.first_name}</div>
                    <div className="tiny faint">{s.class_name}</div>
                  </div>
                  <span className="chip rose">▼ {s.delta.toFixed(1)}</span>
                </Link>
              ))}
              {!attention.data.bottom_performers.length && !attention.data.biggest_decliners.length && <div className="muted small">{t('all_good')}</div>}
            </div>
          )}
        </div>
        <div className="card">
          <div className="card-title"><Ill name="trophy" size={34} /> {t('top_pupils')} <Link to="/analytics" className="btn sm ghost" style={{ marginLeft: 'auto' }}>{t('all')} <IcNext /></Link></div>
          <ErrorBox error={ranking.error} onRetry={ranking.reload} />
          {ranking.loading && !ranking.data && <Skeleton rows={4} h={48} />}
          {ranking.data && (
            <div className="col" style={{ gap: 6 }}>
              {ranking.data.slice(0, 8).map((s) => (
                <Link key={s.student_id} to={`/students/${s.student_id}`} className="row" style={{ padding: '6px 0' }}>
                  <span className="bold faint" style={{ width: 22 }}>{s.position}</span>
                  <Avatar first={s.first_name} last={s.last_name} id={s.student_id} size="sm" />
                  <div className="grow">
                    <div className="bold small">{s.last_name} {s.first_name}</div>
                    <div className="tiny faint">{s.class_name}</div>
                  </div>
                  <Grade v={s.overall_average} />
                </Link>
              ))}
            </div>
          )}
        </div>
        <div className="card">
          <div className="card-title"><Ill name="door_check" size={34} /> {t('cameras_now')} <Link to="/cameras" className="btn sm ghost" style={{ marginLeft: 'auto' }}>{t('all')} <IcNext /></Link></div>
          {cams.length === 0 && <div className="muted small">{t('no_cameras')}</div>}
          <div className="col" style={{ gap: 8 }}>
            {cams.map((c) => (
              <div key={c.camera_id} className="row">
                <span className={'dot'} style={{ color: c.connected ? 'var(--mint)' : 'var(--ink-3)' }} />
                <div className="grow">
                  <div className="bold small">{c.camera_name}</div>
                  <div className="tiny faint">{c.class_name ?? '—'} · {phaseText(c, t)}</div>
                </div>
                {c.detecting && <span className="chip mint">{t('detecting')}</span>}
              </div>
            ))}
          </div>
        </div>
        <div className="card">
          <div className="card-title"><Ill name="calendar" size={34} /> {t('upcoming')} <Link to="/calendar" className="btn sm ghost" style={{ marginLeft: 'auto' }}>{t('all')} <IcNext /></Link></div>
          {upcoming.length === 0 && <div className="muted small">{t('no_events')}</div>}
          <div className="col" style={{ gap: 8 }}>
            {upcoming.map((e) => (
              <div key={e.id} className="row">
                <div className="chip brand" style={{ minWidth: 64, justifyContent: 'center' }}>{f.date(e.start_date)}</div>
                <div className="grow">
                  <div className="bold small">{e.title}</div>
                  <div className="tiny faint">{t('ev_' + e.event_type) || e.event_type}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  )
}

export function phaseText(c: CameraStatusDto, t: (k: string, ...a: (string | number)[]) => string): string {
  if (!c.connected) return t('cam_offline')
  if (c.roll_call) return t('cam_roll_call')
  if (c.detecting) return t('cam_detecting')
  if (c.phase === 'dars vaqti emas' || c.phase === 'idle') return t('cam_no_lesson')
  return c.phase ?? t('cam_ready')
}

function Stat({ ill, v, l, tone, to }: { ill: IllName; v?: number | string; l: string; tone: string; to: string }) {
  return (
    <Link to={to} className={`tile tile-${tone} clickable`}>
      <div className="tile-art"><Ill name={ill} size={96} /></div>
      <div className="stat-v">{v ?? '…'}</div>
      <div className="stat-l">{l}</div>
    </Link>
  )
}
