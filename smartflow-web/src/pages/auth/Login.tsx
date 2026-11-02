import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { ApiError, apiBase, publicBase, saveSession } from '../../api/client'
import { auth } from '../../api/endpoints'
import { LangSwitch, useT } from '../../i18n'
import { errorText, Field, useErrorMessage } from '../../ui/kit'
import { Ill } from '../../ui/illustrations'
import { IcBack, IcBook, IcCamera, IcSparkles } from '../../ui/icons'

/** Which account the typed login belongs to: an email is staff (director or
 *  teacher, the school server tells which), a phone number is a parent, and
 *  anything else is a pupil's username. */
function kindOf(ident: string): 'staff' | 'parent' | 'student' {
  const v = ident.trim()
  if (v.includes('@')) return 'staff'
  if (/^\+?[\d\s()-]{7,}$/.test(v)) return 'parent'
  return 'student'
}

export function Login() {
  const { t } = useT()
  const msg = useErrorMessage()
  const [ident, setIdent] = useState('')   // email / phone / username
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function staffLogin(email: string) {
    let r
    try {
      r = await auth.staffLogin(email, password)
    } catch (err) {
      // School server not updated yet -- no single staff login there.
      if (!(err instanceof ApiError && err.status === 404)) throw err
      try {
        const d = await auth.directorLogin(email, password)
        r = { ...d, user_type: 'director' as const, teacher: null }
      } catch (dirErr) {
        if (!(dirErr instanceof ApiError && dirErr.status === 401)) throw dirErr
        const tr = await auth.teacherLogin(email, password)
        r = { ...tr, user_type: 'teacher' as const, director: null }
      }
    }
    if (r.user_type === 'teacher' && r.teacher) {
      saveSession({ token: r.access_token, role: 'teacher', id: r.teacher.id, fullName: r.teacher.full_name, email: r.teacher.email, subject: r.teacher.subject, serverUrl: apiBase() })
    } else {
      saveSession({ token: r.access_token, role: 'director', id: r.director?.id ?? 0, fullName: r.director?.full_name ?? t('role_director'), email, serverUrl: apiBase() })
    }
  }

  async function studentLogin(username: string) {
    const r = await auth.studentLogin(username, password)
    saveSession({ token: r.access_token, role: 'student', id: r.student_id, fullName: r.full_name, email: '', className: r.class_name, serverUrl: publicBase() })
  }

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (busy) return
    setBusy(true); setError(null)
    try {
      const login = ident.trim()
      const kind = kindOf(login)
      if (kind === 'staff') {
        await staffLogin(login)
      } else if (kind === 'parent') {
        try {
          const r = await auth.parentLogin(login, password)
          if (r.status === 'needs_password' || !r.access_token) { setError(t('err_needs_password')); return }
          saveSession({ token: r.access_token, role: 'parent', id: r.parent_id ?? 0, fullName: r.full_name ?? t('role_parent'), email: '', phone: r.phone ?? login, serverUrl: publicBase() })
        } catch (err) {
          // A pupil's username can be all digits -- not a parent, try that.
          if (errorText(err) !== 'phone_not_registered') throw err
          await studentLogin(login)
        }
      } else {
        await studentLogin(login)
      }
    } catch (err) {
      const code = errorText(err)
      setError(code === 'http_401' || code === 'invalid_credentials' ? t('err_login')
        : code === 'too_many_attempts' ? t('err_too_many_attempts')
        : code === 'phone_not_registered' ? t('err_phone_unknown') : code)
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
          <span className="pill-w"><IcCamera /> {t('hero_pill_attendance')}</span>
          <span className="pill-w"><IcBook /> {t('hero_pill_journal')}</span>
          <span className="pill-w"><IcSparkles /> {t('hero_pill_ai')}</span>
        </div>
      </div>
      <div className="auth-form">
        <form className="auth-card" onSubmit={submit}>
          <Link to="/" className="ld-back"><IcBack /> {t('ld_back_home')}</Link>
          <h2>{t('login_title')}</h2>
          <p className="lead">{t('login_lead')}</p>
          <div className="col" style={{ gap: 14 }}>
            <Field label={t('login_ident')}>
              <input className="input" type="text" autoComplete="username" autoCapitalize="none" value={ident}
                onChange={(e) => { setIdent(e.target.value); setError(null) }} required autoFocus />
            </Field>
            <Field label={t('password')}><input className="input" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required /></Field>
            {error && <div className="error-box">{msg(error)}</div>}
            <button className="btn primary" style={{ height: 46 }} disabled={busy}>{busy ? t('signing_in') : t('sign_in')}</button>
          </div>
          <p className="small muted mt12" style={{ textAlign: 'center' }}>{t('family_login_hint')}</p>
        </form>
      </div>
    </div>
  )
}
