import { useMemo } from 'react'
import type { AbsenceDto, GradeDto, StudentDto } from '../api/types'
import { useT } from '../i18n'
import { Avatar, fmtAvg, gradeClass, todayIso, useFmt } from './kit'

export interface CellInfo { student: StudentDto; date: string; grades: GradeDto[]; absent: boolean }

/**
 * The register as a grid: pupils down, lesson dates across, sticky name and
 * average columns. Read-only for a director; a teacher gets clickable cells.
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

  if (dates.length === 0 || pupils.length === 0) return <div className="empty"><div className="ill">📓</div><h3>{t('no_marks_yet')}</h3><p className="small">{t('journal_empty_body')}</p></div>

  return (
    <div className="journal card" style={{ padding: 0, maxHeight: 'calc(100vh - 260px)' }}>
      <table>
        <thead>
          <tr>
            <th className="name">{t('pupils')}</th>
            {dates.map((d) => (
              <th key={d} className={d === today ? 'today' : ''}>
                <div>{f.ddmm(d)}</div>
                <div className="tiny faint" style={{ fontWeight: 600 }}>{f.weekday(d)}</div>
              </th>
            ))}
            <th className="avg">{t('avg_short')}</th>
          </tr>
        </thead>
        <tbody>
          {pupils.map((p) => {
            const own = byStudent.get(p.id)
            const all = own ? [...own.values()].flat() : []
            const avg = all.length ? all.reduce((s, g) => s + g.value, 0) / all.length : null
            return (
              <tr key={p.id}>
                <td className="name">
                  <div className="row" style={{ cursor: onName ? 'pointer' : 'default' }} onClick={() => onName?.(p)}>
                    <Avatar first={p.first_name} last={p.last_name} id={p.id} size="sm" />
                    <div className="grow ellipsis">
                      <div className="bold small ellipsis">{p.last_name} {p.first_name}</div>
                    </div>
                  </div>
                </td>
                {dates.map((d) => {
                  const gs = own?.get(d) ?? []
                  const ab = absent.has(`${p.id}|${d}`)
                  const info: CellInfo = { student: p, date: d, grades: gs, absent: ab }
                  const click = editable && d === today ? () => onCell?.(info) : undefined
                  let cls = 'cell'
                  let text: string = ''
                  if (gs.length) { cls += ' ' + gradeClass(gs[0].value); text = gs.map((g) => g.value).join('/') }
                  else if (ab) { cls += ' absent'; text = t('absent_short') }
                  else cls += ' blank' + (click ? ' today-empty' : '')
                  if (click) cls += ' editable'
                  return (
                    <td key={d}>
                      <div className={cls} style={ab && gs.length ? { boxShadow: 'inset 0 0 0 1.5px var(--rose)' } : undefined} onClick={click} title={gs.map((g) => g.comment).filter(Boolean).join('\n') || undefined}>{text}</div>
                    </td>
                  )
                })}
                <td className="avg"><span className={'grade ' + gradeClass(avg)}>{fmtAvg(avg)}</span></td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
