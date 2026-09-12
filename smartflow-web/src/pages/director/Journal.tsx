import { useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { director } from '../../api/endpoints'
import { useT } from '../../i18n'
import { JournalGrid, JournalStats } from '../../ui/JournalGrid'
import { ErrorBox, Skeleton, useAsync } from '../../ui/kit'
import { TopBar } from '../../ui/Shell'

export function Journal() {
  const { t } = useT()
  const nav = useNavigate()
  const id = Number(useParams().id)
  const classes = useAsync(() => director.classes(), [])
  const students = useAsync(() => director.students(), [])
  const grades = useAsync(() => director.grades(id), [id])
  const absences = useAsync(() => director.absences(id).catch(() => []), [id])
  const taught = useAsync(() => director.classSubjects(id).catch(() => []), [id])
  const [subject, setSubject] = useState<string | null>(null)

  const cls = classes.data?.find((c) => c.id === id)
  const pupils = (students.data ?? []).filter((s) => s.class_id === id).sort((a, b) => a.last_name.localeCompare(b.last_name))
  const subjects = useMemo(() => {
    const withMarks = [...new Set((grades.data ?? []).map((g) => g.subject))]
    const rest = [...new Set([...(absences.data ?? []).map((a) => a.subject), ...(taught.data ?? []).map((s) => s.subject).filter((s): s is string => !!s)])].filter((s) => !withMarks.includes(s)).sort()
    return [...withMarks, ...rest]
  }, [grades.data, absences.data, taught.data])
  const current = subject ?? subjects[0] ?? null
  const g = (grades.data ?? []).filter((x) => x.subject === current)
  const a = (absences.data ?? []).filter((x) => x.subject === current)

  return (
    <>
      <TopBar title={t('journal')} sub={cls?.name} back={() => nav(`/classes/${id}`)} />
      <ErrorBox error={grades.error} onRetry={grades.reload} />
      {grades.loading && !grades.data && <Skeleton rows={6} h={48} />}
      {grades.data && (
        <>
          <div className="tabs mb16">
            {subjects.map((s) => <button key={s} className={'tab' + (s === current ? ' active' : '')} onClick={() => setSubject(s)}>{s}</button>)}
          </div>
          <JournalStats grades={g} absences={a.length} pupils={pupils} />
          <div className="mb16" />
          <JournalGrid pupils={pupils} grades={g} absences={a} onName={(s) => nav(`/students/${s.id}`)} />
        </>
      )}
    </>
  )
}
