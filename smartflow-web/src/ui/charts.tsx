import { useEffect, useState, type ReactNode } from 'react'

/**
 * Small, dependency-free SVG charts drawn with the app's own colour tokens.
 * Everything animates from zero on mount, so a dashboard feels alive the
 * moment it opens. Colours come from CSS variables (var(--brand), --mint …),
 * so light and dark themes and the brand stay consistent.
 */

function useMounted(delay = 60) {
  const [on, setOn] = useState(false)
  useEffect(() => { const id = setTimeout(() => setOn(true), delay); return () => clearTimeout(id) }, [delay])
  return on
}

/** A ring that fills to `value`/`max`. `label` sits under the big number in the middle. */
export function Ring({ value, max = 100, size = 120, stroke = 12, color = 'var(--brand)', track = 'var(--surface-soft)', center, sub }: {
  value: number; max?: number; size?: number; stroke?: number; color?: string; track?: string; center?: ReactNode; sub?: string
}) {
  const on = useMounted()
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  const pct = Math.max(0, Math.min(1, max ? value / max : 0))
  const off = on ? c * (1 - pct) : c
  return (
    <div className="ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round"
          strokeDasharray={c} strokeDashoffset={off} transform={`rotate(-90 ${size / 2} ${size / 2})`}
          style={{ transition: 'stroke-dashoffset 1s cubic-bezier(.2,.8,.2,1)' }} />
      </svg>
      <div className="ring-mid">{center ?? <b>{Math.round(pct * 100)}%</b>}{sub && <span>{sub}</span>}</div>
    </div>
  )
}

/** A part-of-whole donut: segments in order, each {value, color}. */
export function Donut({ segments, size = 120, stroke = 16, center, sub }: {
  segments: { value: number; color: string }[]; size?: number; stroke?: number; center?: ReactNode; sub?: string
}) {
  const on = useMounted()
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  const total = segments.reduce((s, x) => s + x.value, 0) || 1
  let acc = 0
  return (
    <div className="ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--surface-soft)" strokeWidth={stroke} />
        {segments.map((seg, i) => {
          const frac = seg.value / total
          const len = c * frac
          const dash = on ? `${len} ${c - len}` : `0 ${c}`
          const rot = (acc / total) * 360 - 90
          acc += seg.value
          return <circle key={i} cx={size / 2} cy={size / 2} r={r} fill="none" stroke={seg.color} strokeWidth={stroke}
            strokeDasharray={dash} transform={`rotate(${rot} ${size / 2} ${size / 2})`}
            style={{ transition: 'stroke-dasharray 1s cubic-bezier(.2,.8,.2,1)' }} />
        })}
      </svg>
      <div className="ring-mid">{center}{sub && <span>{sub}</span>}</div>
    </div>
  )
}

/** Labelled horizontal bars, each 0..max, animated to width. */
export function Bars({ data, max, unit = '' }: { data: { label: string; value: number; color?: string }[]; max?: number; unit?: string }) {
  const on = useMounted()
  const top = max ?? Math.max(1, ...data.map((d) => d.value))
  return (
    <div className="col" style={{ gap: 10 }}>
      {data.map((d) => (
        <div key={d.label} className="row" style={{ gap: 10 }}>
          <span className="small grow ellipsis" style={{ maxWidth: 130 }}>{d.label}</span>
          <span className="bar" style={{ flex: 1 }}>
            <span style={{ width: on ? `${(d.value / top) * 100}%` : 0, background: d.color ?? 'var(--brand)', transition: 'width .9s cubic-bezier(.2,.8,.2,1)' }} />
          </span>
          <b className="small" style={{ width: 40, textAlign: 'right' }}>{d.value.toFixed(1)}{unit}</b>
        </div>
      ))}
    </div>
  )
}

/** A trend line over labelled points (e.g. quarters), with a soft area fill. */
export function TrendLine({ points, height = 120, color = 'var(--brand)', max = 10 }: {
  points: { label: string; value: number | null }[]; height?: number; color?: string; max?: number
}) {
  const on = useMounted()
  const w = 300
  const pad = 16
  const pts = points.map((p, i) => {
    const x = pad + (i * (w - 2 * pad)) / Math.max(1, points.length - 1)
    const y = height - pad - ((p.value ?? 0) / max) * (height - 2 * pad)
    return { x, y, ...p }
  })
  const line = pts.map((p) => `${p.x},${p.y}`).join(' ')
  const area = `${pad},${height - pad} ${line} ${w - pad},${height - pad}`
  return (
    <svg viewBox={`0 0 ${w} ${height}`} width="100%" height={height} preserveAspectRatio="none" style={{ overflow: 'visible' }}>
      <polygon points={area} fill={color} opacity={on ? 0.1 : 0} style={{ transition: 'opacity .9s' }} />
      <polyline points={line} fill="none" stroke={color} strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round"
        style={{ strokeDasharray: 1000, strokeDashoffset: on ? 0 : 1000, transition: 'stroke-dashoffset 1.1s ease' }} />
      {pts.map((p, i) => (
        <g key={i}>
          <circle cx={p.x} cy={p.y} r={4} fill="#fff" stroke={color} strokeWidth={2.5} opacity={on ? 1 : 0} style={{ transition: `opacity .4s ${0.6 + i * 0.1}s` }} />
          <text x={p.x} y={height - 3} textAnchor="middle" fontSize="10" fill="var(--ink-3)" fontWeight="700">{p.label}</text>
        </g>
      ))}
    </svg>
  )
}
