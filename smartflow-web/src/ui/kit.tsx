import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react'
import { ApiError } from '../api/client'
import { LOCALE, useT } from '../i18n'
import { IcX } from './icons'

// ------------------------------------------------------------- async data

export interface Async<T> { data?: T; error?: string; loading: boolean }

/** Loads once per `deps`, exposes a reload that keeps the old data on screen. */
export function useAsync<T>(fn: () => Promise<T>, deps: unknown[]): Async<T> & { reload: () => void } {
  const [state, set] = useState<Async<T>>({ loading: true })
  const seq = useRef(0)
  const run = useCallback(() => {
    const id = ++seq.current
    set((s) => ({ ...s, loading: true, error: undefined }))
    fn().then(
      (data) => { if (id === seq.current) set({ data, loading: false }) },
      (e) => { if (id === seq.current) set((s) => ({ ...s, loading: false, error: errorText(e) })) },
    )
  }, deps) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(run, [run])
  return { ...state, reload: run }
}

export function errorText(e: unknown): string {
  if (e instanceof ApiError) return e.detail
  if (e instanceof Error) return e.message
  return String(e)
}

/** Server error codes → sentences. Anything with spaces is already a sentence. */
export function useErrorMessage() {
  const { t } = useT()
  return (code?: string | null) => {
    if (!code) return ''
    if (code.includes(' ')) return code
    const map: Record<string, string> = {
      network: t('err_network'), timeout: t('err_timeout'), school_offline: t('err_school_offline'), school_not_found: t('err_school_offline'),
      school_timeout: t('err_timeout'), http_401: t('err_auth'), http_403: t('err_forbidden'), http_404: t('err_not_found'), http_500: t('err_server'),
      relay_local_error: t('err_server'), live_video_disabled: t('err_live_disabled'),
    }
    return map[code] ?? code
  }
}

// ------------------------------------------------------------------ toast

const ToastCtx = createContext<(msg: string) => void>(() => {})
export function ToastProvider({ children }: { children: ReactNode }) {
  const [msg, setMsg] = useState<string | null>(null)
  const timer = useRef<number>()
  const show = useCallback((m: string) => {
    setMsg(m)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => setMsg(null), 2600)
  }, [])
  return (
    <ToastCtx.Provider value={show}>
      {children}
      {msg && <div className="toast">{msg}</div>}
    </ToastCtx.Provider>
  )
}
export const useToast = () => useContext(ToastCtx)

// ------------------------------------------------------------------ modal

export function Modal({ title, lead, onClose, children, wide, full, actions }: { title?: string; lead?: string; onClose: () => void; children: ReactNode; wide?: boolean; full?: boolean; actions?: ReactNode }) {
  useEffect(() => {
    const k = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', k)
    return () => window.removeEventListener('keydown', k)
  }, [onClose])
  return (
    <div className="overlay" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className={'modal' + (wide ? ' wide' : '') + (full ? ' full' : '')}>
        <div className="row" style={{ alignItems: 'flex-start' }}>
          <div className="grow">
            {title && <h2>{title}</h2>}
            {lead && <p className="lead">{lead}</p>}
          </div>
          <button className="btn ghost icon sm" onClick={onClose} aria-label="close"><IcX /></button>
        </div>
        {children}
        {actions && <div className="modal-actions">{actions}</div>}
      </div>
    </div>
  )
}

export function Confirm({ title, body, onYes, onNo, danger }: { title: string; body?: string; onYes: () => void; onNo: () => void; danger?: boolean }) {
  const { t } = useT()
  return (
    <Modal title={title} onClose={onNo} actions={<>
      <button className="btn ghost" onClick={onNo}>{t('cancel')}</button>
      <button className={'btn ' + (danger ? 'danger' : 'primary')} onClick={onYes}>{danger ? t('delete') : t('ok')}</button>
    </>}>
      {body && <p className="muted">{body}</p>}
    </Modal>
  )
}

// ------------------------------------------------------------- small bits

export function Empty({ icon = '🗂️', title, body }: { icon?: string; title: string; body?: string }) {
  return (
    <div className="empty">
      <div className="ill">{icon}</div>
      <h3>{title}</h3>
      {body && <p className="small">{body}</p>}
    </div>
  )
}

export function ErrorBox({ error, onRetry }: { error?: string; onRetry?: () => void }) {
  const { t } = useT()
  const msg = useErrorMessage()
  if (!error) return null
  return (
    <div className="error-box row">
      <span className="grow">{msg(error)}</span>
      {onRetry && <button className="btn sm ghost" onClick={onRetry}>{t('retry')}</button>}
    </div>
  )
}

export function Skeleton({ rows = 4, h = 56 }: { rows?: number; h?: number }) {
  return <div className="col">{Array.from({ length: rows }).map((_, i) => <div key={i} className="skeleton" style={{ height: h }} />)}</div>
}

export function Avatar({ first, last, id, size }: { first: string; last: string; id: number; size?: 'sm' | 'lg' }) {
  const cls = 'avatar' + (size ? ' ' + size : '') + (id % 5 ? ` p${id % 5}` : '')
  return <div className={cls}>{(last[0] ?? '') + (first[0] ?? '')}</div>
}

export function gradeClass(v?: number | null): string {
  if (v == null) return 'g-none'
  return v >= 8 ? 'g-hi' : v >= 6 ? 'g-mid' : 'g-lo'
}
export function Grade({ v, className }: { v?: number | null; className?: string }) {
  return <span className={'grade ' + gradeClass(v) + (className ? ' ' + className : '')}>{v == null ? '—' : Number.isInteger(v) ? v : v.toFixed(1)}</span>
}
export const fmtAvg = (v?: number | null) => (v == null ? '—' : v.toFixed(1))

export function Toggle({ on, onChange }: { on: boolean; onChange: (v: boolean) => void }) {
  return <button type="button" className={'toggle' + (on ? ' on' : '')} onClick={() => onChange(!on)} aria-pressed={on} />
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return <div className="field"><label>{label}</label>{children}</div>
}

// ------------------------------------------------------------ formatting

export function useFmt() {
  const { lang } = useT()
  const loc = LOCALE[lang]
  return {
    date: (iso?: string | null) => (iso ? new Date(iso.length <= 10 ? iso + 'T00:00:00' : iso).toLocaleDateString(loc, { day: 'numeric', month: 'short' }) : ''),
    dateLong: (iso?: string | null) => (iso ? new Date(iso.length <= 10 ? iso + 'T00:00:00' : iso).toLocaleDateString(loc, { weekday: 'long', day: 'numeric', month: 'long' }) : ''),
    dateTime: (iso?: string | null) => (iso ? new Date(iso).toLocaleString(loc, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : ''),
    time: (iso?: string | null) => (iso ? new Date(iso).toLocaleTimeString(loc, { hour: '2-digit', minute: '2-digit' }) : ''),
    weekday: (iso: string) => new Date(iso + 'T00:00:00').toLocaleDateString(loc, { weekday: 'short' }),
    ddmm: (iso: string) => { const d = new Date(iso + 'T00:00:00'); return `${String(d.getDate()).padStart(2, '0')}.${String(d.getMonth() + 1).padStart(2, '0')}` },
  }
}

export const todayIso = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` }
export const addDays = (iso: string, n: number) => { const d = new Date(iso + 'T00:00:00'); d.setDate(d.getDate() + n); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` }
