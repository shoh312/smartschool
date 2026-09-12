import { useEffect, useState } from 'react'
import { apiBase, defaultApiBase, probe, setApiBase } from '../../api/client'
import { isDemo } from '../../api/demo'
import { director } from '../../api/endpoints'
import type { SchoolSettingsDto } from '../../api/types'
import { useT, type Lang } from '../../i18n'
import { useSession } from '../../App'
import { ErrorBox, errorText, Field, Skeleton, Toggle, useAsync, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'
import { IcGlobe, IcUser, IcWifi } from '../../ui/icons'
import { Ill, type IllName } from '../../ui/illustrations'

const LANGS: { code: Lang; name: string; native: string }[] = [
  { code: 'tg', name: 'Тоҷикӣ', native: 'Tajik' },
  { code: 'ru', name: 'Русский', native: 'Russian' },
  { code: 'en', name: 'English', native: 'English' },
]

/** Language and connection for everyone; the school switches for a director. */
export function Settings() {
  const { t, lang, setLang } = useT()
  const toast = useToast()
  const session = useSession()
  const isDirector = session?.role === 'director'
  const s = useAsync(() => (isDirector ? director.settings() : Promise.resolve(null)), [isDirector])
  const [local, setLocal] = useState<SchoolSettingsDto | null>(null)
  const [server, setServer] = useState(() => (apiBase() === defaultApiBase() ? '' : apiBase()))
  const [probing, setProbing] = useState<null | boolean>(null)
  useEffect(() => { if (s.data) setLocal(s.data) }, [s.data])

  async function flip(key: keyof SchoolSettingsDto, v: boolean) {
    if (!local) return
    const prev = local
    setLocal({ ...local, [key]: v })
    try { setLocal(await director.updateSettings({ [key]: v })); toast(t('saved')) } catch (e) { setLocal(prev); toast(errorText(e)) }
  }
  async function saveServer() {
    setProbing(null)
    const v = server.trim()
    if (v) { const ok = await probe(v); setProbing(ok); if (!ok) return }
    setApiBase(v || null); toast(t('saved'))
  }

  const rows: { key: keyof SchoolSettingsDto; title: string; body: string; ill: IllName }[] = [
    { key: 'live_video_enabled', title: t('set_live'), body: t('set_live_body'), ill: 'door_check' as IllName },
    { key: 'group_mode', title: t('set_group'), body: t('set_group_body'), ill: 'school' as IllName },
    { key: 'sms_enabled', title: t('set_sms'), body: t('set_sms_body'), ill: 'phone_sms' as IllName },
  ]

  return (
    <>
      <TopBar title={t('nav_settings')} sub={t('settings_sub')} />
      <div className="grid c2" style={{ alignItems: 'start' }}>
        <div className="col" style={{ gap: 16 }}>
          <div className="card">
            <div className="card-title"><IcGlobe style={{ width: 20, color: 'var(--brand)' }} /> {t('language_title')}</div>
            <p className="small muted mb12">{t('language_body')}</p>
            <div className="lang-cards">
              {LANGS.map((l) => (
                <button key={l.code} className={'lang-card' + (lang === l.code ? ' active' : '')} onClick={() => { setLang(l.code); toast(t('saved')) }}>
                  <span className="fl">{l.code.toUpperCase()}</span>
                  <span><span className="nm" style={{ display: 'block' }}>{l.name}</span><span className="cd">{l.native}</span></span>
                </button>
              ))}
            </div>
          </div>
          {!isDemo() && (
            <div className="card">
              <div className="card-title"><IcWifi style={{ width: 20, color: 'var(--sky)' }} /> {t('connection')}</div>
              <p className="small muted mb12">{t('connection_body')}</p>
              <Field label={t('server_address')}>
                <input className="input" placeholder={defaultApiBase()} value={server} onChange={(e) => { setServer(e.target.value); setProbing(null) }} />
              </Field>
              {probing === false && <div className="error-box mt8">{t('err_school_offline')}</div>}
              <div className="row mt12">
                <button className="btn primary" onClick={saveServer}>{t('save')}</button>
                <span className="tiny faint ellipsis">{t('current')}: {apiBase()}</span>
              </div>
            </div>
          )}
        </div>
        <div className="col" style={{ gap: 16 }}>
          {isDirector && (
            <div className="card">
              <div className="card-title"><Ill name="school" size={34} /> {t('school_settings')}</div>
              <ErrorBox error={s.error} onRetry={s.reload} />
              {!local && s.loading && <Skeleton rows={3} h={56} />}
              {local && rows.map((r, i) => (
                <div key={r.key} className="row" style={{ padding: '14px 0', borderBottom: i < rows.length - 1 ? '1px solid var(--border)' : 0 }}>
                  <span className="stat-ic" style={{ width: 44, height: 44, borderRadius: 13, background: 'var(--surface-soft)' }}><Ill name={r.ill} size={40} /></span>
                  <div className="grow"><div className="bold">{r.title}</div><div className="small muted">{r.body}</div></div>
                  <Toggle on={!!local[r.key]} onChange={(v) => flip(r.key, v)} />
                </div>
              ))}
            </div>
          )}
          <div className="card">
            <div className="card-title"><IcUser style={{ width: 20, color: 'var(--ink-2)' }} /> {t('account')}</div>
            <div className="row">
              <div className="avatar">{session?.fullName.split(' ').map((w) => w[0]).slice(0, 2).join('')}</div>
              <div className="grow">
                <div className="bold">{session?.fullName}</div>
                <div className="small muted">{session?.email}{session?.subject ? ` · ${session.subject}` : ''}</div>
              </div>
              <span className={'chip ' + (isDemo() ? 'amber' : 'brand')}>{isDemo() ? 'DEMO' : isDirector ? t('role_director') : t('role_teacher')}</span>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}
