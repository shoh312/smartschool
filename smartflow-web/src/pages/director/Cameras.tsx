import { useEffect, useRef, useState } from 'react'
import { loadSession, wsBase } from '../../api/client'
import { director } from '../../api/endpoints'
import type { CameraDto, CameraPositionDto, CameraStatusDto, ClassDto } from '../../api/types'
import { useT } from '../../i18n'
import { IcClock, IcEdit, IcExpand, IcPlay, IcPlus, IcTrash } from '../../ui/icons'
import { Confirm, Empty, ErrorBox, errorText, Field, Modal, Skeleton, useAsync, useErrorMessage, useToast } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'
import { phaseText } from './Home'

export function Cameras() {
  const { t } = useT()
  const toast = useToast()
  const cameras = useAsync(() => director.cameras(), [])
  const classes = useAsync(() => director.classes(), [])
  const [status, setStatus] = useState<Map<number, CameraStatusDto>>(new Map())
  const [watching, setWatching] = useState<CameraDto | null>(null)
  const [positions, setPositions] = useState<CameraDto | null>(null)
  const [editing, setEditing] = useState<CameraDto | null | 'new'>(null)
  const [deleting, setDeleting] = useState<CameraDto | null>(null)

  useEffect(() => {
    let alive = true
    const tick = async () => { try { const s = await director.cameraStatus(); if (alive) setStatus(new Map(s.map((x) => [x.camera_id, x]))) } catch {} }
    tick()
    const id = window.setInterval(tick, 4000)
    return () => { alive = false; window.clearInterval(id) }
  }, [])

  async function remove() {
    if (!deleting) return
    try { await director.deleteCamera(deleting.id); toast(t('deleted')); cameras.reload() } catch (e) { toast(errorText(e)) }
    setDeleting(null)
  }

  return (
    <>
      <TopBar title={t('nav_cameras')} sub={t('cameras_sub')}>
        <button className="btn primary" onClick={() => setEditing('new')}><IcPlus /> {t('add_camera')}</button>
      </TopBar>
      <ErrorBox error={cameras.error} onRetry={cameras.reload} />
      {cameras.loading && !cameras.data && <div className="grid c3"><Skeleton rows={1} h={220} /><Skeleton rows={1} h={220} /></div>}
      {cameras.data?.length === 0 && <Empty icon="📷" title={t('no_cameras')} body={t('no_cameras_body')} />}
      <div className="grid c3">
        {cameras.data?.map((c) => {
          const s = status.get(c.id)
          const on = !!s?.connected
          return (
            <div key={c.id} className="card cam-card">
              <div className="cam-thumb" onClick={() => setWatching(c)} style={{ cursor: 'pointer' }}>
                <div className="play"><IcPlay style={{ width: 22, height: 22 }} /></div>
                <div className="badge" style={{ position: 'absolute', top: 10, left: 10 }}>
                  <span className={'chip ' + (on ? 'mint' : '')} style={{ background: on ? 'rgba(43,182,115,.9)' : 'rgba(0,0,0,.45)', color: '#fff' }}>{on ? <span className="live-dot" style={{ background: '#fff' }} /> : null} {on ? 'LIVE' : t('cam_offline')}</span>
                </div>
              </div>
              <div className="row">
                <div className="grow">
                  <div className="bold">{c.name}</div>
                  <div className="small muted">{s?.class_name ?? classes.data?.find((k) => k.id === c.class_id)?.name ?? '—'} · {s ? phaseText(s, t) : '…'}</div>
                </div>
                {s?.detecting && <span className="chip mint">{t('detecting')}</span>}
              </div>
              <div className="row mt12" style={{ gap: 6 }}>
                <button className="btn sm soft" onClick={() => setPositions(c)}><IcClock /> {t('timetable')}</button>
                <button className="btn sm ghost icon" onClick={() => setEditing(c)}><IcEdit /></button>
                <button className="btn sm ghost icon" onClick={() => setDeleting(c)}><IcTrash /></button>
              </div>
            </div>
          )
        })}
      </div>
      {watching && <LiveModal camera={watching} status={status.get(watching.id)} onClose={() => setWatching(null)} />}
      {positions && <PositionsModal camera={positions} classes={classes.data ?? []} onClose={() => setPositions(null)} />}
      {editing && <CameraForm camera={editing === 'new' ? null : editing} classes={classes.data ?? []} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); cameras.reload() }} />}
      {deleting && <Confirm danger title={t('delete_camera_q', deleting.name)} onNo={() => setDeleting(null)} onYes={remove} />}
    </>
  )
}

