import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { teacher } from '../../api/endpoints'
import type { BlockDto, QuestionType } from '../../api/types'
import { useT } from '../../i18n'
import { IcDown, IcEdit, IcPlus, IcSparkles, IcTrash, IcUp } from '../../ui/icons'
import { ErrorBox, errorText, Field, Modal, Skeleton, useErrorMessage, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'
import { Ill } from '../../ui/illustrations'
import { AiFlow } from './AiFlow'

// -------------------------------------------------------- editable block

export interface EditBlock {
  key: string
  kind: 'page' | QuestionType
  body: string
  points: number
  options: string[]      // single / order
  correctIndex: number   // single
  correctBool: boolean   // truefalse
  answers: string[]      // fill
  left: string[]         // match
  right: string[]        // match (right[i] pairs with left[i])
}

let seq = 0
const nk = () => `b${++seq}-${Date.now()}`

export function newBlock(kind: EditBlock['kind']): EditBlock {
  return { key: nk(), kind, body: '', points: kind === 'page' ? 0 : 1, options: kind === 'single' ? ['', '', '', ''] : kind === 'order' ? ['', '', ''] : [], correctIndex: 0, correctBool: true, answers: [''], left: ['', ''], right: ['', ''] }
}

export function fromDto(b: BlockDto): EditBlock {
  const e = newBlock(b.block_type === 'page' ? 'page' : (b.question_type ?? 'single'))
  e.body = b.body ?? ''
  e.points = b.points ?? (e.kind === 'page' ? 0 : 1)
  const c = (b.correct ?? {}) as Record<string, unknown>
  const o = b.options
  switch (e.kind) {
    case 'single': e.options = Array.isArray(o) ? o.map(String) : []; e.correctIndex = Number(c.index ?? 0); break
    case 'truefalse': e.correctBool = c.value !== false; break
    case 'fill': e.answers = Array.isArray(c.answers) && c.answers.length ? (c.answers as unknown[]).map(String) : ['']; break
    case 'match': {
      const oo = (o ?? {}) as { left?: unknown[]; right?: unknown[] }
      const left = (oo.left ?? []).map(String), right = (oo.right ?? []).map(String)
      const pairs = (Array.isArray(c.pairs) ? c.pairs : []) as [number, number][]
      // Store as aligned rows: left[i] <-> right[pair]
      const alignedRight = left.map((_, i) => { const p = pairs.find((x) => Number(x[0]) === i); return p ? right[Number(p[1])] ?? '' : right[i] ?? '' })
      e.left = left.length ? left : ['', '']; e.right = left.length ? alignedRight : ['', '']
      break
    }
    case 'order': {
      const opts = Array.isArray(o) ? o.map(String) : []
      const order = (Array.isArray(c.order) ? c.order : opts.map((_, i) => i)) as number[]
      e.options = order.map((i) => opts[Number(i)] ?? '').filter((_, i) => i < opts.length)
      if (e.options.length < opts.length) e.options = opts
      break
    }
  }
  return e
}

export function toDto(e: EditBlock, position: number): BlockDto {
  if (e.kind === 'page') return { block_type: 'page', body: e.body.trim(), points: 0, position }
  const base = { block_type: 'question' as const, body: e.body.trim(), question_type: e.kind, points: e.points, position }
  switch (e.kind) {
    case 'single': return { ...base, options: e.options.map((s) => s.trim()), correct: { index: e.correctIndex } }
    case 'truefalse': return { ...base, options: null, correct: { value: e.correctBool } }
    case 'fill': return { ...base, options: null, correct: { answers: e.answers.map((s) => s.trim()).filter(Boolean) } }
    case 'match': {
      const left = e.left.map((s) => s.trim()), right = e.right.map((s) => s.trim())
      // Shuffle-free: right column is stored in a rotated order so the pupil has to think.
      const n = left.length
      const rot = left.map((_, i) => (i + 1) % n)
      const rightShown = rot.map((j) => right[j])
      const pairs = left.map((_, i) => [i, rot.indexOf(i)])
      return { ...base, options: { left, right: rightShown }, correct: { pairs } }
    }
    case 'order': {
      const items = e.options.map((s) => s.trim())
      // Present shuffled (deterministic rotation), correct = indices in true order.
      const n = items.length
      const shown = items.map((_, i) => items[(i * 2 + 1) % n])
      const order = items.map((it) => shown.indexOf(it))
      const distinct = new Set(shown).size === n
      return distinct ? { ...base, options: shown, correct: { order } } : { ...base, options: items, correct: { order: items.map((_, i) => i) } }
    }
  }
}

export function isValid(e: EditBlock): boolean {
  if (!e.body.trim()) return false
  switch (e.kind) {
    case 'page': return true
    case 'single': return e.options.filter((s) => s.trim()).length >= 2 && e.options.every((s) => s.trim()) && e.correctIndex < e.options.length
    case 'truefalse': return true
    case 'fill': return e.answers.some((s) => s.trim())
    case 'match': return e.left.length >= 2 && e.left.every((s) => s.trim()) && e.right.every((s) => s.trim()) && e.left.length === e.right.length
    case 'order': return e.options.length >= 2 && e.options.every((s) => s.trim())
  }
}

// ---------------------------------------------------------------- editor

export function MaterialEditor() {
  const { t } = useT()
  const nav = useNavigate()
  const toast = useToast()
  const msg = useErrorMessage()
  const id = useParams().id ? Number(useParams().id) : null
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [blocks, setBlocks] = useState<EditBlock[]>([])
  const [loading, setLoading] = useState(!!id)
  const [error, setError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [editing, setEditing] = useState<{ index: number; block: EditBlock } | null>(null)
  const [ai, setAi] = useState(false)

  useEffect(() => {
    if (!id) return
    setLoading(true)
    teacher.material(id).then((m) => { setTitle(m.title); setDescription(m.description ?? ''); setBlocks([...m.blocks].sort((a, b) => (a.position ?? 0) - (b.position ?? 0)).map(fromDto)) }, (e) => setError(errorText(e))).finally(() => setLoading(false))
  }, [id])

  const allValid = blocks.every(isValid)
  const canSave = title.trim() && blocks.length > 0 && allValid && !saving
  const questions = blocks.filter((b) => b.kind !== 'page')
  const points = questions.reduce((s, b) => s + b.points, 0)

  async function save() {
    if (!canSave) return
    setSaving(true); setError(null)
    try {
      const dto = blocks.map(toDto)
      if (id) await teacher.updateMaterial(id, { title: title.trim(), description: description.trim() || null, blocks: dto })
      else await teacher.createMaterial({ title: title.trim(), description: description.trim() || null, blocks: dto })
      toast(t('saved')); nav('/materials')
    } catch (e) { setError(errorText(e)) } finally { setSaving(false) }
  }
  function move(i: number, d: number) {
    const j = i + d
    if (j < 0 || j >= blocks.length) return
    const n = [...blocks]; [n[i], n[j]] = [n[j], n[i]]; setBlocks(n)
  }

  if (ai) return <AiFlow onCancel={() => setAi(false)} onDone={(r) => { setAi(false); if (!title.trim() && r.title) setTitle(r.title); if (!description.trim() && r.description) setDescription(r.description); setBlocks((b) => [...b, ...r.blocks.map(fromDto)]); toast(t('ai_added', r.blocks.length) + (r.dropped_count ? ` · ${t('ai_dropped', r.dropped_count)}` : '')) }} />

  return (
    <>
      <TopBar title={id ? t('edit_material') : t('new_material')} sub={t('editor_sub', questions.length, points)} back={() => nav('/materials')}>
        <button className="btn primary" disabled={!canSave} onClick={save}>{saving ? t('saving') : t('save')}</button>
      </TopBar>
      {loading && <Skeleton rows={4} h={90} />}
      {!loading && (
        <div className="grid" style={{ gridTemplateColumns: '1fr 320px', alignItems: 'start' }}>
          <div className="col" style={{ gap: 12 }}>
            <div className="card">
              <div className="col" style={{ gap: 12 }}>
                <Field label={t('material_title')}><input className="input" style={{ fontSize: 16, fontWeight: 700, height: 48 }} value={title} onChange={(e) => setTitle(e.target.value)} autoFocus placeholder={t('material_title_ph')} /></Field>
                <Field label={t('description_optional')}><textarea className="textarea" style={{ minHeight: 60 }} value={description} onChange={(e) => setDescription(e.target.value)} /></Field>
              </div>
            </div>
            {blocks.length === 0 && <div className="card empty"><div className="ill"><Ill name="clipboard" size={150} /></div><h3>{t('no_blocks')}</h3><p className="small">{t('no_blocks_body')}</p></div>}
            {blocks.map((b, i) => (
              <div key={b.key} className="block" style={{ borderColor: isValid(b) ? 'var(--border)' : 'var(--rose)' }}>
                <div className="row">
                  <span className="kind grow">{i + 1}. {b.kind === 'page' ? t('block_page') : t('qt_' + b.kind)}{b.kind !== 'page' && ` · ${b.points} ${t('points')}`}{!isValid(b) && <span className="chip rose" style={{ marginLeft: 8, height: 20 }}>{t('incomplete')}</span>}</span>
                  <button className="btn ghost icon sm" onClick={() => move(i, -1)} disabled={i === 0}><IcUp /></button>
                  <button className="btn ghost icon sm" onClick={() => move(i, 1)} disabled={i === blocks.length - 1}><IcDown /></button>
                  <button className="btn ghost icon sm" onClick={() => setEditing({ index: i, block: { ...b } })}><IcEdit /></button>
                  <button className="btn ghost icon sm" onClick={() => setBlocks(blocks.filter((_, j) => j !== i))}><IcTrash /></button>
                </div>
                <div className="body">{b.body || <span className="faint">{t('empty')}</span>}</div>
                <BlockPreview b={b} />
              </div>
            ))}
            {error && <ErrorBox error={error} />}
          </div>
          <div className="col" style={{ gap: 12, position: 'sticky', top: 20 }}>
            <button className="card clickable" style={{ textAlign: 'left', background: 'linear-gradient(135deg, var(--brand), var(--brand-deep))', color: '#fff', border: 0 }} onClick={() => setAi(true)}>
              <div className="row"><IcSparkles style={{ width: 22, height: 22 }} /><div className="bold" style={{ fontSize: 15 }}>{t('ai_draft')}</div></div>
              <div className="small mt8" style={{ opacity: .85 }}>{t('ai_draft_hint')}</div>
            </button>
            <div className="card">
              <div className="card-title">{t('add_block')}</div>
              <div className="col" style={{ gap: 6 }}>
                {(['page', 'single', 'truefalse', 'fill', 'match', 'order'] as const).map((k) => (
                  <button key={k} className="btn ghost" style={{ justifyContent: 'flex-start' }} onClick={() => setEditing({ index: -1, block: newBlock(k) })}><IcPlus /> {k === 'page' ? t('block_page') : t('qt_' + k)}</button>
                ))}
              </div>
            </div>
            <div className="card tight small muted">{t('editor_tip')}</div>
          </div>
        </div>
      )}
      {editing && (
        <BlockEditor block={editing.block} onClose={() => setEditing(null)} onSave={(b) => { setBlocks(editing.index < 0 ? [...blocks, b] : blocks.map((x, i) => (i === editing.index ? b : x))); setEditing(null) }} />
      )}
      {error && !loading && !blocks.length && <div className="error-box">{msg(error)}</div>}
    </>
  )
}

function BlockPreview({ b }: { b: EditBlock }) {
  const { t } = useT()
  if (b.kind === 'single') return <div>{b.options.map((o, i) => <div key={i} className={'opt-line' + (i === b.correctIndex ? ' correct' : '')}><span className="k">{String.fromCharCode(65 + i)}</span><span>{o}</span></div>)}</div>
  if (b.kind === 'truefalse') return <div className="opt-line correct"><span className="k">✓</span>{b.correctBool ? t('true') : t('false')}</div>
  if (b.kind === 'fill') return <div className="opt-line correct"><span className="k">✓</span>{b.answers.filter(Boolean).join(' / ')}</div>
  if (b.kind === 'match') return <div>{b.left.map((l, i) => <div key={i} className="opt-line"><span className="k">{i + 1}</span><span>{l}</span><span className="faint">→</span><span>{b.right[i]}</span></div>)}</div>
  if (b.kind === 'order') return <div>{b.options.map((o, i) => <div key={i} className="opt-line correct"><span className="k">{i + 1}</span><span>{o}</span></div>)}</div>
  return null
}

function BlockEditor({ block, onClose, onSave }: { block: EditBlock; onClose: () => void; onSave: (b: EditBlock) => void }) {
  const { t } = useT()
  const [b, set] = useState<EditBlock>(block)
  const up = (patch: Partial<EditBlock>) => set({ ...b, ...patch })
  const list = (key: 'options' | 'answers' | 'left' | 'right', i: number, v: string) => { const n = [...b[key]]; n[i] = v; up({ [key]: n } as Partial<EditBlock>) }
  const add = (key: 'options' | 'answers') => up({ [key]: [...b[key], ''] } as Partial<EditBlock>)
  const rm = (key: 'options' | 'answers', i: number) => up({ [key]: b[key].filter((_, j) => j !== i), correctIndex: key === 'options' && b.correctIndex >= i && b.correctIndex > 0 ? b.correctIndex - 1 : b.correctIndex } as Partial<EditBlock>)

  return (
    <Modal title={b.kind === 'page' ? t('block_page') : t('qt_' + b.kind)} onClose={onClose} wide actions={<>
      <button className="btn ghost" onClick={onClose}>{t('cancel')}</button>
      <button className="btn primary" disabled={!isValid(b)} onClick={() => onSave(b)}>{t('done')}</button>
    </>}>
      <div className="col" style={{ gap: 14 }}>
        <Field label={b.kind === 'page' ? t('page_text') : t('question_text')}><textarea className="textarea" style={{ minHeight: b.kind === 'page' ? 200 : 80 }} value={b.body} onChange={(e) => up({ body: e.target.value })} autoFocus /></Field>
        {b.kind === 'single' && (
          <Field label={t('options_pick_correct')}>
            {b.options.map((o, i) => (
              <div key={i} className="row">
                <button className={'btn icon sm ' + (b.correctIndex === i ? 'primary' : 'ghost')} onClick={() => up({ correctIndex: i })}>{String.fromCharCode(65 + i)}</button>
                <input className="input" value={o} onChange={(e) => list('options', i, e.target.value)} />
                <button className="btn ghost icon sm" disabled={b.options.length <= 2} onClick={() => rm('options', i)}><IcTrash /></button>
              </div>
            ))}
            <button className="btn sm soft" style={{ alignSelf: 'flex-start' }} disabled={b.options.length >= 6} onClick={() => add('options')}><IcPlus /> {t('add_option')}</button>
          </Field>
        )}
        {b.kind === 'truefalse' && (
          <Field label={t('correct_answer')}>
            <div className="seg"><button className={b.correctBool ? 'active' : ''} onClick={() => up({ correctBool: true })}>{t('true')}</button><button className={!b.correctBool ? 'active' : ''} onClick={() => up({ correctBool: false })}>{t('false')}</button></div>
          </Field>
        )}
        {b.kind === 'fill' && (
          <Field label={t('accepted_answers')}>
            {b.answers.map((a, i) => (
              <div key={i} className="row"><input className="input" value={a} onChange={(e) => list('answers', i, e.target.value)} /><button className="btn ghost icon sm" disabled={b.answers.length <= 1} onClick={() => rm('answers', i)}><IcTrash /></button></div>
            ))}
            <button className="btn sm soft" style={{ alignSelf: 'flex-start' }} onClick={() => add('answers')}><IcPlus /> {t('add_variant')}</button>
          </Field>
        )}
        {b.kind === 'match' && (
          <Field label={t('pairs')}>
            {b.left.map((l, i) => (
              <div key={i} className="row">
                <input className="input" value={l} onChange={(e) => list('left', i, e.target.value)} placeholder={t('left')} />
                <span className="faint">→</span>
                <input className="input" value={b.right[i] ?? ''} onChange={(e) => list('right', i, e.target.value)} placeholder={t('right')} />
                <button className="btn ghost icon sm" disabled={b.left.length <= 2} onClick={() => up({ left: b.left.filter((_, j) => j !== i), right: b.right.filter((_, j) => j !== i) })}><IcTrash /></button>
              </div>
            ))}
            <button className="btn sm soft" style={{ alignSelf: 'flex-start' }} disabled={b.left.length >= 6} onClick={() => up({ left: [...b.left, ''], right: [...b.right, ''] })}><IcPlus /> {t('add_pair')}</button>
          </Field>
        )}
        {b.kind === 'order' && (
          <Field label={t('items_in_order')}>
            {b.options.map((o, i) => (
              <div key={i} className="row"><span className="k chip">{i + 1}</span><input className="input" value={o} onChange={(e) => list('options', i, e.target.value)} /><button className="btn ghost icon sm" disabled={b.options.length <= 2} onClick={() => rm('options', i)}><IcTrash /></button></div>
            ))}
            <button className="btn sm soft" style={{ alignSelf: 'flex-start' }} disabled={b.options.length >= 8} onClick={() => add('options')}><IcPlus /> {t('add_item')}</button>
          </Field>
        )}
        {b.kind !== 'page' && (
          <Field label={t('points')}><input className="input" type="number" min={0} max={100} style={{ width: 120 }} value={b.points} onChange={(e) => up({ points: Math.max(0, Math.min(100, Number(e.target.value) || 0)) })} /></Field>
        )}
      </div>
    </Modal>
  )
}
