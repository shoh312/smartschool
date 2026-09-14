import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { director } from '../../api/endpoints'
import type { LiveStatusDto } from '../../api/types'
import { useT } from '../../i18n'
import { IcCheck, IcUsers, IcX } from '../../ui/icons'
import { Avatar, Empty, ErrorBox, errorText, Skeleton, useAsync, useFmt, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

const TONES = ['brand', 'coral', 'sky', 'mint', 'amber']

/** /test — mark attendance by hand: every group, then its pupils with a tick. */
export function ManualAttendance() {
  const { t } = useT()
  const nav = useNavigate()
  const toast = useToast()
  const f = useFmt()
  const classId = useParams().id ? Number(useParams().id) : null
  const classes = useAsync(() => director.classes(), [])
  const students = useAsync(() => director.students(), [])
  const [live, setLive] = useState<Map<number, LiveStatusDto>>(new Map())
  const [busy, setBusy] = useState<number | null>(null)

  async function refreshLive() {
    try { const l = await director.liveStatus(); setLive(new Map(l.map((x) => [x.student_id, x]))) } catch {}
  }
  useEffect(() => { refreshLive() }, [])

  async function mark(studentId: number, status: 'present' | 'absent') {
    if (busy) return
    setBusy(studentId)
    try { await director.markAttendance(studentId, status); await refreshLive(); toast(status === 'present' ? t('marked_present') : t('marked_absent')) } catch (e) { toast(errorText(e)) } finally { setBusy(null) }
  }

  if (classId == null) {
    return (
      <>
        <TopBar title={t('manual_attendance')} sub={t('manual_attendance_sub')} />
        <ErrorBox error={classes.error} onRetry={classes.reload} />
        {classes.loading && !classes.data && <Skeleton rows={3} h={90} />}
        {classes.data?.length === 0 && <Empty ill="school" title={t('no_classes')} />}
        <div className="grid c3">
          {classes.data?.map((c) => {
            const pupils = (students.data ?? []).filter((s) => s.class_id === c.id)
            const present = pupils.filter((s) => ['present', 'late'].includes(live.get(s.id)?.status ?? '')).length
            return (
              <button key={c.id} className="card clickable" style={{ textAlign: 'left' }} onClick={() => nav(`/test/${c.id}`)}>
                <div className="row">
                  <div className="stat-ic" style={{ background: `var(--${TONES[c.id % 5]}-soft)`, color: `var(--${TONES[c.id % 5]})` }}><IcUsers /></div>
                  <div className="grow">
                    <div className="bold" style={{ fontSize: 16 }}>{c.name}</div>
                    <div className="small muted">{t('pupils_n', pupils.length)} · {t('present_now', present)}</div>
                  </div>
                </div>
              </button>
            )
          })}
        </div>
      </>
    )
  }

  const cls = classes.data?.find((c) => c.id === classId)
  const pupils = (students.data ?? []).filter((s) => s.class_id === classId).sort((a, b) => a.last_name.localeCompare(b.last_name))
  const present = pupils.filter((s) => ['present', 'late'].includes(live.get(s.id)?.status ?? '')).length

  return (
    <>
      <TopBar title={cls?.name ?? '…'} sub={`${f.dateLong(new Date().toISOString().slice(0, 10))} · ${t('present_now', present)} / ${pupils.length}`} back={() => nav('/test')} />
      {students.loading && !students.data && <Skeleton rows={8} h={56} />}
      {students.data && pupils.length === 0 && <Empty ill="backpack" title={t('no_pupils')} />}
      {pupils.length > 0 && (
        <div className="card" style={{ padding: 0 }}>
          <table className="table">
            <thead><tr><th style={{ width: 56 }}></th><th>{t('name')}</th><th>{t('status')}</th><th style={{ textAlign: 'right' }}>{t('mark')}</th></tr></thead>
            <tbody>
              {pupils.map((s) => {
                const st = live.get(s.id)?.status ?? 'not_detected'
                const came = st === 'present' || st === 'late'
                const tone = came ? 'mint' : st === 'absent' ? 'rose' : st === 'left_school' ? 'amber' : ''
                return (
                  <tr key={s.id}>
                    <td><Avatar first={s.first_name} last={s.last_name} id={s.id} /></td>
                    <td className="bold">{s.last_name} {s.first_name}<div className="tiny faint" style={{ fontWeight: 500 }}>{live.get(s.id)?.time_in ? f.time(live.get(s.id)!.time_in) : ''}</div></td>
                    <td><span className={'chip ' + tone}>{t('st_' + st)}</span></td>
                    <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
                      <button className={'btn sm ' + (came ? 'ghost' : 'primary')} disabled={busy === s.id || came} onClick={() => mark(s.id, 'present')}><IcCheck /> {t('came')}</button>{' '}
                      <button className={'btn sm ' + (st === 'absent' ? 'ghost' : 'danger')} disabled={busy === s.id || st === 'absent'} onClick={() => mark(s.id, 'absent')}><IcX /> {t('did_not_come')}</button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </>
  )
}
