import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { director } from '../../api/endpoints'
import { useT } from '../../i18n'
import { Avatar, ErrorBox, fmtAvg, Grade, gradeClass, Skeleton, useAsync, useFmt } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function StudentPage() {
  const { t } = useT()
  const f = useFmt()
  const nav = useNavigate()
  const id = Number(useParams().id)
  const [quarter, setQuarter] = useState<number | null>(null)
  const a = useAsync(() => director.studentAnalytics(id, quarter), [id, quarter])
  const students = useAsync(() => director.students(), [])
  const me = students.data?.find((s) => s.id === id)
  const grades = useAsync(async () => (me?.class_id ? (await director.grades(me.class_id)).filter((g) => g.student_id === id) : []), [me?.class_id, id])
  const d = a.data

  return (
    <>
      <TopBar title={d ? `${d.last_name} ${d.first_name}` : me ? `${me.last_name} ${me.first_name}` : '…'} sub={me?.class_name ?? ''} back={() => nav(-1)}>
        <div className="seg">
          {[null, 1, 2, 3, 4].map((q) => <button key={String(q)} className={quarter === q ? 'active' : ''} onClick={() => setQuarter(q)}>{q == null ? t('current') : `${q} ${t('quarter_short')}`}</button>)}
        </div>
      </TopBar>
      <ErrorBox error={a.error} onRetry={a.reload} />
      {a.loading && !d && <Skeleton rows={4} h={90} />}
      {d && (
        <>
          <div className="hero mb24">
            <div className="row" style={{ gap: 18 }}>
              <div className="avatar lg" style={{ background: 'rgba(255,255,255,.2)' }}>{d.last_name[0]}{d.first_name[0]}</div>
              <div className="grow">
                <h2>{d.last_name} {d.first_name}</h2>
                <p>{t('quarter_n', d.quarter)}{d.school_year ? ` · ${d.school_year}` : ''}</p>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: 44, fontWeight: 800, letterSpacing: -1, lineHeight: 1 }}>{fmtAvg(d.overall_average)}</div>
                <div className="small" style={{ opacity: .8 }}>{t('overall_average')}</div>
              </div>
            </div>
          </div>
          <div className="grid c3 mb24">
            <Rank label={t('rank_class')} pos={d.class_rank.position} of={d.class_rank.out_of} avg={d.class_average} t={t} />
            <Rank label={t('rank_parallel')} pos={d.parallel_rank.position} of={d.parallel_rank.out_of} avg={d.parallel_average} t={t} />
            <Rank label={t('rank_school')} pos={d.school_rank.position} of={d.school_rank.out_of} avg={d.school_average} t={t} />
          </div>
          <div className="grid c2">
            <div className="card">
              <div className="card-title">{t('by_subject')}</div>
              {d.subject_breakdown.length === 0 && <div className="muted small">{t('no_marks_yet')}</div>}
              <div className="col">
                {d.subject_breakdown.map((s) => (
                  <div key={s.subject} className="row">
                    <div className="small bold" style={{ width: 140 }}>{s.subject}{s.subject === d.strongest_subject && ' 🏆'}{s.subject === d.weakest_subject && ' ⚠️'}</div>
                    <div className="bar grow"><i style={{ width: `${(s.average / 10) * 100}%`, background: s.average >= 8 ? 'var(--mint)' : s.average >= 6 ? 'var(--amber)' : 'var(--rose)' }} /></div>
                    <Grade v={s.average} />
                    <span className="tiny faint" style={{ width: 40 }}>{s.grade_count}×</span>
                  </div>
                ))}
              </div>
              {d.lesson_attendance_rate != null && (
                <div className="row mt16">
                  <div className="small bold grow">{t('attendance_rate')}</div>
                  <span className={'chip ' + (d.lesson_attendance_rate >= 0.9 ? 'mint' : d.lesson_attendance_rate >= 0.75 ? 'amber' : 'rose')}>{Math.round(d.lesson_attendance_rate * 100)}%</span>
                </div>
              )}
            </div>
            <div className="card">
              <div className="card-title">{t('recent_marks')}</div>
              {grades.data?.length === 0 && <div className="muted small">{t('no_marks_yet')}</div>}
              <div className="col" style={{ gap: 6 }}>
                {grades.data?.slice(0, 20).map((g) => (
                  <div key={g.id} className="row">
                    <Grade v={g.value} />
                    <div className="grow">
                      <div className="small bold">{g.subject}</div>
                      <div className="tiny faint">{f.date(g.grade_date)}{g.teacher_name ? ` · ${g.teacher_name}` : ''}{g.comment ? ` · ${g.comment}` : ''}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </>
      )}
    </>
  )
}

function Rank({ label, pos, of, avg, t }: { label: string; pos?: number | null; of: number; avg?: number | null; t: (k: string) => string }) {
  return (
    <div className="card tight">
      <div className="stat">
        <div className="stat-ic" style={{ background: 'var(--brand-tint)', color: 'var(--brand)', fontWeight: 800, fontSize: 18 }}>{pos ?? '—'}</div>
        <div>
          <div className="stat-v" style={{ fontSize: 18 }}>{pos != null ? `${pos} / ${of}` : '—'}</div>
          <div className="stat-l">{label}{avg != null && <span className={'grade ' + gradeClass(avg)} style={{ marginLeft: 8, height: 22, minWidth: 30, fontSize: 11 }}>{t('avg_short')} {fmtAvg(avg)}</span>}</div>
        </div>
      </div>
    </div>
  )
}
