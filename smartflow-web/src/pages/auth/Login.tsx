import { useState, type FormEvent } from 'react'
import { apiBase, defaultApiBase, probe, saveSession, setApiBase } from '../../api/client'
import { setDemo } from '../../api/demo'
import { auth } from '../../api/endpoints'
import type { Role } from '../../api/types'
import { LangSwitch, useT } from '../../i18n'
import { errorText, Field, useErrorMessage } from '../../ui/kit'
import { Ill } from '../../ui/illustrations'

export function Login() {
  const { t } = useT()
  const msg = useErrorMessage()
  const [role, setRole] = useState<Role>('director')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [advanced, setAdvanced] = useState(false)
  const [server, setServer] = useState(() => (apiBase() === defaultApiBase() ? '' : apiBase()))

  function startDemo(r: Role) {
    setDemo(true)
    if (r === 'director') saveSession({ token: 'demo', role: 'director', id: 1, fullName: 'Шарипов Шоҳрух', email: 'director@cict.tj', serverUrl: 'demo' })
    else saveSession({ token: 'demo', role: 'teacher', id: 1, fullName: 'Раҳимова Нигина', email: 'n.rahimova@cict.tj', subject: 'BackEnd #1', serverUrl: 'demo' })
  }

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (busy) return
    setBusy(true); setError(null)
    setApiBase(server.trim() || null)
    try {
      if (server.trim() && !(await probe(server.trim()))) throw new Error('school_offline')
      if (role === 'director') {
        const r = await auth.directorLogin(email.trim(), password)
        saveSession({ token: r.access_token, role: 'director', id: r.director?.id ?? 0, fullName: r.director?.full_name ?? t('role_director'), email: email.trim(), serverUrl: apiBase() })
      } else {
        const r = await auth.teacherLogin(email.trim(), password)
        saveSession({ token: r.access_token, role: 'teacher', id: r.teacher.id, fullName: r.teacher.full_name, email: r.teacher.email, subject: r.teacher.subject, serverUrl: apiBase() })
      }
    } catch (err) {
      const code = errorText(err)
      setError(code === 'http_401' ? t('err_login') : code)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="auth">
      <div className="auth-hero">
        <div className="orb" style={{ width: 420, height: 420, right: -140, top: -120 }} />
        <div className="orb" style={{ width: 260, height: 260, left: -80, bottom: 60 }} />
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <div className="row">
            <div className="brand-mark" style={{ background: 'rgba(255,255,255,.18)', boxShadow: 'none' }}>S</div>
            <div className="brand-name">SmartFlow</div>
          </div>
          <LangSwitch light />
        </div>
        <div className="hero-ill"><Ill name="school" size={360} /></div>
        <h1>{t('hero_title')}</h1>
        <p>{t('hero_body')}</p>
        <div className="row wrap" style={{ marginTop: 26, gap: 8 }}>
          <span className="pill-w">📷 {t('hero_pill_attendance')}</span>
          <span className="pill-w">📚 {t('hero_pill_journal')}</span>
          <span className="pill-w">✨ {t('hero_pill_ai')}</span>
        </div>
      </div>
      <div className="auth-form">
        <form className="auth-card" onSubmit={submit}>
          <h2>{t('login_title')}</h2>
          <p className="lead">{t('login_lead')}</p>
          <div className="seg mb16">
            <button type="button" className={role === 'director' ? 'active' : ''} onClick={() => setRole('director')}>{t('role_director')}</button>
            <button type="button" className={role === 'teacher' ? 'active' : ''} onClick={() => setRole('teacher')}>{t('role_teacher')}</button>
          </div>
          <div className="col" style={{ gap: 14 }}>
            <Field label={t('email')}><input className="input" type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus /></Field>
            <Field label={t('password')}><input className="input" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required /></Field>
            {advanced && (
              <Field label={t('server_address')}>
                <input className="input" placeholder={defaultApiBase()} value={server} onChange={(e) => setServer(e.target.value)} />
                <span className="tiny faint">{t('server_hint')}</span>
              </Field>
            )}
            {error && <div className="error-box">{msg(error)}</div>}
            <button className="btn primary" style={{ height: 46 }} disabled={busy}>{busy ? t('signing_in') : t('sign_in')}</button>
            <button type="button" className="small faint" style={{ alignSelf: 'center' }} onClick={() => setAdvanced((v) => !v)}>{advanced ? t('hide_server') : t('show_server')}</button>
          </div>
          <div className="card tight mt24" style={{ background: 'var(--brand-tint)', borderColor: 'var(--brand-soft)', boxShadow: 'none' }}>
            <div className="row">
              <span style={{ fontSize: 22 }}>🎬</span>
              <div className="grow">
                <div className="bold">{t('demo_title')}</div>
                <div className="small muted">{t('demo_body')}</div>
              </div>
            </div>
            <div className="row mt12" style={{ gap: 8 }}>
              <button type="button" className="btn soft grow" style={{ background: 'var(--surface)' }} onClick={() => startDemo('director')}>{t('role_director')}</button>
              <button type="button" className="btn soft grow" style={{ background: 'var(--surface)' }} onClick={() => startDemo('teacher')}>{t('role_teacher')}</button>
            </div>
          </div>
        </form>
      </div>
    </div>
  )
}
