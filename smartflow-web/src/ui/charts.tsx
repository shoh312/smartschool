import { useEffect, useRef, useState, type ReactNode } from 'react'

/** Measures the container so a chart can fill the full available width (no empty side margins). */
function useWidth(fallback = 340) {
  const ref = useRef<HTMLDivElement>(null)
  const [w, setW] = useState(fallback)
  useEffect(() => {
    const el = ref.current
    if (!el || typeof ResizeObserver === 'undefined') return
    const ro = new ResizeObserver(() => setW(el.clientWidth || fallback))
    ro.observe(el); setW(el.clientWidth || fallback)
    return () => ro.disconnect()
  }, [fallback])
  return [ref, Math.max(240, w)] as const
}

/**
 * Small, dependency-free SVG charts drawn with the app's own colour tokens —
 * gridlines, axes, smooth curves, gradient fills and a donut with a legend, so
 * a dashboard reads like a real analytics board. Everything animates from zero
 * on mount. Colours come from CSS variables so light/dark and the brand stay
 * consistent.
 */

function useMounted(delay = 60) {
  const [on, setOn] = useState(false)
  useEffect(() => { const id = setTimeout(() => setOn(true), delay); return () => clearTimeout(id) }, [delay])
  return on
}

const fmt = (v: number) => (Number.isInteger(v) ? String(v) : v.toFixed(1))

/** Nice-ish tick values from 0..max in `steps` divisions. */
function ticks(max: number, steps = 4): number[] {
  const out: number[] = []
  for (let i = 0; i <= steps; i++) out.push((max / steps) * i)
  return out
}

// -------------------------------------------------------------- ring

/** A thick progress ring; `center` is the big label, `sub` the caption under it. */
export function Ring({ value, max = 100, size = 128, stroke = 14, color = 'var(--brand)', track = 'var(--surface-soft)', center, sub }: {
  value: number; max?: number; size?: number; stroke?: number; color?: string; track?: string; center?: ReactNode; sub?: string
}) {
  const on = useMounted()
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  const pct = Math.max(0, Math.min(1, max ? value / max : 0))
  return (
    <div className="ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round"
          strokeDasharray={c} strokeDashoffset={on ? c * (1 - pct) : c} transform={`rotate(-90 ${size / 2} ${size / 2})`}
          style={{ transition: 'stroke-dashoffset 1.1s cubic-bezier(.2,.8,.2,1)' }} />
      </svg>
      <div className="ring-mid">{center ?? <b>{Math.round(pct * 100)}%</b>}{sub && <span>{sub}</span>}</div>
    </div>
  )
}

// ------------------------------------------------------------- donut

/** A donut with a legend table beside it: each row shows colour, name, % and value. */
export function DonutChart({ segments, size = 172, stroke = 30, unit = '', title, total: totalLabel }: {
  segments: { label: string; value: number; color: string }[]
  size?: number; stroke?: number; unit?: string; title?: ReactNode; total?: ReactNode
}) {
  const on = useMounted()
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  const total = segments.reduce((s, x) => s + x.value, 0) || 1
  let acc = 0
  return (
    <div className="donut-wrap">
      <div className="ring" style={{ width: size, height: size }}>
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
          <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--surface-soft)" strokeWidth={stroke} />
          {segments.map((seg, i) => {
            const frac = seg.value / total
            const len = c * frac
            const gap = 2
            const dash = on ? `${Math.max(0, len - gap)} ${c - Math.max(0, len - gap)}` : `0 ${c}`
            const rot = (acc / total) * 360 - 90
            acc += seg.value
            return <circle key={i} cx={size / 2} cy={size / 2} r={r} fill="none" stroke={seg.color} strokeWidth={stroke}
              strokeDasharray={dash} strokeLinecap="round" transform={`rotate(${rot} ${size / 2} ${size / 2})`}
              style={{ transition: 'stroke-dasharray 1s cubic-bezier(.2,.8,.2,1)' }} />
          })}
        </svg>
        <div className="ring-mid">{title}{totalLabel && <span>{totalLabel}</span>}</div>
      </div>
      <div className="donut-legend">
        {segments.map((seg) => (
          <div key={seg.label} className="dl-row">
            <i style={{ background: seg.color }} />
            <span className="dl-name grow ellipsis">{seg.label}</span>
            <span className="dl-pct">{Math.round((seg.value / total) * 100)}%</span>
            <b className="dl-val">{fmt(seg.value)}{unit}</b>
          </div>
        ))}
      </div>
    </div>
  )
}

