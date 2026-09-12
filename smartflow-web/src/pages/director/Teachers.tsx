import { useState } from 'react'
import { director } from '../../api/endpoints'
import type { TeacherDto } from '../../api/types'
import { useT } from '../../i18n'
import { IcPlus } from '../../ui/icons'
import { Avatar, Empty, ErrorBox, errorText, Field, Modal, Skeleton, useAsync, useErrorMessage, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function Teachers() {
  const { t } = useT()
  const toast = useToast()
  const msg = useErrorMessage()
  const teachers = useAsync(() => director.teachers(), [])
  const classes = useAsync(() => director.classes(), [])
  const [adding, setAdding] = useState(false)
  const [assigning, setAssigning] = useState<TeacherDto | null>(null)
  const [form, setForm] = useState({ full_name: '', email: '', password: '', subject: '' })
  const [assign, setAssign] = useState({ class_id: 0, subject: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function create() {
    if (busy) return
    setBusy(true); setError(null)
    try {
      await director.createTeacher({ full_name: form.full_name.trim(), email: form.email.trim(), password: form.password, subject: form.subject.trim() || null })
      setAdding(false); setForm({ full_name: '', email: '', password: '', subject: '' }); teachers.reload(); toast(t('saved'))
    } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }
  async function doAssign() {
    if (!assigning || busy) return
    setBusy(true); setError(null)
    try {
      await director.assignClass(assigning.id, { class_id: assign.class_id, subject: assign.subject.trim() || assigning.subject || '' })
      setAssigning(null); toast(t('saved'))
    } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }

  return (
    <>
      <TopBar title={t('nav_teachers')} sub={t('teachers_n', teachers.data?.length ?? 0)}>
        <button className="btn primary" onClick={() => setAdding(true)}><IcPlus /> {t('add_teacher')}</button>
      </TopBar>
      <ErrorBox error={teachers.error} onRetry={teachers.reload} />
      {teachers.loading && !teachers.data && <Skeleton rows={5} h={64} />}
      {teachers.data?.length === 0 && <Empty ill="family" title={t('no_teachers')} />}
      <div className="grid c3">
        {teachers.data?.map((tc) => (
          <div key={tc.id} className="card">
            <div className="row">
              <Avatar first={tc.full_name.split(' ')[1] ?? ''} last={tc.full_name.split(' ')[0] ?? ''} id={tc.id} />
              <div className="grow">
                <div className="bold">{tc.full_name}</div>
                <div className="small muted">{tc.subject || '—'}</div>
                <div className="tiny faint">{tc.email}</div>
              </div>
            </div>
            <div className="row mt12">
              <button className="btn sm soft" onClick={() => { setAssigning(tc); setAssign({ class_id: classes.data?.[0]?.id ?? 0, subject: tc.subject ?? '' }); setError(null) }}>{t('assign_class')}</button>
              {tc.is_active === false && <span className="chip rose">{t('inactive')}</span>}
            </div>
          </div>
        ))}
      </div>
      {adding && (
        <Modal title={t('add_teacher')} onClose={() => setAdding(false)} actions={<>
          <button className="btn ghost" onClick={() => setAdding(false)}>{t('cancel')}</button>
          <button className="btn primary" disabled={busy || !form.full_name.trim() || !form.email.trim() || form.password.length < 4} onClick={create}>{t('save')}</button>
        </>}>
          <div className="col" style={{ gap: 12 }}>
            <Field label={t('full_name')}><input className="input" value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} autoFocus /></Field>
            <Field label={t('email')}><input className="input" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></Field>
            <Field label={t('password')}><input className="input" type="text" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} /></Field>
            <Field label={t('subject')}><input className="input" value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} placeholder="BackEnd #1" /></Field>
            {error && <div className="error-box">{msg(error)}</div>}
          </div>
        </Modal>
      )}
      {assigning && (
        <Modal title={t('assign_class')} lead={assigning.full_name} onClose={() => setAssigning(null)} actions={<>
          <button className="btn ghost" onClick={() => setAssigning(null)}>{t('cancel')}</button>
          <button className="btn primary" disabled={busy || !assign.class_id} onClick={doAssign}>{t('save')}</button>
        </>}>
          <div className="col" style={{ gap: 12 }}>
            <Field label={t('class')}>
              <select className="select" value={assign.class_id} onChange={(e) => setAssign({ ...assign, class_id: Number(e.target.value) })}>
                {classes.data?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </Field>
            <Field label={t('subject')}><input className="input" value={assign.subject} onChange={(e) => setAssign({ ...assign, subject: e.target.value })} /></Field>
            {error && <div className="error-box">{msg(error)}</div>}
          </div>
        </Modal>
      )}
    </>
  )
}
