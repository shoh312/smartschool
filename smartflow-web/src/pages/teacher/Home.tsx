import { Link } from 'react-router-dom'
import { teacher } from '../../api/endpoints'
import { useT } from '../../i18n'
import { useSession } from '../../App'
import { IcBook, IcFile, IcUsers } from '../../ui/icons'
import { Ill } from '../../ui/illustrations'
import { Empty, ErrorBox, Skeleton, todayIso, useAsync, useFmt } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

const TONES = ['brand', 'coral', 'sky', 'mint', 'amber']

export function TeacherHome() {
  const { t } = useT()
  const f = useFmt()
  const session = useSession()
  const classes = useAsync(() => teacher.classes(), [])
  const assignments = useAsync(() => teacher.assignments(), [])
  const open = (assignments.data ?? []).filter((a) => a.submitted_count < a.student_count).length

  return (
    <>
      <TopBar title={t('greeting', session?.fullName.split(' ')[0] ?? '')} sub={f.dateLong(todayIso())} />
      <div className="hero mb24">
        <div className="hero-art"><Ill name="book" size={230} /></div>
        <h2>{t('teacher_hero_title')}</h2>
        <p>{t('teacher_hero_body')}</p>
        <div className="row wrap mt16" style={{ gap: 8 }}>
          {session?.subject && <span className="pill-w"><IcBook /> {session.subject}</span>}
          <span className="pill-w"><IcUsers /> {t('classes_n', classes.data?.length ?? 0)}</span>
          {open > 0 && <span className="pill-w"><IcFile /> {t('open_assignments', open)}</span>}
        </div>
      </div>
      <div className="grid c3 mb24">
        <Link to="/materials" className="tile tile-brand clickable"><div className="tile-art"><Ill name="clipboard" size={110} /></div><div className="bold" style={{ fontSize: 16 }}>{t('nav_materials')}</div><div className="small muted">{t('materials_hint')}</div></Link>
        <Link to="/diary" className="tile tile-mint clickable"><div className="tile-art"><Ill name="notebook" size={110} /></div><div className="bold" style={{ fontSize: 16 }}>{t('nav_diary')}</div><div className="small muted">{t('diary_hint')}</div></Link>
        <Link to="/announcements" className="tile tile-amber clickable"><div className="tile-art"><Ill name="megaphone" size={110} /></div><div className="bold" style={{ fontSize: 16 }}>{t('nav_announcements')}</div><div className="small muted">{t('announcements_hint')}</div></Link>
      </div>
      <div className="section-title">{t('my_classes')}</div>
      <ErrorBox error={classes.error} onRetry={classes.reload} />
      {classes.loading && !classes.data && <Skeleton rows={3} h={80} />}
      {classes.data?.length === 0 && <Empty ill="backpack" title={t('no_classes')} body={t('no_classes_teacher')} />}
      <div className="grid c3">
        {classes.data?.map((c) => (
          <Link key={c.id} to={`/journal/${c.class_id}/${encodeURIComponent(c.subject ?? '')}`} className="card clickable">
            <div className="row">
              <div className="stat-ic" style={{ background: `var(--${TONES[c.class_id % 5]}-soft)`, color: `var(--${TONES[c.class_id % 5]})` }}><IcUsers /></div>
              <div className="grow">
                <div className="bold" style={{ fontSize: 16 }}>{c.class_name}</div>
                {c.subject && c.subject !== c.class_name && <div className="small muted">{c.subject}</div>}
              </div>
              <span className="chip brand">{t('journal')}</span>
            </div>
          </Link>
        ))}
      </div>
    </>
  )
}