// -------------------------------------------------------------- bars

/** Vertical bars with gridlines and axes. Pass `stack` values for a two-tone stacked bar. */
export function BarChart({ data, max, unit = '', height = 200, color = 'var(--brand)', stackColor = 'var(--coral)' }: {
  data: { label: string; value: number; stack?: number }[]
  max?: number; unit?: string; height?: number; color?: string; stackColor?: string
}) {
  const on = useMounted()
  const [ref, W] = useWidth()
  const padL = 30, padB = 26, padT = 10
  const top = max ?? Math.max(1, ...data.map((d) => (d.value + (d.stack ?? 0))))
  const plotH = height - padB - padT
  const plotW = W - padL - 6
  const bw = Math.min(46, (plotW / data.length) * 0.62)
  const step = plotW / data.length
  const y = (v: number) => padT + plotH * (1 - v / top)
  return (
    <div ref={ref} style={{ width: '100%' }}>
    <svg viewBox={`0 0 ${W} ${height}`} width="100%" height={height} style={{ overflow: 'visible', display: 'block' }}>
      {ticks(top).map((tk, i) => (
        <g key={i}>
          <line x1={padL} y1={y(tk)} x2={W - 4} y2={y(tk)} stroke="var(--border)" strokeWidth={1} strokeDasharray={i === 0 ? '0' : '3 4'} />
          <text x={padL - 6} y={y(tk) + 3} textAnchor="end" fontSize="9.5" fill="var(--ink-3)" fontWeight="700">{fmt(tk)}</text>
        </g>
      ))}
      {data.map((d, i) => {
        const cx = padL + step * i + step / 2
        const base = d.stack != null ? d.stack : 0
        const total = d.value + base
        const yTotal = on ? y(total) : y(0)
        const yBase = on ? y(base) : y(0)
        return (
          <g key={d.label}>
            {/* main (or bottom of stack) */}
            <rect x={cx - bw / 2} y={d.stack != null ? yBase : yTotal} width={bw}
              height={Math.max(0, (d.stack != null ? y(0) - yBase : y(0) - yTotal))} rx={bw / 2.4}
              fill={d.stack != null ? stackColor : color} style={{ transition: 'all .9s cubic-bezier(.2,.8,.2,1)' }} />
            {/* top of stack */}
            {d.stack != null && (
              <rect x={cx - bw / 2} y={yTotal} width={bw} height={Math.max(0, yBase - yTotal)} rx={bw / 2.4}
                fill={color} style={{ transition: 'all .9s cubic-bezier(.2,.8,.2,1)' }} />
            )}
            <text x={cx} y={height - 8} textAnchor="middle" fontSize="9.5" fill="var(--ink-3)" fontWeight="700">{d.label}</text>
          </g>
        )
      })}
      {unit && <text x={padL - 6} y={padT - 1} textAnchor="end" fontSize="9" fill="var(--ink-3)">{unit}</text>}
    </svg>
    </div>
  )
}

// ------------------------------------------------------------- area

function smoothPath(pts: { x: number; y: number }[]): string {
  if (pts.length < 2) return pts.length ? `M ${pts[0].x},${pts[0].y}` : ''
  let d = `M ${pts[0].x},${pts[0].y}`
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2
    const cp1x = p1.x + (p2.x - p0.x) / 6, cp1y = p1.y + (p2.y - p0.y) / 6
    const cp2x = p2.x - (p3.x - p1.x) / 6, cp2y = p2.y - (p3.y - p1.y) / 6
    d += ` C ${cp1x},${cp1y} ${cp2x},${cp2y} ${p2.x},${p2.y}`
  }
  return d
}

