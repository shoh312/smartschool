import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { teacher } from '../../api/endpoints'
import type { GradeDto } from '../../api/types'
import { useT } from '../../i18n'
import { IcTrash } from '../../ui/icons'
import { JournalGrid, type CellInfo } from '../../ui/JournalGrid'
import { Avatar, ErrorBox, errorText, Field, fmtAvg, gradeClass, Modal, Skeleton, useAsync, useErrorMessage, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function TeacherJournal() {
  const { t } = useT()
  const nav = useNavigate()
  const toast = useToast()
  const p = useParams()
  const classId = Number(p.classId)
  const subject = decodeURIComponent(p.subject ?? '')
  const roster = useAsync(() => teacher.roster(classId), [classId])
  const grades = useAsync(() => teacher.grades(classId, subject || null), [classId, subject])
  const absences = useAsync(() => teacher.absences(classId, subject || null).catch(() => []), [classId, subject])
  const classes = useAsync(() => teacher.classes(), [])
  const [cell, setCell] = useState<CellInfo | null>(null)
  const cls = classes.data?.find((c) => c.class_id === classId && (c.subject ?? '') === subject)
  const pupils = [...(roster.data ?? [])].sort((a, b) => a.last_name.localeCompare(b.last_name))
  const g = grades.data ?? []
  const avg = g.length ? g.reduce((s, x) => s + x.value, 0) / g.length : null

  return (
    <>
      <TopBar title={cls?.class_name ?? '…'} sub={subject} back={() => nav('/')}>
        <div className="card tight row" style={{ gap: 14 }}>
          <span className={'grade ' + gradeClass(avg)} style={{ minWidth: 44, height: 44, fontSize: 16 }}>{fmtAvg(avg)}</span>
          <div>
            <div className="small bold">{t('average')}</div>
            <div className="tiny faint">{t('marks_n', g.length)} · {t('absences_n', (absences.data ?? []).length)}</div>
          </div>
        </div>
      </TopBar>
      <p className="small muted mb12">{t('journal_teacher_hint')}</p>
      <ErrorBox error={roster.error ?? grades.error} onRetry={() => { roster.reload(); grades.reload() }} />
      {(roster.loading || grades.loading) && !(roster.data && grades.data) && <Skeleton rows={6} h={48} />}
      {roster.data && grades.data && <JournalGrid pupils={pupils} grades={g} absences={absences.data ?? []} editable onCell={setCell} />}
      {cell && (
        <GradeModal cell={cell} classId={classId} subject={subject} onClose={() => setCell(null)} onSaved={() => { setCell(null); grades.reload(); toast(t('grade_saved')) }} allGrades={g} />
      )}
    </>
  )
}

function GradeModal({ cell, classId, subject, onClose, onSaved, allGrades }: { cell: CellInfo; classId: number; subject: string; onClose: () => void; onSaved: () => void; allGrades: GradeDto[] }) {
  const { t } = useT()
  const msg = useErrorMessage()
  const existing = cell.grades[0]
  const [value, setValue] = useState<number | null>(existing?.value ?? null)
  const [comment, setComment] = useState(existing?.comment ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const history = allGrades.filter((x) => x.student_id === cell.student.id).sort((a, b) => b.grade_date.localeCompare(a.grade_date)).slice(0, 10)

  async function save() {
    if (value == null || busy) return
    setBusy(true); setError(null)
    try {
      if (existing) await teacher.updateGrade(existing.id, { value, comment: comment.trim() || null })
      else await teacher.createGrade({ student_id: cell.student.id, class_id: classId, subject, value, comment: comment.trim() || null })
      onSaved()
    } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }
  async function remove() {
    if (!existing || busy) return
    setBusy(true)
    try { await teacher.deleteGrade(existing.id); onSaved() } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }

  return (
    <Modal onClose={onClose} actions={<>
      {existing && <button className="btn danger" onClick={remove} disabled={busy} style={{ marginRight: 'auto' }}><IcTrash /> {t('delete')}</button>}
      <button className="btn ghost" onClick={onClose}>{t('cancel')}</button>
      <button className="btn primary" disabled={value == null || busy} onClick={save}>{busy ? t('saving') : t('save')}</button>
    </>}>
      <div className="row mb16">
        <Avatar first={cell.student.first_name} last={cell.student.last_name} id={cell.student.id} size="lg" />
        <div>
          <h2 style={{ marginBottom: 0 }}>{cell.student.last_name} {cell.student.first_name}</h2>
          <div className="muted small">{existing ? t('grade_today') : t('give_grade')}{cell.absent ? ` · ${t('absent_today')}` : ''}</div>
        </div>
      </div>
      <div className="tiny bold faint mb8" style={{ textTransform: 'uppercase', letterSpacing: '.06em' }}>{t('grade_value')}</div>
      <div className="grid" style={{ gridTemplateColumns: 'repeat(5, 1fr)', gap: 8 }}>
        {Array.from({ length: 10 }, (_, i) => i + 1).map((v) => {
          const on = value === v
          const cls = gradeClass(v)
          const color = cls === 'g-hi' ? 'var(--mint)' : cls === 'g-mid' ? 'var(--amber)' : 'var(--rose)'
          const soft = cls === 'g-hi' ? 'var(--mint-soft)' : cls === 'g-mid' ? 'var(--amber-soft)' : 'var(--rose-soft)'
          return <button key={v} onClick={() => setValue(v)} style={{ height: 54, borderRadius: 12, fontSize: 20, fontWeight: 800, background: on ? color : soft, color: on ? '#fff' : color, boxShadow: on ? `0 8px 18px -8px ${color}` : 'none', transition: 'all .12s' }}>{v}</button>
        })}
      </div>
      <div className="mt16"><Field label={t('comment_optional')}><textarea className="textarea" style={{ minHeight: 64 }} value={comment} onChange={(e) => setComment(e.target.value)} /></Field></div>
      {history.length > 0 && (
        <div className="mt16">
          <div className="tiny bold faint mb8" style={{ textTransform: 'uppercase', letterSpacing: '.06em' }}>{t('last_marks')}</div>
          <div className="row wrap" style={{ gap: 6 }}>
            {history.map((h) => <span key={h.id} className={'grade ' + gradeClass(h.value)} title={h.grade_date}>{h.value}</span>)}
          </div>
        </div>
      )}
      {error && <div className="error-box mt12">{msg(error)}</div>}
    </Modal>
  )
}
