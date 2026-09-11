import { useState } from 'react'
import { teacher } from '../../api/endpoints'
import type { DiaryEntryDto } from '../../api/types'
import { useT } from '../../i18n'
import { IcBack, IcEdit, IcNext } from '../../ui/icons'
import { addDays, Empty, ErrorBox, errorText, Field, Modal, Skeleton, todayIso, useAsync, useErrorMessage, useFmt, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function Diary() {
  const { t } = useT()
  const f = useFmt()
  const toast = useToast()
  const classes = useAsync(() => teacher.classes(), [])
  const [classId, setClassId] = useState<number | null>(null)
  const [date, setDate] = useState(todayIso())
  const uniq = (classes.data ?? []).filter((c, i, arr) => arr.findIndex((x) => x.class_id === c.class_id) === i)
  const current = classId ?? uniq[0]?.class_id ?? null
  const diary = useAsync(() => (current ? teacher.diary(current, date) : Promise.resolve([] as DiaryEntryDto[])), [current, date])
  const [editing, setEditing] = useState<DiaryEntryDto | null>(null)

  return (
    <>
      <TopBar title={t('nav_diary')} sub={t('diary_sub')}>
        <button className="btn ghost icon" onClick={() => setDate(addDays(date, -1))}><IcBack /></button>
        <input className="input" type="date" style={{ width: 170 }} value={date} onChange={(e) => e.target.value && setDate(e.target.value)} />
        <button className="btn ghost icon" onClick={() => setDate(addDays(date, 1))}><IcNext /></button>
        {date !== todayIso() && <button className="btn sm soft" onClick={() => setDate(todayIso())}>{t('today')}</button>}
      </TopBar>
      <div className="tabs mb16">
        {uniq.map((c) => <button key={c.class_id} className={'tab' + (c.class_id === current ? ' active' : '')} onClick={() => setClassId(c.class_id)}>{c.class_name}</button>)}
      </div>
      <div className="section-title" style={{ marginTop: 0 }}>{f.dateLong(date)}</div>
      <ErrorBox error={diary.error} onRetry={diary.reload} />
      {diary.loading && !diary.data && <Skeleton rows={3} h={90} />}
      {diary.data?.length === 0 && <Empty icon="📅" title={t('no_lessons_day')} body={t('no_lessons_day_body')} />}
      <div className="col" style={{ gap: 12, maxWidth: 860 }}>
        {diary.data?.map((l) => (
          <div key={l.lesson_id} className="card">
            <div className="row" style={{ alignItems: 'flex-start' }}>
              <span className="chip brand" style={{ height: 34, fontSize: 13 }}>{l.start_time.slice(0, 5)}</span>
              <div className="grow">
                <div className="bold" style={{ fontSize: 15 }}>{l.subject}</div>
                <div className="tiny faint">{l.duration_minutes} {t('min')}{l.room ? ` · ${l.room}` : ''}{l.teacher_name ? ` · ${l.teacher_name}` : ''}</div>
              </div>
              <button className="btn sm ghost" onClick={() => setEditing(l)}><IcEdit /> {t('edit')}</button>
            </div>
            <div className="grid c2 mt12" style={{ gap: 12 }}>
              <div><div className="tiny bold faint" style={{ textTransform: 'uppercase', letterSpacing: '.06em' }}>{t('homework')}</div><div className="small mt8" style={{ whiteSpace: 'pre-wrap' }}>{l.homework || <span className="faint">—</span>}</div></div>
              <div><div className="tiny bold faint" style={{ textTransform: 'uppercase', letterSpacing: '.06em' }}>{t('teacher_comment')}</div><div className="small mt8" style={{ whiteSpace: 'pre-wrap' }}>{l.teacher_comment || <span className="faint">—</span>}</div></div>
            </div>
          </div>
        ))}
      </div>
      {editing && <DiaryEdit entry={editing} date={date} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); diary.reload(); toast(t('saved')) }} />}
    </>
  )
}

function DiaryEdit({ entry, date, onClose, onSaved }: { entry: DiaryEntryDto; date: string; onClose: () => void; onSaved: () => void }) {
  const { t } = useT()
  const msg = useErrorMessage()
  const [homework, setHomework] = useState(entry.homework ?? '')
  const [comment, setComment] = useState(entry.teacher_comment ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  async function save() {
    setBusy(true); setError(null)
    try { await teacher.updateDiary(entry.lesson_id, date, { homework: homework.trim() || null, teacher_comment: comment.trim() || null }); onSaved() } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }
  return (
    <Modal title={entry.subject} lead={`${entry.start_time.slice(0, 5)} · ${date}`} onClose={onClose} actions={<>
      <button className="btn ghost" onClick={onClose}>{t('cancel')}</button>
      <button className="btn primary" disabled={busy} onClick={save}>{t('save')}</button>
    </>}>
      <div className="col" style={{ gap: 12 }}>
        <Field label={t('homework')}><textarea className="textarea" value={homework} onChange={(e) => setHomework(e.target.value)} autoFocus /></Field>
        <Field label={t('teacher_comment')}><textarea className="textarea" style={{ minHeight: 70 }} value={comment} onChange={(e) => setComment(e.target.value)} /></Field>
        {error && <div className="error-box">{msg(error)}</div>}
      </div>
    </Modal>
  )
}
