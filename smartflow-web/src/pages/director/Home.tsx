import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { director } from '../../api/endpoints'
import type { CameraStatusDto, LiveStatusDto } from '../../api/types'
import { useT } from '../../i18n'
import { useSession } from '../../App'
import { IcBook, IcCheck, IcNext } from '../../ui/icons'
import { Ill, type IllName } from '../../ui/illustrations'
import { Avatar, ErrorBox, Grade, Skeleton, useAsync, useFmt } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

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
    tick()
    const id = window.setInterval(tick, 5000)
    return () => { alive = false; window.clearInterval(id) }
  }, [])

  const today = new Date()
  const present = live.filter((s) => s.status === 'present' || s.status === 'late').length
  const inLesson = live.filter((s) => s.class_lesson_state === 'running')
  const online = cams.filter((c) => c.connected).length
  const todayIso = today.toISOString().slice(0, 10)
  const upcoming = (events.data ?? []).filter((e) => (e.end_date ?? e.start_date) >= todayIso).sort((a, b) => a.start_date.localeCompare(b.start_date)).slice(0, 4)

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

      <div className="grid c4 mb24">
        <Stat to="/classes" ill="school" tone="brand" v={classes.data?.length} l={t('nav_classes')} />
        <Stat to="/students" ill="backpack" tone="mint" v={students.data?.length} l={t('nav_students')} />
        <Stat to="/teachers" ill="family" tone="amber" v={teachers.data?.length} l={t('nav_teachers')} />
        <Stat to="/cameras" ill="door_check" tone="sky" v={`${online}/${cams.length}`} l={t('cams_online_l')} />
      </div>

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
