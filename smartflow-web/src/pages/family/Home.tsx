import { Link, Navigate } from 'react-router-dom'
import { useSession } from '../../App'
import { family } from '../../api/endpoints'
import { useT } from '../../i18n'
import { Avatar, ErrorBox, Skeleton, useAsync } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'
import { Ill } from '../../ui/illustrations'
import { IcNext } from '../../ui/icons'

/** Parent landing: the children on this account. A pupil skips straight to their own dashboard. */
export function FamilyHome() {
  const { t } = useT()
  const session = useSession()
  const kids = useAsync(() => family.children(), [])

  if (session?.role === 'student') return <Navigate to={`/child/${session.id}`} replace />

  return (
    <>
      <TopBar title={t('family_children')} sub={t('family_children_sub')} />
      <ErrorBox error={kids.error} onRetry={kids.reload} />
      {kids.loading && <div className="grid auto"><Skeleton rows={2} h={96} /></div>}
      {kids.data && kids.data.length === 0 && (
        <div className="card" style={{ textAlign: 'center', padding: 40 }}>
          <Ill name="family" size={120} />
          <div className="bold mt12">{t('family_no_children')}</div>
          <div className="small muted">{t('family_no_children_body')}</div>
        </div>
      )}
      <div className="grid auto">
        {kids.data?.map((c) => (
          <Link key={c.id} to={`/child/${c.id}`} className="card clickable">
            <div className="row">
              <Avatar first={c.first_name} last={c.last_name} id={c.id} size="lg" />
              <div className="grow">
                <div className="bold" style={{ fontSize: 16 }}>{c.last_name} {c.first_name}</div>
                <div className="small muted">{c.class_name || t('family_no_class')}</div>
              </div>
              <IcNext />
            </div>
          </Link>
        ))}
      </div>
    </>
  )
}