/** Smooth area chart with gridlines, axis labels and a highlighted last point. */
export function AreaChart({ points, max = 10, height = 200, color = 'var(--brand)', unit = '', highlight }: {
  points: { label: string; value: number | null }[]
  max?: number; height?: number; color?: string; unit?: string; highlight?: number
}) {
  const on = useMounted()
  const [ref, W] = useWidth()
  const padL = 30, padB = 26, padT = 12
  const plotH = height - padB - padT
  const plotW = W - padL - 8
  const hi = highlight ?? points.length - 1
  const xs = points.map((_, i) => padL + (i * plotW) / Math.max(1, points.length - 1))
  const ys = points.map((p) => padT + plotH * (1 - (p.value ?? 0) / max))
  const pts = xs.map((x, i) => ({ x, y: ys[i] }))
  const line = smoothPath(pts)
  const area = `${line} L ${xs[xs.length - 1]},${padT + plotH} L ${xs[0]},${padT + plotH} Z`
  const id = 'ag' + Math.round(max * 97)
  return (
    <div ref={ref} style={{ width: '100%' }}>
    <svg viewBox={`0 0 ${W} ${height}`} width="100%" height={height} style={{ overflow: 'visible', display: 'block' }}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.22" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      {ticks(max).map((tk, i) => (
        <g key={i}>
          <line x1={padL} y1={padT + plotH * (1 - tk / max)} x2={W - 4} y2={padT + plotH * (1 - tk / max)}
            stroke="var(--border)" strokeWidth={1} strokeDasharray={i === 0 ? '0' : '3 4'} />
          <text x={padL - 6} y={padT + plotH * (1 - tk / max) + 3} textAnchor="end" fontSize="9.5" fill="var(--ink-3)" fontWeight="700">{fmt(tk)}</text>
        </g>
      ))}
      <path d={area} fill={`url(#${id})`} opacity={on ? 1 : 0} style={{ transition: 'opacity 1s' }} />
      <path d={line} fill="none" stroke={color} strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round"
        style={{ strokeDasharray: 1200, strokeDashoffset: on ? 0 : 1200, transition: 'stroke-dashoffset 1.2s ease' }} />
      {pts.map((p, i) => (
        <g key={i}>
          {i === hi && <line x1={p.x} y1={p.y} x2={p.x} y2={padT + plotH} stroke={color} strokeWidth={1} strokeDasharray="3 3" opacity={on ? 0.5 : 0} />}
          <circle cx={p.x} cy={p.y} r={i === hi ? 5.5 : 3.5} fill={i === hi ? color : '#fff'} stroke={color} strokeWidth={2.4}
            opacity={on ? 1 : 0} style={{ transition: `opacity .4s ${0.5 + i * 0.08}s` }} />
          <text x={p.x} y={height - 8} textAnchor="middle" fontSize="9.5" fill="var(--ink-3)" fontWeight="700">{points[i].label}</text>
          {i === hi && points[i].value != null && (
            <g opacity={on ? 1 : 0} style={{ transition: 'opacity .5s .8s' }}>
              <rect x={p.x - 20} y={p.y - 26} width={40} height={18} rx={6} fill="var(--ink)" />
              <text x={p.x} y={p.y - 13} textAnchor="middle" fontSize="10" fill="#fff" fontWeight="800">{fmt(points[i].value!)}{unit}</text>
            </g>
          )}
        </g>
      ))}
    </svg>
    </div>
  )
}

// -------------------------------------------------------- line chart

/**
 * A multi-series line chart with gridlines, a full x-axis, a soft area under
 * the first series, and a highlighted point with a tooltip — the "distribution"
 * look. Each series is a run of values aligned to `labels`; a dashed series
 * reads as the comparison line.
 */
