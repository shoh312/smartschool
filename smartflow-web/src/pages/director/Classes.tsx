import { useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { director } from '../../api/endpoints'
import { useT } from '../../i18n'
import { IcBook, IcPlus, IcTrash, IcUsers } from '../../ui/icons'
import { Avatar, Confirm, Empty, ErrorBox, Field, fmtAvg, Grade, gradeClass, Modal, Skeleton, useAsync, useToast, errorText } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

const TONES = ['brand', 'coral', 'sky', 'mint', 'amber']

export function Classes() {
  const { t } = useT()
  const toast = useToast()
  const classes = useAsync(() => director.classes(), [])
  const students = useAsync(() => director.students(), [])
  const [adding, setAdding] = useState(false)
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)
  const counts = useMemo(() => {
    const m = new Map<number, number>()
    for (const s of students.data ?? []) if (s.class_id != null) m.set(s.class_id, (m.get(s.class_id) ?? 0) + 1)
    return m
  }, [students.data])

  async function create() {
    if (!name.trim() || busy) return
    setBusy(true)
    try {
      await director.createClass({ name: name.trim() })
      setAdding(false); setName(''); classes.reload(); toast(t('saved'))
    } catch (e) { toast(errorText(e)) } finally { setBusy(false) }
  }

  return (
    <>
      <TopBar title={t('nav_classes')} sub={t('classes_sub')}>
        <button className="btn primary" onClick={() => setAdding(true)}><IcPlus /> {t('add_class')}</button>
      </TopBar>
      <ErrorBox error={classes.error} onRetry={classes.reload} />
      {classes.loading && !classes.data && <div className="grid c3"><Skeleton rows={1} h={110} /><Skeleton rows={1} h={110} /><Skeleton rows={1} h={110} /></div>}
      {classes.data && classes.data.length === 0 && <Empty ill="school" title={t('no_classes')} body={t('no_classes_body')} />}
      <div className="grid c3">
        {classes.data?.map((c) => (
          <Link key={c.id} to={`/classes/${c.id}`} className="card clickable">
            <div className="row">
              <div className="stat-ic" style={{ background: `var(--${TONES[c.id % 5]}-soft)`, color: `var(--${TONES[c.id % 5]})` }}><IcUsers /></div>
              <div className="grow">
                <div className="bold" style={{ fontSize: 16 }}>{c.name}</div>
                <div className="small muted">{t('pupils_n', counts.get(c.id) ?? 0)}{c.start_time ? ` · ${c.start_time.slice(0, 5)}${c.end_time ? '–' + c.end_time.slice(0, 5) : ''}` : ''}</div>
              </div>
            </div>
          </Link>
        ))}
      </div>
      {adding && (
        <Modal title={t('add_class')} onClose={() => setAdding(false)} actions={<>
          <button className="btn ghost" onClick={() => setAdding(false)}>{t('cancel')}</button>
          <button className="btn primary" disabled={!name.trim() || busy} onClick={create}>{t('save')}</button>
        </>}>
          <Field label={t('class_name')}><input className="input" value={name} onChange={(e) => setName(e.target.value)} autoFocus placeholder="BackEnd #2" /></Field>
        </Modal>
      )}
    </>
  )
}

export function ClassDetail() {
  const { t } = useT()
  const nav = useNavigate()
  const toast = useToast()
  const id = Number(useParams().id)
  const classes = useAsync(() => director.classes(), [])
  const students = useAsync(() => director.students(), [])
  const subjects = useAsync(() => director.classSubjects(id), [id])
  const averages = useAsync(() => director.classSubjectAverages(id), [id])
  const ranking = useAsync(() => director.classRanking(id), [id])
  const [deleting, setDeleting] = useState(false)
  const cls = classes.data?.find((c) => c.id === id)
  const pupils = (students.data ?? []).filter((s) => s.class_id === id).sort((a, b) => a.last_name.localeCompare(b.last_name))
  const ranks = new Map((ranking.data ?? []).map((r) => [r.student_id, r]))

  async function remove() {
    try { await director.deleteClass(id); toast(t('deleted')); nav('/classes') } catch (e) { toast(errorText(e)) }
    setDeleting(false)
  }

  return (
    <>
      <TopBar title={cls?.name ?? '…'} sub={t('pupils_n', pupils.length)} back={() => nav('/classes')}>
        <button className="btn gold" onClick={() => nav(`/classes/${id}/journal`)}><IcBook /> {t('journal')}</button>
        <button className="btn ghost icon" title={t('delete')} onClick={() => setDeleting(true)}><IcTrash /></button>
      </TopBar>
      <div className="grid" style={{ gridTemplateColumns: '1.4fr 1fr' }}>
        <div className="card">
          <div className="card-title">{t('pupils')}</div>
          {students.loading && !students.data && <Skeleton rows={6} h={48} />}
          {students.data && pupils.length === 0 && <Empty ill="backpack" title={t('no_pupils')} />}
          <table className="table">
            <tbody>
              {pupils.map((s) => {
                const r = ranks.get(s.id)
                return (
                  <tr key={s.id} className="clickable" onClick={() => nav(`/students/${s.id}`)}>
                    <td style={{ width: 48 }}><Avatar first={s.first_name} last={s.last_name} id={s.id} size="sm" /></td>
                    <td><div className="bold">{s.last_name} {s.first_name}</div><div className="tiny faint">{s.parent_phone ?? ''}</div></td>
                    <td style={{ textAlign: 'right' }}>{r?.overall_average != null ? <span className={'chip ' + gradeClass(r.overall_average).replace('g-hi', 'mint').replace('g-mid', 'amber').replace('g-lo', 'rose')}>#{r.position} · {fmtAvg(r.overall_average)}</span> : <span className="chip">—</span>}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        <div className="col" style={{ gap: 16 }}>
          <div className="card">
            <div className="card-title">{t('subjects_avg')}</div>
            <ErrorBox error={averages.error} onRetry={averages.reload} />
            {averages.data?.length === 0 && <div className="muted small">{t('no_marks_yet')}</div>}
            <div className="col">
              {averages.data?.map((s) => (
                <div key={s.subject} className="row">
                  <div className="small bold" style={{ width: 120 }} title={s.subject}>{s.subject}</div>
                  <div className="bar grow"><i style={{ width: `${Math.min(100, (s.average / 10) * 100)}%`, background: s.average >= 8 ? 'var(--mint)' : s.average >= 6 ? 'var(--amber)' : 'var(--rose)' }} /></div>
                  <Grade v={s.average} />
                </div>
              ))}
            </div>
          </div>
          <div className="card">
            <div className="card-title">{t('teachers_of_class')}</div>
            {subjects.data?.length === 0 && <div className="muted small">{t('no_teachers_assigned')}</div>}
            <div className="col" style={{ gap: 8 }}>
              {subjects.data?.map((s) => (
                <div key={s.id} className="row">
                  <div className="grow small bold">{s.subject ?? '—'}</div>
                  <div className="small muted">{s.teacher_name}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
      {deleting && <Confirm danger title={t('delete_class_q')} body={t('delete_class_body')} onNo={() => setDeleting(false)} onYes={remove} />}
    </>
  )
}