/** JPEG frames over a websocket, painted into an <img>. */
export function LiveVideo({ cameraId }: { cameraId: number }) {
  const { t } = useT()
  const msg = useErrorMessage()
  const img = useRef<HTMLImageElement>(null)
  const box = useRef<HTMLDivElement>(null)
  const [state, setState] = useState<'connecting' | 'live' | 'closed'>('connecting')
  const [reason, setReason] = useState<string>('')
  const [fps, setFps] = useState(0)

  useEffect(() => {
    const s = loadSession()
    if (!s) return
    let url: string | null = null
    let frames = 0
    const ws = new WebSocket(`${wsBase()}ws/stream?camera_id=${cameraId}&token=${encodeURIComponent(s.token)}`)
    ws.binaryType = 'blob'
    ws.onopen = () => setState('connecting')
    ws.onmessage = (ev) => {
      if (!(ev.data instanceof Blob)) return
      const next = URL.createObjectURL(ev.data)
      if (img.current) img.current.src = next
      if (url) URL.revokeObjectURL(url)
      url = next
      frames++
      setState('live')
    }
    ws.onclose = (ev) => { setState('closed'); setReason(ev.reason || '') }
    ws.onerror = () => setState('closed')
    const fpsTimer = window.setInterval(() => { setFps(frames); frames = 0 }, 1000)
    return () => { ws.close(); window.clearInterval(fpsTimer); if (url) URL.revokeObjectURL(url) }
  }, [cameraId])

  return (
    <div className="video" ref={box}>
      <img ref={img} alt="" style={{ display: state === 'live' ? 'block' : 'none' }} />
      {state !== 'live' && (
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 34, marginBottom: 8 }}>{state === 'closed' ? '📷' : '⏳'}</div>
          <div className="bold">{state === 'closed' ? (reason ? msg(reason) : t('cam_no_signal')) : t('connecting')}</div>
          {state === 'closed' && !reason && <div className="small" style={{ opacity: .7 }}>{t('cam_no_signal_hint')}</div>}
        </div>
      )}
      {state === 'live' && <div className="badge"><span className="chip" style={{ background: 'rgba(0,0,0,.5)', color: '#fff' }}><span className="live-dot" /> LIVE · {fps} fps</span></div>}
      <button className="fs" title={t('fullscreen')} onClick={() => { const el = box.current; if (!el) return; if (document.fullscreenElement) document.exitFullscreen(); else el.requestFullscreen?.() }}><IcExpand /></button>
    </div>
  )
}

function LiveModal({ camera, status, onClose }: { camera: CameraDto; status?: CameraStatusDto; onClose: () => void }) {
  const { t } = useT()
  return (
    <Modal title={camera.name} lead={status ? `${status.class_name ?? ''} · ${phaseText(status, t)}` : undefined} onClose={onClose} full>
      <LiveVideo cameraId={camera.id} />
    </Modal>
  )
}

const DAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
function fmtTime(v: string) {
  // "1400" -> "14:00", keeps ":" if typed
  const d = v.replace(/\D/g, '').slice(0, 4)
  return d.length > 2 ? `${d.slice(0, 2)}:${d.slice(2)}` : d
}