export function LineChart({ series, labels, max, height = 210, unit = '', highlight, everyLabel }: {
  series: { label: string; color: string; dashed?: boolean; values: (number | null)[] }[]
  labels: string[]; max?: number; height?: number; unit?: string; highlight?: number; everyLabel?: number
}) {
  const on = useMounted()
  const [ref, W] = useWidth()
  const padL = 34, padB = 26, padT = 14
  const plotH = height - padB - padT
  const plotW = W - padL - 10
  const n = labels.length
  const top = max ?? Math.max(1, ...series.flatMap((s) => s.values.map((v) => v ?? 0)))
  const x = (i: number) => padL + (i * plotW) / Math.max(1, n - 1)
  const y = (v: number) => padT + plotH * (1 - v / top)
  const hi = highlight ?? n - 1
  const step = everyLabel ?? Math.ceil(n / 7)
  const id = 'lg' + Math.round(top * 13 + n)
  const primary = series[0]
  return (
    <div ref={ref} style={{ width: '100%' }}>
    <svg viewBox={`0 0 ${W} ${height}`} width="100%" height={height} style={{ overflow: 'visible', display: 'block' }}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={primary.color} stopOpacity="0.18" />
          <stop offset="100%" stopColor={primary.color} stopOpacity="0" />
        </linearGradient>
      </defs>
      {ticks(top).map((tk, i) => (
        <g key={i}>
          <line x1={padL} y1={y(tk)} x2={W - 4} y2={y(tk)} stroke="var(--border)" strokeWidth={1} strokeDasharray={i === 0 ? '0' : '3 4'} />
          <text x={padL - 6} y={y(tk) + 3} textAnchor="end" fontSize="9" fill="var(--ink-3)" fontWeight="700">{fmt(tk)}{unit}</text>
        </g>
      ))}
      {series.map((s, si) => {
        const pts = s.values.map((v, i) => ({ x: x(i), y: y(v ?? 0) }))
        const line = smoothPath(pts)
        return (
          <g key={si}>
            {si === 0 && <path d={`${line} L ${x(n - 1)},${padT + plotH} L ${x(0)},${padT + plotH} Z`} fill={`url(#${id})`} opacity={on ? 1 : 0} style={{ transition: 'opacity 1s' }} />}
            <path d={line} fill="none" stroke={s.color} strokeWidth={s.dashed ? 2 : 2.8} strokeLinecap="round" strokeLinejoin="round"
              strokeDasharray={s.dashed ? '5 5' : undefined} opacity={s.dashed ? 0.7 : 1}
              style={{ strokeDasharray: s.dashed ? '5 5' : 1400, strokeDashoffset: on ? 0 : (s.dashed ? 0 : 1400), transition: 'stroke-dashoffset 1.3s ease', opacity: on ? (s.dashed ? 0.7 : 1) : 0 }} />
          </g>
        )
      })}
      {/* highlight on the primary series */}
      {primary.values[hi] != null && (
        <g opacity={on ? 1 : 0} style={{ transition: 'opacity .5s .8s' }}>
          <line x1={x(hi)} y1={y(primary.values[hi]!)} x2={x(hi)} y2={padT + plotH} stroke={primary.color} strokeWidth={1} strokeDasharray="3 3" opacity={0.5} />
          <circle cx={x(hi)} cy={y(primary.values[hi]!)} r={5.5} fill={primary.color} stroke="#fff" strokeWidth={2.5} />
          <g>
            <rect x={x(hi) - 24} y={y(primary.values[hi]!) - 27} width={48} height={19} rx={6} fill="var(--ink)" />
            <text x={x(hi)} y={y(primary.values[hi]!) - 14} textAnchor="middle" fontSize="10" fill="#fff" fontWeight="800">{fmt(primary.values[hi]!)}{unit}</text>
          </g>
        </g>
      )}
      {labels.map((lb, i) => ((i % step === 0 || i === n - 1) &&
        <text key={i} x={x(i)} y={height - 8} textAnchor="middle" fontSize="9" fill="var(--ink-3)" fontWeight="700">{lb}</text>
      ))}
    </svg>
    </div>
  )
}

// -------------------------------------------------------------- delta

/** A small up/down change badge, green for a rise, rose for a fall. */
export function Delta({ value, unit = '' }: { value: number; unit?: string }) {
  const up = value >= 0
  return (
    <span className={'delta ' + (up ? 'up' : 'down')}>
      <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
        {up ? <path d="M6 15l6-6 6 6" /> : <path d="M6 9l6 6 6-6" />}
      </svg>
      {up ? '+' : ''}{fmt(value)}{unit}
    </span>
  )
}
