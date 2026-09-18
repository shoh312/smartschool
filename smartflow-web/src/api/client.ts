import type { Session } from './types'

/**
 * Where the school server is.
 *
 * The page is served by the public server, which forwards `/relay/...` to
 * the school over its tunnel -- so by default we talk to our own origin and
 * let the relay route it. On the school Wi-Fi a director can point the app
 * straight at the school box (faster video); that address is kept in
 * localStorage. `VITE_API_BASE` is for `npm run dev` against a LAN server.
 */
const STORAGE_API = 'sf.api'
const STORAGE_SESSION = 'sf.session'

export function defaultApiBase(): string {
  const env = import.meta.env.VITE_API_BASE as string | undefined
  if (env) return env.endsWith('/') ? env : env + '/'
  return `${location.origin}/relay/`
}

export function apiBase(): string {
  try {
    const saved = localStorage.getItem(STORAGE_API)
    if (saved) return saved.endsWith('/') ? saved : saved + '/'
  } catch {}
  return defaultApiBase()
}

export function setApiBase(url: string | null) {
  try {
    if (url && url.trim()) localStorage.setItem(STORAGE_API, url.trim())
    else localStorage.removeItem(STORAGE_API)
  } catch {}
}

export function wsBase(): string {
  return apiBase().replace(/^http/, 'ws')
}

// ------------------------------------------------------------- session

let session: Session | null = null
const listeners = new Set<() => void>()

export function loadSession(): Session | null {
  if (session) return session
  try {
    const raw = localStorage.getItem(STORAGE_SESSION)
    if (raw) session = JSON.parse(raw) as Session
    if (session?.token === 'demo') { session = null; localStorage.removeItem(STORAGE_SESSION) }
  } catch {}
  return session
}

export function saveSession(s: Session | null) {
  session = s
  try {
    if (s) localStorage.setItem(STORAGE_SESSION, JSON.stringify(s))
    else localStorage.removeItem(STORAGE_SESSION)
  } catch {}
  listeners.forEach((l) => l())
}

export function onSessionChange(l: () => void): () => void {
  listeners.add(l)
  return () => listeners.delete(l)
}

// --------------------------------------------------------------- errors

export class ApiError extends Error {
  constructor(public status: number, public detail: string) {
    super(detail)
  }
}

function detailOf(body: unknown, status: number): string {
  if (body && typeof body === 'object' && 'detail' in body) {
    const d = (body as { detail: unknown }).detail
    if (typeof d === 'string') return d
    if (Array.isArray(d) && d.length && typeof d[0]?.msg === 'string') return d[0].msg
  }
  return `http_${status}`
}

// ----------------------------------------------------------------- fetch

interface Options {
  method?: string
  body?: unknown
  form?: FormData
  query?: Record<string, string | number | boolean | null | undefined>
  timeoutMs?: number
  auth?: boolean
}

export async function request<T>(path: string, o: Options = {}): Promise<T> {
  const url = new URL(path.replace(/^\//, ''), apiBase())
  if (o.query) for (const [k, v] of Object.entries(o.query)) if (v !== undefined && v !== null) url.searchParams.set(k, String(v))
  const headers: Record<string, string> = { Accept: 'application/json' }
  const s = loadSession()
  if (o.auth !== false && s) headers.Authorization = `Bearer ${s.token}`
  let body: BodyInit | undefined
  if (o.form) body = o.form
  else if (o.body !== undefined) {
    headers['Content-Type'] = 'application/json'
    body = JSON.stringify(o.body)
  }
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), o.timeoutMs ?? 30000)
  let res: Response
  try {
    res = await fetch(url.toString(), { method: o.method ?? (body ? 'POST' : 'GET'), headers, body, signal: ctrl.signal })
  } catch (e) {
    clearTimeout(timer)
    throw new ApiError(0, ctrl.signal.aborted ? 'timeout' : 'network')
  }
  clearTimeout(timer)
  const text = await res.text()
  let json: unknown = null
  if (text) {
    try { json = JSON.parse(text) } catch { json = text }
  }
  if (!res.ok) {
    if (res.status === 401 && o.auth !== false && s) saveSession(null)
    throw new ApiError(res.status, detailOf(json, res.status))
  }
  return json as T
}

export const get = <T,>(path: string, query?: Options['query']) => request<T>(path, { query })
export const post = <T,>(path: string, body?: unknown, extra: Options = {}) => request<T>(path, { method: 'POST', body, ...extra })
export const patch = <T,>(path: string, body?: unknown) => request<T>(path, { method: 'PATCH', body })
export const put = <T,>(path: string, body?: unknown) => request<T>(path, { method: 'PUT', body })
export const del = <T,>(path: string) => request<T>(path, { method: 'DELETE' })

/** True when the school server answers at the given address. */
export async function probe(base: string, timeoutMs = 4000): Promise<boolean> {
  const ctrl = new AbortController()
  const t = setTimeout(() => ctrl.abort(), timeoutMs)
  try {
    const url = new URL('', base.endsWith('/') ? base : base + '/')  // GET / answers {"message": ...}
    const r = await fetch(url.toString(), { signal: ctrl.signal })
    return r.ok
  } catch {
    return false
  } finally {
    clearTimeout(t)
  }
}
