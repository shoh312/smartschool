import { useMemo, useState } from 'react'
import { director, teacher } from '../../api/endpoints'
import type { CalendarEventDto } from '../../api/types'
import { useT } from '../../i18n'
import { useSession } from '../../App'
import { IcBack, IcNext, IcPlus, IcTrash } from '../../ui/icons'
import { addDays, Confirm, ErrorBox, errorText, Field, Modal, Skeleton, todayIso, useAsync, useErrorMessage, useFmt, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

const TYPES = ['event', 'exam', 'holiday', 'meeting']
const TONE: Record<string, string> = { event: 'brand', exam: 'rose', holiday: 'mint', meeting: 'amber' }

export function Calendar() {
  const { t, lang } = useT()
  const f = useFmt()
  const toast = useToast()
  const msg = useErrorMessage()
  const session = useSession()
  const isDirector = session?.role === 'director'
  const events = useAsync(() => (isDirector ? director.calendar() : teacher.calendar()), [isDirector])
  const classes = useAsync(() => (isDirector ? director.classes() : Promise.resolve([])), [isDirector])
  const [month, setMonth] = useState(() => todayIso().slice(0, 7))
  const [adding, setAdding] = useState<string | null>(null)
  const [deleting, setDeleting] = useState<CalendarEventDto | null>(null)
  const [form, setForm] = useState({ title: '', description: '', event_type: 'event', end_date: '', class_id: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const days = useMemo(() => {
    const [y, m] = month.split('-').map(Number)
    const first = new Date(y, m - 1, 1)
    const offset = (first.getDay() + 6) % 7 // Monday first
    const count = new Date(y, m, 0).getDate()
    const cells: (string | null)[] = Array.from({ length: offset }, () => null)
    for (let d = 1; d <= count; d++) cells.push(`${month}-${String(d).padStart(2, '0')}`)
    while (cells.length % 7) cells.push(null)
    return cells
  }, [month])
  const byDay = useMemo(() => {
    const m = new Map<string, CalendarEventDto[]>()
    for (const e of events.data ?? []) {
      const end = e.end_date ?? e.start_date
      for (let d = e.start_date; d <= end; d = addDays(d, 1)) { m.set(d, [...(m.get(d) ?? []), e]); if (d > end) break }
    }
    return m
  }, [events.data])
  const today = todayIso()
  const monthLabel = new Date(month + '-01T00:00:00').toLocaleDateString({ tg: 'tg-TJ', ru: 'ru-RU', en: 'en-GB' }[lang], { month: 'long', year: 'numeric' })

  async function create() {
    if (!adding || busy || !form.title.trim()) return
    setBusy(true); setError(null)
    try {
      await director.createEvent({ title: form.title.trim(), description: form.description.trim() || null, event_type: form.event_type, start_date: adding, end_date: form.end_date || null, class_id: form.class_id ? Number(form.class_id) : null })
      setAdding(null); setForm({ title: '', description: '', event_type: 'event', end_date: '', class_id: '' }); events.reload(); toast(t('saved'))
    } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }
  async function remove() {
    if (!deleting) return
    try { await director.deleteEvent(deleting.id); events.reload() } catch (e) { toast(errorText(e)) }
    setDeleting(null)
  }

  return (
    <>
      <TopBar title={t('nav_calendar')} sub={t('calendar_sub')}>
        <button className="btn ghost icon" onClick={() => setMonth(shiftMonth(month, -1))}><IcBack /></button>
        <div className="bold" style={{ minWidth: 150, textAlign: 'center', textTransform: 'capitalize' }}>{monthLabel}</div>
        <button className="btn ghost icon" onClick={() => setMonth(shiftMonth(month, 1))}><IcNext /></button>
        {isDirector && <button className="btn primary" onClick={() => setAdding(today)}><IcPlus /> {t('new_event')}</button>}
      </TopBar>
      <ErrorBox error={events.error} onRetry={events.reload} />
      {events.loading && !events.data && <Skeleton rows={3} h={120} />}
      {events.data && (
        <div className="card" style={{ padding: 14 }}>
          <div className="grid" style={{ gridTemplateColumns: 'repeat(7, 1fr)', gap: 8 }}>
            {['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].map((d) => <div key={d} className="tiny faint bold" style={{ textAlign: 'center', textTransform: 'uppercase', letterSpacing: '.06em' }}>{t('day_' + d)}</div>)}
            {days.map((d, i) => (
              <div key={i} className={'day-col' + (d === today ? ' today' : '')} style={{ opacity: d ? 1 : 0, cursor: isDirector && d ? 'pointer' : 'default' }} onClick={() => isDirector && d && setAdding(d)}>
                {d && <div className="small bold" style={{ color: d === today ? 'var(--brand)' : 'var(--ink-2)' }}>{Number(d.slice(-2))}</div>}
                {d && byDay.get(d)?.map((e) => (
                  <div key={e.id} className="event row" style={{ background: `var(--${TONE[e.event_type] ?? 'brand'}-soft)`, color: `var(--${TONE[e.event_type] ?? 'brand'})` }} onClick={(ev) => { ev.stopPropagation(); if (isDirector) setDeleting(e) }} title={e.description ?? ''}>
                    <span className="grow ellipsis">{e.title}</span>
                    {isDirector && <IcTrash style={{ width: 13, height: 13, opacity: .6 }} />}
                  </div>
                ))}
              </div>
            ))}
          </div>
        </div>
      )}
      {adding && (
        <Modal title={t('new_event')} lead={f.dateLong(adding)} onClose={() => setAdding(null)} actions={<>
          <button className="btn ghost" onClick={() => setAdding(null)}>{t('cancel')}</button>
          <button className="btn primary" disabled={busy || !form.title.trim()} onClick={create}>{t('save')}</button>
        </>}>
          <div className="col" style={{ gap: 12 }}>
            <Field label={t('title')}><input className="input" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} autoFocus /></Field>
            <div className="grid c2" style={{ gap: 12 }}>
              <Field label={t('type')}>
                <select className="select" value={form.event_type} onChange={(e) => setForm({ ...form, event_type: e.target.value })}>{TYPES.map((x) => <option key={x} value={x}>{t('ev_' + x)}</option>)}</select>
              </Field>
              <Field label={t('end_date_optional')}><input className="input" type="date" value={form.end_date} min={adding} onChange={(e) => setForm({ ...form, end_date: e.target.value })} /></Field>
            </div>
            <Field label={t('recipients')}>
              <select className="select" value={form.class_id} onChange={(e) => setForm({ ...form, class_id: e.target.value })}>
                <option value="">{t('whole_school')}</option>
                {classes.data?.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </Field>
            <Field label={t('description')}><textarea className="textarea" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></Field>
            {error && <div className="error-box">{msg(error)}</div>}
          </div>
        </Modal>
      )}
      {deleting && <Confirm danger title={t('delete_event_q', deleting.title)} onNo={() => setDeleting(null)} onYes={remove} />}
    </>
  )
}

function shiftMonth(ym: string, n: number) { const [y, m] = ym.split('-').map(Number); const d = new Date(y, m - 1 + n, 1); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}` }
