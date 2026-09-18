import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { family } from '../../api/endpoints'
import type { AttemptResultDto, StudentAssignmentDetailDto, StudentBlockDto } from '../../api/types'
import { useSession } from '../../App'
import { useT } from '../../i18n'
import { errorText, ErrorBox, gradeClass, Skeleton, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'
import { Ill } from '../../ui/illustrations'
import { IcCheck, IcNext } from '../../ui/icons'

/** A pupil sits an assignment: start an attempt, answer question by question, submit. */
export function TakeTest() {
  const { t } = useT()
  const toast = useToast()
  const nav = useNavigate()
  const session = useSession()
  const studentId = session?.id ?? 0
  const assignmentId = Number(useParams().aid)

  const [detail, setDetail] = useState<StudentAssignmentDetailDto | null>(null)
  const [answers, setAnswers] = useState<Record<string, unknown>>({})
  const [error, setError] = useState<string | null>(null)
  const [i, setI] = useState(0)
  const [result, setResult] = useState<AttemptResultDto | null>(null)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    let alive = true
    family.startAttempt(assignmentId, studentId)
      .then((d) => { if (alive) { setDetail(d); setAnswers({ ...(d.saved_answers || {}) }) } })
      .catch((e) => alive && setError(errorText(e)))
    return () => { alive = false }
  }, [assignmentId, studentId])

  const questions = useMemo(() => (detail?.blocks ?? []).filter((b) => b.block_type === 'question'), [detail])
  const pages = useMemo(() => (detail?.blocks ?? []), [detail])

  if (error) return <><TopBar title={t('nav_home')} back={() => nav(-1)} /><ErrorBox error={error} /></>
  if (!detail) return <><TopBar title={t('asg_loading')} /><Skeleton rows={4} h={70} /></>

  if (result) {
    return (
      <>
        <TopBar title={detail.title} />
        <div className="card" style={{ textAlign: 'center', padding: 40, maxWidth: 520, margin: '0 auto' }}>
          <Ill name="trophy" size={130} />
          <h2 className="mt12">{t('asg_submitted')}</h2>
          {result.score_visible && result.percent != null
            ? <div className={'grade ' + gradeClass(result.percent / 10)} style={{ fontSize: 26, margin: '14px auto', width: 'auto', padding: '0 18px' }}>{result.score}/{result.max_score} · {result.percent}%</div>
            : <p className="muted mt12">{t('asg_result_hidden')}</p>}
          <button className="btn primary mt16" onClick={() => nav(-1)}>{t('asg_back')}</button>
        </div>
      </>
    )
  }

  const answered = questions.filter((q) => answers[String(q.id)] != null && answers[String(q.id)] !== '').length

  async function setAnswer(block: StudentBlockDto, value: unknown) {
    setAnswers((a) => ({ ...a, [String(block.id)]: value }))
    if (!detail?.attempt_id) return
    try { await family.answer(detail.attempt_id, block.id, value) } catch { /* saved locally; retried on submit path */ }
  }

  async function submit() {
    if (!detail?.attempt_id || busy) return
    setBusy(true)
    try {
      // flush any answers the server might have missed
      for (const q of questions) {
        const v = answers[String(q.id)]
        if (v != null && v !== '') { try { await family.answer(detail.attempt_id, q.id, v) } catch {} }
      }
      setResult(await family.submit(detail.attempt_id))
    } catch (e) { toast(errorText(e)) } finally { setBusy(false) }
  }

  const block = pages[i]
  const qNo = block.block_type === 'question' ? questions.findIndex((q) => q.id === block.id) + 1 : 0

  return (
    <>
      <TopBar title={detail.title} sub={`${detail.subject}${detail.teacher_name ? ' · ' + detail.teacher_name : ''}`} back={() => nav(-1)} />
      <div className="card mb16">
        <div className="row"><div className="small muted grow">{t('asg_progress', answered, questions.length)}</div><div className="small faint">{i + 1} / {pages.length}</div></div>
        <div className="bar mt8"><span style={{ width: `${((i + 1) / pages.length) * 100}%` }} /></div>
      </div>

      <div className="card" style={{ maxWidth: 720, margin: '0 auto' }}>
        {block.block_type === 'page'
          ? <div className="prose"><div style={{ whiteSpace: 'pre-wrap', lineHeight: 1.6 }}>{block.body}</div></div>
          : <Question block={block} no={qNo} value={answers[String(block.id)]} onChange={(v) => setAnswer(block, v)} />}
        <div className="row mt24">
          <button className="btn ghost" disabled={i === 0} onClick={() => setI(i - 1)}>{t('asg_prev')}</button>
          <div className="grow" />
          {i < pages.length - 1
            ? <button className="btn primary" onClick={() => setI(i + 1)}>{t('asg_next')} <IcNext /></button>
            : <button className="btn gold" disabled={busy} onClick={submit}><IcCheck /> {busy ? t('asg_submitting') : t('asg_submit')}</button>}
        </div>
      </div>
    </>
  )
}

function Question({ block, no, value, onChange }: { block: StudentBlockDto; no: number; value: unknown; onChange: (v: unknown) => void }) {
  const { t } = useT()
  const opts = Array.isArray(block.options) ? (block.options as string[]) : []
  return (
    <div>
      <div className="row mb12" style={{ alignItems: 'flex-start' }}>
        <span className="q-no">{no}</span>
        <div className="grow" style={{ fontSize: 16, fontWeight: 700, lineHeight: 1.5 }}>{block.body}</div>
      </div>
      {block.question_type === 'single' && (
        <div className="col" style={{ gap: 8 }}>
          {opts.map((o) => (
            <button key={o} type="button" className={'opt' + (value === o ? ' on' : '')} onClick={() => onChange(o)}>
              <span className="opt-dot">{value === o && <IcCheck />}</span> {o}
            </button>
          ))}
        </div>
      )}
      {block.question_type === 'truefalse' && (
        <div className="row" style={{ gap: 8 }}>
          {['true', 'false'].map((o) => (
            <button key={o} type="button" className={'opt grow' + (value === o ? ' on' : '')} onClick={() => onChange(o)}>
              {o === 'true' ? t('tf_true') : t('tf_false')}
            </button>
          ))}
        </div>
      )}
      {(block.question_type === 'fill' || block.question_type === 'match' || block.question_type === 'order') && (
        <textarea className="input" style={{ minHeight: 80, resize: 'vertical' }} value={(value as string) ?? ''}
          placeholder={t('asg_your_answer')} onChange={(e) => onChange(e.target.value)} />
      )}
    </div>
  )
}