function PositionsModal({ camera, classes, onClose }: { camera: CameraDto; classes: ClassDto[]; onClose: () => void }) {
  const { t } = useT()
  const toast = useToast()
  const msg = useErrorMessage()
  const list = useAsync(() => director.positions(camera.id), [camera.id])
  const [form, setForm] = useState({ class_id: classes[0]?.id ?? 0, day: -1, start: '', end: '', subject: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const valid = form.class_id && /^\d{2}:\d{2}$/.test(form.start) && /^\d{2}:\d{2}$/.test(form.end)

  async function add() {
    if (!valid || busy) return
    setBusy(true); setError(null)
    try {
      await director.createPosition(camera.id, { class_id: form.class_id, start_time: form.start, end_time: form.end, subject: form.subject.trim() || null, day_of_week: form.day < 0 ? null : form.day })
      setForm({ ...form, start: '', end: '' }); list.reload(); toast(t('saved'))
    } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }
  async function remove(p: CameraPositionDto) {
    try { await director.deletePosition(camera.id, p.id); list.reload() } catch (e) { toast(errorText(e)) }
  }

  return (
    <Modal title={t('timetable')} lead={`${camera.name} · ${t('positions_lead')}`} onClose={onClose} wide>
      <div className="col" style={{ gap: 8 }}>
        {list.data?.length === 0 && <div className="muted small">{t('no_positions')}</div>}
        {list.data?.map((p) => (
          <div key={p.id} className="row card tight" style={{ boxShadow: 'none' }}>
            <span className="chip brand">{p.start_time.slice(0, 5)}–{p.end_time.slice(0, 5)}</span>
            <div className="grow">
              <div className="bold small">{p.class_name ?? classes.find((c) => c.id === p.class_id)?.name}</div>
              <div className="tiny faint">{p.day_of_week == null ? t('every_day') : t('day_' + DAYS[p.day_of_week])}{p.subject ? ` · ${p.subject}` : ''}</div>
            </div>
            <button className="btn sm ghost icon" onClick={() => remove(p)}><IcTrash /></button>
          </div>
        ))}
      </div>
      <div className="section-title" style={{ fontSize: 14, margin: '18px 0 10px' }}>{t('add_position')}</div>
      <div className="grid c3" style={{ gap: 10 }}>
        <Field label={t('class')}>
          <select className="select" value={form.class_id} onChange={(e) => setForm({ ...form, class_id: Number(e.target.value) })}>{classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select>
        </Field>
        <Field label={t('day')}>
          <select className="select" value={form.day} onChange={(e) => setForm({ ...form, day: Number(e.target.value) })}>
            <option value={-1}>{t('every_day')}</option>
            {DAYS.map((d, i) => <option key={d} value={i}>{t('day_' + d)}</option>)}
          </select>
        </Field>
        <Field label={t('subject_optional')}><input className="input" value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} /></Field>
        <Field label={t('start')}><input className="input" placeholder="14:00" value={form.start} onChange={(e) => setForm({ ...form, start: fmtTime(e.target.value) })} /></Field>
        <Field label={t('end')}><input className="input" placeholder="16:00" value={form.end} onChange={(e) => setForm({ ...form, end: fmtTime(e.target.value) })} /></Field>
        <div className="field"><label>&nbsp;</label><button className="btn primary" disabled={!valid || busy} onClick={add}><IcPlus /> {t('add')}</button></div>
      </div>
      {error && <div className="error-box mt12">{msg(error)}</div>}
    </Modal>
  )
}

function CameraForm({ camera, classes, onClose, onSaved }: { camera: CameraDto | null; classes: ClassDto[]; onClose: () => void; onSaved: () => void }) {
  const { t } = useT()
  const msg = useErrorMessage()
  const [form, setForm] = useState({ name: camera?.name ?? '', rtsp_url: camera?.rtsp_url ?? '', ip_address: camera?.ip_address ?? '', class_id: camera?.class_id ?? null as number | null, is_active: camera?.is_active ?? true })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  async function save() {
    if (busy || !form.name.trim()) return
    setBusy(true); setError(null)
    const body = { name: form.name.trim(), rtsp_url: form.rtsp_url.trim() || null, ip_address: form.ip_address.trim() || null, class_id: form.class_id, is_active: form.is_active }
    try { if (camera) await director.updateCamera(camera.id, body); else await director.createCamera(body); onSaved() } catch (e) { setError(errorText(e)) } finally { setBusy(false) }
  }
  return (
    <Modal title={camera ? t('edit_camera') : t('add_camera')} onClose={onClose} actions={<>
      <button className="btn ghost" onClick={onClose}>{t('cancel')}</button>
      <button className="btn primary" disabled={busy || !form.name.trim()} onClick={save}>{t('save')}</button>
    </>}>
      <div className="col" style={{ gap: 12 }}>
        <Field label={t('name')}><input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} autoFocus placeholder="Room 3" /></Field>
        <Field label="RTSP URL"><input className="input" value={form.rtsp_url} onChange={(e) => setForm({ ...form, rtsp_url: e.target.value })} placeholder="rtsp://user:pass@192.168.0.50:554/stream" /></Field>
        <Field label={t('ip_optional')}><input className="input" value={form.ip_address} onChange={(e) => setForm({ ...form, ip_address: e.target.value })} /></Field>
        <Field label={t('default_class')}>
          <select className="select" value={form.class_id ?? ''} onChange={(e) => setForm({ ...form, class_id: e.target.value ? Number(e.target.value) : null })}>
            <option value="">—</option>
            {classes.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </Field>
        {error && <div className="error-box">{msg(error)}</div>}
      </div>
    </Modal>
  )
}
