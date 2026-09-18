import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { director } from '../../api/endpoints'
import type { ClassDto, StudentDto } from '../../api/types'
import { useT } from '../../i18n'
import { IcEdit, IcPlus, IcSearch, IcTrash } from '../../ui/icons'
import { Avatar, Confirm, Empty, ErrorBox, errorText, Field, Modal, Skeleton, useAsync, useErrorMessage, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function Students() {
  const { t } = useT()
  const nav = useNavigate()
  const toast = useToast()
  const students = useAsync(() => director.students(), [])
  const classes = useAsync(() => director.classes(), [])
  const [q, setQ] = useState('')
  const [cls, setCls] = useState<number | 'all'>('all')
  const [editing, setEditing] = useState<StudentDto | null | 'new'>(null)
  const [deleting, setDeleting] = useState<StudentDto | null>(null)

  const list = useMemo(() => {
    const needle = q.trim().toLowerCase()
    return (students.data ?? [])
      .filter((s) => cls === 'all' || s.class_id === cls)
      .filter((s) => !needle || `${s.last_name} ${s.first_name} ${s.parent_phone ?? ''} ${s.username ?? ''}`.toLowerCase().includes(needle))
      .sort((a, b) => a.last_name.localeCompare(b.last_name))
  }, [students.data, q, cls])

  async function remove() {
    if (!deleting) return
    try { await director.deleteStudent(deleting.id); toast(t('deleted')); students.reload() } catch (e) { toast(errorText(e)) }
    setDeleting(null)
  }

  return (
    <>
      <TopBar title={t('nav_students')} sub={t('students_n', students.data?.length ?? 0)}>
        <button className="btn primary" onClick={() => setEditing('new')}><IcPlus /> {t('add_student')}</button>
      </TopBar>
      <div className="row mb16">
        <div className="search grow"><IcSearch /><input className="input" placeholder={t('search')} value={q} onChange={(e) => setQ(e.target.value)} /></div>
        <select className="select" style={{ width: 220 }} value={cls} onChange={(e) => setCls(e.target.value === 'all' ? 'all' : Number(e.target.value))}>
          <option value="all">{t('all_classes')}</option>
          {classes.data?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
      </div>
      <ErrorBox error={students.error} onRetry={students.reload} />
      {students.loading && !students.data && <Skeleton rows={8} h={52} />}
      {students.data && list.length === 0 && <Empty ill="backpack" title={t('no_pupils')} />}
      {list.length > 0 && (
        <div className="card" style={{ padding: 0 }}>
          <table className="table">
            <thead><tr><th style={{ width: 56 }}></th><th>{t('name')}</th><th>{t('class')}</th><th>{t('parent')}</th><th>{t('login')}</th><th></th></tr></thead>
            <tbody>
              {list.map((s) => (
                <tr key={s.id} className="clickable" onClick={() => nav(`/students/${s.id}`)}>
                  <td><Avatar first={s.first_name} last={s.last_name} id={s.id} /></td>
                  <td className="bold">{s.last_name} {s.first_name}</td>
                  <td><span className="chip brand">{s.class_name ?? '—'}</span></td>
                  <td className="small muted">{s.parent_name && s.parent_name !== s.parent_phone ? `${s.parent_name} · ` : ''}{s.parent_phone ?? '—'}</td>
                  <td className="small muted">{s.username ?? '—'}</td>
                  <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }} onClick={(e) => e.stopPropagation()}>
                    <button className="btn ghost icon sm" onClick={() => setEditing(s)}><IcEdit /></button>{' '}
                    <button className="btn ghost icon sm" onClick={() => setDeleting(s)}><IcTrash /></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {editing && <StudentForm student={editing === 'new' ? null : editing} classes={classes.data ?? []} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); students.reload() }} />}
      {deleting && <Confirm danger title={t('delete_student_q', `${deleting.last_name} ${deleting.first_name}`)} body={t('delete_student_body')} onNo={() => setDeleting(null)} onYes={remove} />}
    </>
  )
}

export function StudentForm({ student, classes, onClose, onSaved }: { student: StudentDto | null; classes: ClassDto[]; onClose: () => void; onSaved: () => void }) {
  const { t } = useT()
  const toast = useToast()
  const msg = useErrorMessage()
  const [first, setFirst] = useState(student?.first_name ?? '')
  const [last, setLast] = useState(student?.last_name ?? '')
  const [classId, setClassId] = useState<number>(student?.class_id ?? classes[0]?.id ?? 0)
  const [phone, setPhone] = useState(student?.parent_phone ?? '')
  const [parentName, setParentName] = useState(student?.parent_name ?? '')
  const [username, setUsername] = useState(student?.username ?? '')
  const [password, setPassword] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const valid = first.trim() && last.trim() && classId && (student || (phone.trim() && file))

  async function save() {
    if (!valid || busy) return
    setBusy(true); setError(null)
    const fd = new FormData()
    fd.set('first_name', first.trim()); fd.set('last_name', last.trim()); fd.set('class_id', String(classId))
    try {
      if (student) {
        if (phone.trim()) fd.set('parent_phone', phone.trim())
        if (username.trim()) fd.set('username', username.trim())
        if (password) fd.set('password', password)
        if (file) fd.set('file', file)
        await director.updateStudent(student.id, fd)
      } else {
        fd.set('parent_phone', phone.trim())
        if (parentName.trim()) fd.set('parent_full_name', parentName.trim())
        if (username.trim()) fd.set('username', username.trim())
        if (password) fd.set('password', password)
        fd.set('file', file!)
        await director.createStudent(fd)
      }
      toast(t('saved')); onSaved()
    } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }

  return (
    <Modal title={student ? t('edit_student') : t('add_student')} lead={student ? undefined : t('add_student_lead')} onClose={onClose} actions={<>
      <button className="btn ghost" onClick={onClose}>{t('cancel')}</button>
      <button className="btn primary" disabled={!valid || busy} onClick={save}>{busy ? t('saving') : t('save')}</button>
    </>}>
      <div className="grid c2" style={{ gap: 12 }}>
        <Field label={t('last_name')}><input className="input" value={last} onChange={(e) => setLast(e.target.value)} autoFocus /></Field>
        <Field label={t('first_name')}><input className="input" value={first} onChange={(e) => setFirst(e.target.value)} /></Field>
        <Field label={t('class')}>
          <select className="select" value={classId} onChange={(e) => setClassId(Number(e.target.value))}>
            {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </Field>
        <Field label={t('parent_phone')}><input className="input" placeholder="+992 9xx xx xx xx" value={phone} onChange={(e) => setPhone(e.target.value)} /></Field>
        {!student && <Field label={t('parent_name')}><input className="input" value={parentName} onChange={(e) => setParentName(e.target.value)} /></Field>}
        <Field label={t('login')}><input className="input" autoComplete="off" value={username} onChange={(e) => setUsername(e.target.value)} placeholder={student ? undefined : t('login_auto')} /></Field>
        <Field label={student ? t('new_password') : t('password')}><input className="input" type="password" autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder={student ? t('leave_empty') : t('login_auto')} /></Field>
        <Field label={student ? t('photo_optional') : t('photo_required')}>
          <input className="input" type="file" accept="image/*" style={{ paddingTop: 9 }} onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
          <span className="tiny faint">{t('photo_hint')}</span>
        </Field>
      </div>
      {error && <div className="error-box mt12">{msg(error)}</div>}
    </Modal>
  )
}
