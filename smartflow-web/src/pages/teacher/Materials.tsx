import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { teacher } from '../../api/endpoints'
import type { ClassAssignmentDto, MaterialSummaryDto } from '../../api/types'
import { useT } from '../../i18n'
import { IcEdit, IcPlus, IcSend, IcTrash } from '../../ui/icons'
import { Confirm, Empty, ErrorBox, errorText, Field, Modal, Skeleton, useAsync, useErrorMessage, useFmt, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function Materials() {
  const { t } = useT()
  const f = useFmt()
  const nav = useNavigate()
  const toast = useToast()
  const materials = useAsync(() => teacher.materials(), [])
  const assignments = useAsync(() => teacher.assignments(), [])
  const classes = useAsync(() => teacher.classes(), [])
  const [tab, setTab] = useState<'materials' | 'assignments'>('materials')
  const [assigning, setAssigning] = useState<MaterialSummaryDto | null>(null)
  const [deleting, setDeleting] = useState<MaterialSummaryDto | null>(null)

  async function remove() {
    if (!deleting) return
    try { await teacher.deleteMaterial(deleting.id); toast(t('deleted')); materials.reload() } catch (e) { toast(errorText(e)) }
    setDeleting(null)
  }
  const sortedA = [...(assignments.data ?? [])].sort((a, b) => (b.published_at ?? '').localeCompare(a.published_at ?? ''))

  return (
    <>
      <TopBar title={t('nav_materials')} sub={t('materials_sub')}>
        <button className="btn primary" onClick={() => nav('/materials/new')}><IcPlus /> {t('new_material')}</button>
      </TopBar>
      <div className="tabs mb16">
        <button className={'tab' + (tab === 'materials' ? ' active' : '')} onClick={() => setTab('materials')}>📚 {t('my_materials')} {materials.data ? `· ${materials.data.length}` : ''}</button>
        <button className={'tab' + (tab === 'assignments' ? ' active' : '')} onClick={() => setTab('assignments')}>📝 {t('handed_out')} {assignments.data ? `· ${assignments.data.length}` : ''}</button>
      </div>
      {tab === 'materials' && (
        <>
          <ErrorBox error={materials.error} onRetry={materials.reload} />
          {materials.loading && !materials.data && <Skeleton rows={4} h={96} />}
          {materials.data?.length === 0 && <Empty icon="✨" title={t('no_materials')} body={t('no_materials_body')} />}
          <div className="grid c2">
            {materials.data?.map((m) => (
              <div key={m.id} className="card">
                <div className="row" style={{ alignItems: 'flex-start' }}>
                  <div className="grow">
                    <div className="bold" style={{ fontSize: 15 }}>{m.title}</div>
                    {m.description && <div className="small muted mt8" style={{ display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{m.description}</div>}
                  </div>
                </div>
                <div className="row wrap mt12" style={{ gap: 6 }}>
                  <span className="chip brand">{m.subject}</span>
                  <span className="chip">{t('questions_n', m.question_count)}</span>
                  {m.page_count > 0 && <span className="chip">{t('pages_n', m.page_count)}</span>}
                  <span className="chip">{m.max_score} {t('points')}</span>
                  {m.assigned_class_count > 0 && <span className="chip mint">{t('assigned_n', m.assigned_class_count)}</span>}
                  <span className="tiny faint" style={{ marginLeft: 'auto' }}>{f.dateTime(m.updated_at)}</span>
                </div>
                <div className="row mt12" style={{ gap: 6 }}>
                  <button className="btn sm primary" onClick={() => setAssigning(m)}><IcSend /> {t('hand_out')}</button>
                  <Link to={`/materials/${m.id}`} className="btn sm ghost"><IcEdit /> {t('edit')}</Link>
                  <button className="btn sm ghost icon" onClick={() => setDeleting(m)}><IcTrash /></button>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
      {tab === 'assignments' && (
        <>
          <ErrorBox error={assignments.error} onRetry={assignments.reload} />
          {assignments.loading && !assignments.data && <Skeleton rows={4} h={80} />}
          {assignments.data?.length === 0 && <Empty icon="📝" title={t('no_assignments')} />}
          <div className="card" style={{ padding: 0 }}>
            {sortedA.length > 0 && (
              <table className="table">
                <thead><tr><th>{t('material')}</th><th>{t('class')}</th><th>{t('mode')}</th><th>{t('due')}</th><th>{t('submitted')}</th><th></th></tr></thead>
                <tbody>
                  {sortedA.map((a) => (
                    <tr key={a.id} className="clickable" onClick={() => nav(`/results/${a.id}`)}>
                      <td className="bold">{a.material_title}</td>
                      <td><span className="chip">{a.class_name}</span></td>
                      <td><span className={'chip ' + (a.mode === 'control' ? 'coral' : 'sky')}>{a.mode === 'control' ? t('mode_control') : t('mode_practice')}</span></td>
                      <td className="small muted">{a.due_at ? f.dateTime(a.due_at) : '—'}</td>
                      <td>
                        <div className="row"><div className="bar" style={{ width: 90 }}><i style={{ width: `${a.student_count ? (a.submitted_count / a.student_count) * 100 : 0}%` }} /></div><span className="small bold">{a.submitted_count}/{a.student_count}</span></div>
                      </td>
                      <td style={{ textAlign: 'right' }}>{a.grades_transferred_at ? <span className="chip mint">{t('in_journal')}</span> : <span className="btn sm soft">{t('results')}</span>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}
      {assigning && <AssignModal material={assigning} classes={classes.data ?? []} onClose={() => setAssigning(null)} onDone={() => { setAssigning(null); assignments.reload(); materials.reload(); setTab('assignments') }} />}
      {deleting && <Confirm danger title={t('delete_material_q', deleting.title)} onNo={() => setDeleting(null)} onYes={remove} />}
    </>
  )
}

function AssignModal({ material, classes, onClose, onDone }: { material: MaterialSummaryDto; classes: ClassAssignmentDto[]; onClose: () => void; onDone: () => void }) {
  const { t } = useT()
  const toast = useToast()
  const msg = useErrorMessage()
  const uniq = classes.filter((c, i, arr) => arr.findIndex((x) => x.class_id === c.class_id) === i)
  const [picked, setPicked] = useState<Set<number>>(new Set(uniq.length === 1 ? [uniq[0].class_id] : []))
  const [mode, setMode] = useState<'practice' | 'control'>('practice')
  const [due, setDue] = useState('')
  const [attempts, setAttempts] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function go() {
    if (!picked.size || busy) return
    setBusy(true); setError(null)
    try {
      await teacher.assign({ material_id: material.id, class_ids: [...picked], mode, due_at: due ? new Date(due).toISOString() : null, max_attempts: attempts ? Number(attempts) : null })
      toast(t('handed_out_ok')); onDone()
    } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }

  return (
    <Modal title={t('hand_out')} lead={material.title} onClose={onClose} actions={<>
      <button className="btn ghost" onClick={onClose}>{t('cancel')}</button>
      <button className="btn primary" disabled={!picked.size || busy} onClick={go}><IcSend /> {t('hand_out')}</button>
    </>}>
      <div className="col" style={{ gap: 14 }}>
        <Field label={t('classes')}>
          <div className="row wrap" style={{ gap: 6 }}>
            {uniq.map((c) => <button key={c.class_id} className={'tab' + (picked.has(c.class_id) ? ' active' : '')} onClick={() => { const n = new Set(picked); n.has(c.class_id) ? n.delete(c.class_id) : n.add(c.class_id); setPicked(n) }}>{c.class_name}</button>)}
          </div>
        </Field>
        <Field label={t('mode')}>
          <div className="seg">
            <button className={mode === 'practice' ? 'active' : ''} onClick={() => setMode('practice')}>{t('mode_practice')}</button>
            <button className={mode === 'control' ? 'active' : ''} onClick={() => setMode('control')}>{t('mode_control')}</button>
          </div>
          <span className="tiny faint">{mode === 'practice' ? t('mode_practice_hint') : t('mode_control_hint')}</span>
        </Field>
        <div className="grid c2" style={{ gap: 12 }}>
          <Field label={t('due_optional')}><input className="input" type="datetime-local" value={due} onChange={(e) => setDue(e.target.value)} /></Field>
          <Field label={t('attempts_optional')}><input className="input" type="number" min={1} max={10} value={attempts} onChange={(e) => setAttempts(e.target.value)} placeholder="∞" /></Field>
        </div>
        {error && <div className="error-box">{msg(error)}</div>}
      </div>
    </Modal>
  )
}
