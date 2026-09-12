import { useMemo } from 'react'
import type { AbsenceDto, GradeDto, StudentDto } from '../api/types'
import { useT } from '../i18n'
import { Ill } from './illustrations'
import { addDays, Avatar, fmtAvg, gradeClass, todayIso, useFmt } from './kit'

export interface CellInfo { student: StudentDto; date: string; grades: GradeDto[]; absent: boolean }

/**
 * The register as a grid: pupils down, lesson dates across. The name and
 * average columns stay put while the dates scroll; the grid always fills its
 * card. Read-only for a director; a teacher gets clickable cells for today.
 */
export function JournalGrid({ pupils, grades, absences, editable, onCell, onName }: {
  pupils: StudentDto[]
  grades: GradeDto[]
  absences: AbsenceDto[]
  editable?: boolean
  onCell?: (c: CellInfo) => void
  onName?: (s: StudentDto) => void
}) {
  const { t } = useT()
  const f = useFmt()
  const today = todayIso()
  const dates = useMemo(() => {
    const set = new Set<string>([...grades.map((g) => g.grade_date), ...absences.map((a) => a.date)])
    if (editable) set.add(today)
    return [...set].sort()
  }, [grades, absences, editable, today])
  const byStudent = useMemo(() => {
    const m = new Map<number, Map<string, GradeDto[]>>()
    for (const g of grades) {
      if (!m.has(g.student_id)) m.set(g.student_id, new Map())
      const d = m.get(g.student_id)!
      d.set(g.grade_date, [...(d.get(g.grade_date) ?? []), g])
    }
    return m
  }, [grades])
  const absent = useMemo(() => new Set(absences.map((a) => `${a.student_id}|${a.date}`)), [absences])
  const cutoff = addDays(today, -14)

  if (dates.length === 0 || pupils.length === 0) return <div className="empty"><div className="ill"><Ill name="notebook" size={150} /></div><h3>{t('no_marks_yet')}</h3><p className="small">{t('journal_empty_body')}</p></div>

  return (
    <div className="journal-wrap">
      <div className="journal">
        <table>
          <thead>
            <tr>
              <th className="name"><span>{t('pupils')}</span><span className="th-sub">{t('pupils_n', pupils.length)}</span></th>
              {dates.map((d) => {
                const wd = new Date(d + 'T00:00:00').getDay()
                return (
                  <th key={d} className={(d === today ? 'today' : '') + (wd === 0 || wd === 6 ? ' weekend' : '')}>
                    <div className="th-d">{f.ddmm(d)}</div>
                    <div className="th-w">{f.weekday(d)}</div>
                  </th>
                )
              })}
              <th className="avg"><span>{t('avg_short')}</span><span className="th-sub">{t('trend')}</span></th>
            </tr>
          </thead>
          <tbody>
            {pupils.map((p) => {
              const own = byStudent.get(p.id)
              const all = own ? [...own.values()].flat() : []
              const avg = all.length ? all.reduce((s, g) => s + g.value, 0) / all.length : null
              const recent = all.filter((g) => g.grade_date >= cutoff), earlier = all.filter((g) => g.grade_date < cutoff)
              const trend = recent.length && earlier.length ? recent.reduce((s, g) => s + g.value, 0) / recent.length - earlier.reduce((s, g) => s + g.value, 0) / earlier.length : 0
              const abs = absences.filter((a) => a.student_id === p.id).length
              return (
                <tr key={p.id}>
                  <td className="name">
                    <div className="pupil" style={{ cursor: onName ? 'pointer' : 'default' }} onClick={() => onName?.(p)}>
                      <Avatar first={p.first_name} last={p.last_name} id={p.id} size="sm" />
                      <div className="grow ellipsis">
                        <div className="bold small ellipsis">{p.last_name} {p.first_name}</div>
                        <div className="tiny faint">{t('marks_n', all.length)}{abs ? ` · ${t('absences_n', abs)}` : ''}</div>
                      </div>
                    </div>
                  </td>
                  {dates.map((d) => {
                    const gs = own?.get(d) ?? []
                    const ab = absent.has(`${p.id}|${d}`)
                    const info: CellInfo = { student: p, date: d, grades: gs, absent: ab }
                    const click = editable && d === today ? () => onCell?.(info) : undefined
                    const comment = gs.map((g) => g.comment).filter(Boolean).join('\n')
                    let cls = 'cell'
                    let text = ''
                    if (gs.length) { cls += ' ' + gradeClass(gs[0].value); text = gs.map((g) => g.value).join('/') }
                    else if (ab) { cls += ' absent'; text = t('absent_short') }
                    else cls += ' blank' + (click ? ' today-empty' : '')
                    if (click) cls += ' editable'
                    if (ab && gs.length) cls += ' late'
                    return (
                      <td key={d} className={d === today ? 'today' : ''}>
                        <div className={cls} onClick={click} title={comment || (ab ? t('absent_from_lesson') : undefined)}>
                          {text}
                          {comment && <i className="note" />}
                        </div>
                      </td>
                    )
                  })}
                  <td className="avg">
                    <div className="avg-box">
                      <span className={'grade ' + gradeClass(avg)}>{fmtAvg(avg)}</span>
                      {Math.abs(trend) >= 0.3 && <span className={'trend ' + (trend > 0 ? 'up' : 'down')}>{trend > 0 ? '▲' : '▼'} {Math.abs(trend).toFixed(1)}</span>}
                    </div>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
      <div className="legend">
        <span><i className="sw g-hi" /> 8–10</span>
        <span><i className="sw g-mid" /> 6–7</span>
        <span><i className="sw g-lo" /> 1–5</span>
        <span><i className="sw absent">{t('absent_short')}</i> {t('absent_from_lesson')}</span>
        <span><i className="sw note-sw" /> {t('has_comment')}</span>
        {editable && <span><i className="sw today-sw" /> {t('today_click')}</span>}
      </div>
    </div>
  )
}

/** Four cards above the grid: average, marks, absences, best pupil. */
export function JournalStats({ grades, absences, pupils }: { grades: GradeDto[]; absences: number; pupils: StudentDto[] }) {
  const { t } = useT()
  const avg = grades.length ? grades.reduce((s, g) => s + g.value, 0) / grades.length : null
  const byPupil = new Map<number, number[]>()
  for (const g of grades) byPupil.set(g.student_id, [...(byPupil.get(g.student_id) ?? []), g.value])
  let best: { s: StudentDto; a: number } | null = null
  for (const p of pupils) { const v = byPupil.get(p.id); if (v && v.length >= 2) { const a = v.reduce((x, y) => x + y, 0) / v.length; if (!best || a > best.a) best = { s: p, a } } }
  const cls = gradeClass(avg)
  const tone = cls === 'g-hi' ? 'mint' : cls === 'g-mid' ? 'amber' : cls === 'g-lo' ? 'rose' : 'brand'
  return (
    <div className="jstat">
      <div className="card"><span className="ic" style={{ background: `var(--${tone}-soft)`, color: `var(--${tone})` }}>📊</span><div><div className="v" style={{ color: avg == null ? 'var(--ink-3)' : `var(--${tone})` }}>{fmtAvg(avg)}</div><div className="l">{t('average')}</div></div></div>
      <div className="card"><span className="ic" style={{ background: 'var(--brand-soft)' }}>📝</span><div><div className="v">{grades.length}</div><div className="l">{t('marks_total')}</div></div></div>
      <div className="card"><span className="ic" style={{ background: 'var(--rose-soft)' }}>🚫</span><div><div className="v">{absences}</div><div className="l">{t('absences_total')}</div></div></div>
      <div className="card"><span className="ic" style={{ background: 'var(--amber-soft)' }}>🏆</span><div className="grow ellipsis"><div className="v ellipsis" style={{ fontSize: 15 }}>{best ? `${best.s.last_name} ${best.s.first_name}` : '—'}</div><div className="l">{t('best_pupil')}{best ? ` · ${fmtAvg(best.a)}` : ''}</div></div></div>
    </div>
  )
}
