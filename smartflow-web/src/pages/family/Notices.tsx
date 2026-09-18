import { useSession } from '../../App'
import { family } from '../../api/endpoints'
import { useT } from '../../i18n'
import { ErrorBox, Skeleton, useAsync, useFmt } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'
import { Ill } from '../../ui/illustrations'

/**
 * Announcements, calendar and (for a parent) the alert history. Announcements
 * and events belong to a class, so we read them for the first child; for a
 * pupil that is simply their own record.
 */
export function FamilyNotices() {
  const { t } = useT()
  const f = useFmt()
  const session = useSession()
  const kids = useAsync(() => family.children(), [])
  const anchor = session?.role === 'student' ? session.id : kids.data?.[0]?.id
  const ann = useAsync(() => (anchor ? family.announcements(anchor) : Promise.resolve([])), [anchor])
  const cal = useAsync(() => (anchor ? family.calendar(anchor) : Promise.resolve([])), [anchor])
  const notif = useAsync(() => (session?.role === 'parent' ? family.notifications(session.id) : Promise.resolve([])), [session?.id])

  return (
    <>
      <TopBar title={t('nav_notices')} sub={t('family_notices_sub')} />
      <div className="grid c2" style={{ alignItems: 'start' }}>
        <div className="col" style={{ gap: 16 }}>
          <div className="card">
            <div className="card-title"><Ill name="megaphone" size={30} /> {t('nav_announcements')}</div>
            {ann.loading && <Skeleton rows={2} h={54} />}
            <ErrorBox error={ann.error} onRetry={ann.reload} />
            {ann.data && ann.data.length === 0 && <div className="small muted">{t('ann_empty')}</div>}
            {ann.data?.map((a) => (
              <div key={a.id} style={{ padding: '10px 0', borderBottom: '1px solid var(--border)' }}>
                <div className="bold">{a.title}</div>
                <div className="small muted">{a.body}</div>
                {a.created_at && <div className="tiny faint mt8">{f.dateTime(a.created_at)}</div>}
              </div>
            ))}
          </div>
          {session?.role === 'parent' && (
            <div className="card">
              <div className="card-title"><Ill name="bell" size={30} /> {t('family_alerts')}</div>
              {notif.loading && <Skeleton rows={2} h={48} />}
              {notif.data && notif.data.length === 0 && <div className="small muted">{t('family_alerts_empty')}</div>}
              {notif.data?.slice(0, 40).map((n) => (
                <div key={n.id} className="row" style={{ padding: '9px 0', borderBottom: '1px solid var(--border)' }}>
                  <div className="grow"><div className="bold small">{n.title}</div><div className="small muted">{n.body}</div></div>
                  <div className="tiny faint">{f.dateTime(n.sent_at || n.created_at)}</div>
                </div>
              ))}
            </div>
          )}
        </div>
        <div className="card">
          <div className="card-title"><Ill name="calendar" size={30} /> {t('nav_calendar')}</div>
          {cal.loading && <Skeleton rows={2} h={54} />}
          <ErrorBox error={cal.error} onRetry={cal.reload} />
          {cal.data && cal.data.length === 0 && <div className="small muted">{t('cal_empty')}</div>}
          {cal.data?.map((e) => (
            <div key={e.id} className="row" style={{ padding: '10px 0', borderBottom: '1px solid var(--border)' }}>
              <div className="cal-chip"><b>{new Date(e.start_date + 'T00:00:00').getDate()}</b><span>{f.weekday(e.start_date)}</span></div>
              <div className="grow"><div className="bold">{e.title}</div>{e.description && <div className="small muted">{e.description}</div>}</div>
            </div>
          ))}
        </div>
      </div>
    </>
  )
}
