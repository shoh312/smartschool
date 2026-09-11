import { useState } from 'react'
import { director, teacher } from '../../api/endpoints'
import type { AnnouncementDto } from '../../api/types'
import { useT } from '../../i18n'
import { useSession } from '../../App'
import { IcPlus, IcTrash } from '../../ui/icons'
import { Confirm, Empty, ErrorBox, errorText, Field, Modal, Skeleton, useAsync, useErrorMessage, useFmt, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function Announcements() {
  const { t } = useT()
  const f = useFmt()
  const toast = useToast()
  const msg = useErrorMessage()
  const session = useSession()
  const isDirector = session?.role === 'director'
  const list = useAsync(() => (isDirector ? director.announcements() : teacher.announcements()), [isDirector])
  const classes = useAsync(() => (isDirector ? director.classes() : Promise.resolve([])), [isDirector])
  const [adding, setAdding] = useState(false)
  const [deleting, setDeleting] = useState<AnnouncementDto | null>(null)
  const [form, setForm] = useState({ title: '', body: '', class_id: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function create() {
    if (busy || !form.title.trim() || !form.body.trim()) return
    setBusy(true); setError(null)
    try {
      await director.createAnnouncement({ title: form.title.trim(), body: form.body.trim(), class_id: form.class_id ? Number(form.class_id) : null })
      setAdding(false); setForm({ title: '', body: '', class_id: '' }); list.reload(); toast(t('sent'))
    } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }
  async function remove() {
    if (!deleting) return
    try { await director.deleteAnnouncement(deleting.id); list.reload() } catch (e) { toast(errorText(e)) }
    setDeleting(null)
  }
  const sorted = [...(list.data ?? [])].sort((a, b) => (b.created_at ?? '').localeCompare(a.created_at ?? ''))

  return (
    <>
      <TopBar title={t('nav_announcements')} sub={t('announcements_sub')}>
        {isDirector && <button className="btn primary" onClick={() => setAdding(true)}><IcPlus /> {t('new_announcement')}</button>}
      </TopBar>
      <ErrorBox error={list.error} onRetry={list.reload} />
      {list.loading && !list.data && <Skeleton rows={4} h={90} />}
      {list.data?.length === 0 && <Empty icon="📣" title={t('no_announcements')} />}
      <div className="col" style={{ gap: 12, maxWidth: 820 }}>
        {sorted.map((a) => (
          <div key={a.id} className="card">
            <div className="row" style={{ alignItems: 'flex-start' }}>
              <div className="grow">
                <div className="bold" style={{ fontSize: 15 }}>{a.title}</div>
                <div className="tiny faint mt8">{f.dateTime(a.created_at)}{a.class_id ? ` · ${classes.data?.find((c) => c.id === a.class_id)?.name ?? ''}` : ` · ${t('whole_school')}`}</div>
              </div>
              {isDirector && <button className="btn ghost icon sm" onClick={() => setDeleting(a)}><IcTrash /></button>}
            </div>
            <p className="mt12" style={{ whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{a.body}</p>
          </div>
        ))}
      </div>
      {adding && (
        <Modal title={t('new_announcement')} onClose={() => setAdding(false)} actions={<>
          <button className="btn ghost" onClick={() => setAdding(false)}>{t('cancel')}</button>
          <button className="btn primary" disabled={busy || !form.title.trim() || !form.body.trim()} onClick={create}>{t('send')}</button>
        </>}>
          <div className="col" style={{ gap: 12 }}>
            <Field label={t('title')}><input className="input" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} autoFocus /></Field>
            <Field label={t('text')}><textarea className="textarea" value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} /></Field>
            <Field label={t('recipients')}>
              <select className="select" value={form.class_id} onChange={(e) => setForm({ ...form, class_id: e.target.value })}>
                <option value="">{t('whole_school')}</option>
                {classes.data?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </Field>
            {error && <div className="error-box">{msg(error)}</div>}
          </div>
        </Modal>
      )}
      {deleting && <Confirm danger title={t('delete_q')} onNo={() => setDeleting(null)} onYes={remove} />}
    </>
  )
}
