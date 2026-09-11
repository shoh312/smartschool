import { useEffect, useState } from 'react'
import { apiBase, defaultApiBase, probe, setApiBase } from '../../api/client'
import { director } from '../../api/endpoints'
import type { SchoolSettingsDto } from '../../api/types'
import { useT } from '../../i18n'
import { ErrorBox, errorText, Field, Skeleton, Toggle, useAsync, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function Settings() {
  const { t } = useT()
  const toast = useToast()
  const s = useAsync(() => director.settings(), [])
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

  const rows: { key: keyof SchoolSettingsDto; title: string; body: string }[] = [
    { key: 'live_video_enabled', title: t('set_live'), body: t('set_live_body') },
    { key: 'group_mode', title: t('set_group'), body: t('set_group_body') },
    { key: 'sms_enabled', title: t('set_sms'), body: t('set_sms_body') },
  ]

  return (
    <>
      <TopBar title={t('nav_settings')} sub={t('settings_sub')} />
      <div className="grid c2">
        <div className="card">
          <div className="card-title">{t('school_settings')}</div>
          <ErrorBox error={s.error} onRetry={s.reload} />
          {!local && s.loading && <Skeleton rows={3} h={56} />}
          {local && rows.map((r) => (
            <div key={r.key} className="row" style={{ padding: '12px 0', borderBottom: '1px solid var(--border)' }}>
              <div className="grow"><div className="bold">{r.title}</div><div className="small muted">{r.body}</div></div>
              <Toggle on={!!local[r.key]} onChange={(v) => flip(r.key, v)} />
            </div>
          ))}
        </div>
        <div className="card">
          <div className="card-title">{t('connection')}</div>
          <p className="small muted mb12">{t('connection_body')}</p>
          <Field label={t('server_address')}>
            <input className="input" placeholder={defaultApiBase()} value={server} onChange={(e) => { setServer(e.target.value); setProbing(null) }} />
          </Field>
          {probing === false && <div className="error-box mt8">{t('err_school_offline')}</div>}
          <div className="row mt12">
            <button className="btn primary" onClick={saveServer}>{t('save')}</button>
            <span className="tiny faint">{t('current')}: {apiBase()}</span>
          </div>
        </div>
      </div>
    </>
  )
}
