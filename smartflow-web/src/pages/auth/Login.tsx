import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { apiBase, publicBase, saveSession } from '../../api/client'
import { auth } from '../../api/endpoints'
import type { Role } from '../../api/types'
import { LangSwitch, useT } from '../../i18n'
import { errorText, Field, useErrorMessage } from '../../ui/kit'
import { Ill } from '../../ui/illustrations'
import { IcBack, IcBook, IcCamera, IcSparkles } from '../../ui/icons'

const ROLES: { role: Role; label: string }[] = [
  { role: 'director', label: 'role_director' },
  { role: 'teacher', label: 'role_teacher' },
  { role: 'parent', label: 'role_parent' },
  { role: 'student', label: 'role_student' },
]

export function Login() {
  const { t } = useT()
  const msg = useErrorMessage()
  const [role, setRole] = useState<Role>('director')
  const [ident, setIdent] = useState('')   // email / phone / username
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const isParent = role === 'parent'
  const isStudent = role === 'student'
  const identLabel = isParent ? t('phone') : isStudent ? t('username') : t('email')
  const identType = isParent ? 'tel' : 'text'

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (busy) return
    setBusy(true); setError(null)
    try {
      if (role === 'director') {
        const r = await auth.directorLogin(ident.trim(), password)
        saveSession({ token: r.access_token, role: 'director', id: r.director?.id ?? 0, fullName: r.director?.full_name ?? t('role_director'), email: ident.trim(), serverUrl: apiBase() })
      } else if (role === 'teacher') {
        const r = await auth.teacherLogin(ident.trim(), password)
        saveSession({ token: r.access_token, role: 'teacher', id: r.teacher.id, fullName: r.teacher.full_name, email: r.teacher.email, subject: r.teacher.subject, serverUrl: apiBase() })
      } else if (role === 'parent') {
        const r = await auth.parentLogin(ident.trim(), password)
        if (r.status === 'needs_password' || !r.access_token) { setError(t('err_needs_password')); return }
        saveSession({ token: r.access_token, role: 'parent', id: r.parent_id ?? 0, fullName: r.full_name ?? t('role_parent'), email: '', phone: r.phone ?? ident.trim(), serverUrl: publicBase() })
      } else {
        const r = await auth.studentLogin(ident.trim(), password)
        saveSession({ token: r.access_token, role: 'student', id: r.student_id, fullName: r.full_name, email: '', className: r.class_name, serverUrl: publicBase() })
      }
    } catch (err) {
      const code = errorText(err)
      setError(code === 'http_401' || code === 'invalid_credentials' ? t('err_login')
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
          <div className="seg seg-4 mb16">
            {ROLES.map((r) => (
              <button key={r.role} type="button" className={role === r.role ? 'active' : ''} onClick={() => { setRole(r.role); setError(null) }}>{t(r.label)}</button>
            ))}
          </div>
          <div className="col" style={{ gap: 14 }}>
            <Field label={identLabel}>
              <input className="input" type={identType} inputMode={isParent ? 'tel' : undefined}
                autoComplete={isParent ? 'tel' : 'username'} value={ident}
                onChange={(e) => setIdent(e.target.value)} required autoFocus
                placeholder={isParent ? '+992…' : undefined} />
            </Field>
            <Field label={t('password')}><input className="input" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required /></Field>
            {error && <div className="error-box">{msg(error)}</div>}
            <button className="btn primary" style={{ height: 46 }} disabled={busy}>{busy ? t('signing_in') : t('sign_in')}</button>
          </div>
          {(isParent || isStudent) && <p className="small muted mt12" style={{ textAlign: 'center' }}>{t('family_login_hint')}</p>}
        </form>
      </div>
    </div>
  )
}
