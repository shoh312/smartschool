import { useEffect, useState } from 'react'
import { teacher } from '../../api/endpoints'
import type { AiGenerateResponse } from '../../api/types'
import { useT } from '../../i18n'
import { IcBack, IcSparkles } from '../../ui/icons'
import { errorText, Field, useErrorMessage } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

type Source = 'topic' | 'photo' | 'text'
const TYPES = ['single', 'truefalse', 'fill', 'match', 'order'] as const
const LANGS: Record<string, string> = { tg: 'tojik (kirill)', ru: 'русский', en: 'english' }

/** Pick a source → fill the form → watch it generate. Returns the draft. */
export function AiFlow({ onCancel, onDone }: { onCancel: () => void; onDone: (r: AiGenerateResponse) => void }) {
  const { t, lang } = useT()
  const msg = useErrorMessage()
  const [source, setSource] = useState<Source | null>(null)
  const [kind, setKind] = useState<'lesson' | 'test'>('lesson')
  const [topic, setTopic] = useState('')
  const [text, setText] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [count, setCount] = useState(6)
  const [types, setTypes] = useState<Set<string>>(new Set(['single', 'truefalse']))
  const [difficulty, setDifficulty] = useState('medium')
  const [language, setLanguage] = useState(LANGS[lang] ?? LANGS.ru)
  const [generating, setGenerating] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const ready = source === 'topic' ? topic.trim().length > 2 : source === 'photo' ? !!file : text.trim().length > 40

  async function go() {
    if (!ready || generating) return
    setGenerating(true); setError(null)
    const fd = new FormData()
    fd.set('kind', kind)
    if (topic.trim()) fd.set('topic', topic.trim())
    if (source === 'text') fd.set('source_text', text.trim())
    fd.set('question_count', String(count))
    fd.set('page_count', kind === 'test' ? '0' : '2')
    fd.set('question_types', [...types].join(','))
    fd.set('difficulty', difficulty)
    fd.set('language', language)
    if (source === 'photo' && file) fd.set('file', file)
    try { onDone(await teacher.aiGenerate(fd)) } catch (e) { setError(errorText(e)); setGenerating(false) }
  }

  if (generating) return <Generating />

  return (
    <>
      <TopBar title={t('ai_draft')} sub={source ? t('ai_src_' + source) : t('ai_how')} back={source ? () => setSource(null) : onCancel} />
      {!source && (
        <div className="grid c3" style={{ maxWidth: 900 }}>
          {(['topic', 'photo', 'text'] as Source[]).map((s, i) => (
            <button key={s} className="option-card" onClick={() => setSource(s)}>
              <div className="ic" style={{ background: ['var(--brand-soft)', 'var(--amber-soft)', 'var(--mint-soft)'][i] }}>{['💡', '📸', '📄'][i]}</div>
              <h4>{t('ai_src_' + s)}</h4>
              <div className="small muted">{t('ai_src_' + s + '_hint')}</div>
            </button>
          ))}
        </div>
      )}
      {source && (
        <div className="card" style={{ maxWidth: 720 }}>
          <div className="col" style={{ gap: 16 }}>
            {source === 'topic' && <Field label={t('topic')}><input className="input" value={topic} onChange={(e) => setTopic(e.target.value)} autoFocus placeholder={t('topic_ph')} /></Field>}
            {source === 'photo' && (
              <>
                <Field label={t('textbook_page')}>
                  <input className="input" type="file" accept="image/*,.pdf" style={{ paddingTop: 9 }} onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
                  {file && <span className="tiny faint">{file.name} · {Math.round(file.size / 1024)} KB</span>}
                </Field>
                <Field label={t('topic_optional')}><input className="input" value={topic} onChange={(e) => setTopic(e.target.value)} /></Field>
              </>
            )}
            {source === 'text' && (
              <>
                <Field label={t('your_text')}><textarea className="textarea" style={{ minHeight: 200 }} value={text} onChange={(e) => setText(e.target.value)} autoFocus placeholder={t('text_ph')} /></Field>
                <Field label={t('topic_optional')}><input className="input" value={topic} onChange={(e) => setTopic(e.target.value)} /></Field>
              </>
            )}
            <Field label={t('ai_kind')}>
              <div className="seg"><button className={kind === 'lesson' ? 'active' : ''} onClick={() => setKind('lesson')}>{t('ai_kind_lesson')}</button><button className={kind === 'test' ? 'active' : ''} onClick={() => setKind('test')}>{t('ai_kind_test')}</button></div>
            </Field>
            <div className="grid c2" style={{ gap: 12 }}>
              <Field label={t('questions_count')}>
                <div className="row"><input type="range" min={2} max={15} value={count} onChange={(e) => setCount(Number(e.target.value))} style={{ flex: 1 }} /><span className="chip brand">{count}</span></div>
              </Field>
              <Field label={t('difficulty')}>
                <div className="seg">{['easy', 'medium', 'hard'].map((d) => <button key={d} className={difficulty === d ? 'active' : ''} onClick={() => setDifficulty(d)}>{t('diff_' + d)}</button>)}</div>
              </Field>
            </div>
            <Field label={t('question_types')}>
              <div className="row wrap" style={{ gap: 6 }}>
                {TYPES.map((k) => <button key={k} className={'tab' + (types.has(k) ? ' active' : '')} onClick={() => { const n = new Set(types); n.has(k) ? (n.size > 1 && n.delete(k)) : n.add(k); setTypes(n) }}>{t('qt_' + k)}</button>)}
              </div>
            </Field>
            <Field label={t('language')}>
              <div className="seg">{Object.entries(LANGS).map(([k, v]) => <button key={k} className={language === v ? 'active' : ''} onClick={() => setLanguage(v)}>{k.toUpperCase()}</button>)}</div>
            </Field>
            {error && <div className="error-box">{msg(error)}</div>}
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button className="btn ghost" onClick={() => setSource(null)}><IcBack /> {t('back')}</button>
              <button className="btn primary" style={{ height: 46 }} disabled={!ready} onClick={go}><IcSparkles /> {t('generate')}</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}

function Generating() {
  const { t } = useT()
  const steps = ['ai_step_reading', 'ai_step_writing', 'ai_step_checking', 'ai_step_polishing']
  const [i, setI] = useState(0)
  const [sec, setSec] = useState(0)
  useEffect(() => {
    const a = window.setInterval(() => setI((x) => (x + 1) % steps.length), 3500)
    const b = window.setInterval(() => setSec((s) => s + 1), 1000)
    return () => { window.clearInterval(a); window.clearInterval(b) }
  }, [])
  return (
    <div className="ai-stage" style={{ maxWidth: 520, margin: '60px auto' }}>
      <div className="orbit">
        <div className="ring"><span className="dot-o" style={{ background: 'var(--coral)' }} /></div>
        <div className="ring" style={{ inset: 14, animationDuration: '6s', animationDirection: 'reverse' }}><span className="dot-o" style={{ background: 'var(--mint)' }} /></div>
        <div className="ring" style={{ inset: 28, animationDuration: '4s' }}><span className="dot-o" style={{ background: 'var(--amber)' }} /></div>
        <div className="core" />
      </div>
      <h2 style={{ fontSize: 22, fontWeight: 800 }}>{t('ai_generating_title')}</h2>
      <p className="muted mt8" key={i} style={{ animation: 'fade .4s' }}>{t(steps[i])}</p>
      <div className="sweep"><i /></div>
      <p className="tiny faint mt16">{t('ai_generating_hint')} · {sec}s</p>
    </div>
  )
}
