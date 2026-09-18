// Demo mode: the whole API answered from memory, so the app can be shown
// (to a jury, a school, a parent) with no school server on. Everything a
// user does -- a mark, a material, a slot -- lands in this state and stays
// for the session; a reload starts the demo afresh.

import { addDays, todayIso } from '../ui/kit'
import type {
  AbsenceDto, AiGenerateResponse, AnalyticsDto, AnnouncementDto, AssignmentDto, AssignmentResultsDto, BlockDto, CalendarEventDto,
  CameraDto, CameraPositionDto, CameraStatusDto, ClassAssignmentDto, ClassDto, ClassSubjectAverageDto, ClassSubjectDto, DiaryEntryDto,
  GradeDto, LeaderboardEntryDto, LiveStatusDto, MaterialFullDto, MaterialSummaryDto, NeedsAttentionDto, SchoolSettingsDto, StudentDto, TeacherDto,
} from './types'

const DEMO_KEY = 'sf.demo'
export function isDemo(): boolean { try { return localStorage.getItem(DEMO_KEY) === '1' } catch { return false } }
export function setDemo(on: boolean) { try { on ? localStorage.setItem(DEMO_KEY, '1') : localStorage.removeItem(DEMO_KEY) } catch {} }

// ------------------------------------------------------------------ seed

let seed = 7
const rnd = () => { seed = (seed * 9301 + 49297) % 233280; return seed / 233280 }
const pick = <T,>(a: T[]) => a[Math.floor(rnd() * a.length)]
const today = todayIso()

const classes: ClassDto[] = [
  { id: 1, name: 'BackEnd #1', grade: null, start_time: '15:00', end_time: '16:30' },
  { id: 2, name: 'FrontEnd #2', grade: null, start_time: '17:00', end_time: '18:30' },
  { id: 3, name: 'Design #1', grade: null, start_time: '10:00', end_time: '11:30' },
]
const teachers: TeacherDto[] = [
  { id: 1, full_name: 'Раҳимова Нигина', email: 'n.rahimova@cict.tj', subject: 'BackEnd #1', is_active: true },
  { id: 2, full_name: 'Каримов Фаррух', email: 'f.karimov@cict.tj', subject: 'FrontEnd #2', is_active: true },
  { id: 3, full_name: 'Собирова Мадина', email: 'm.sobirova@cict.tj', subject: 'Design #1', is_active: true },
]
const subjectOf: Record<number, string> = { 1: 'BackEnd #1', 2: 'FrontEnd #2', 3: 'Design #1' }
const teacherOf: Record<number, number> = { 1: 1, 2: 2, 3: 3 }

const NAMES: [string, string][] = [
  ['Абдуллоев', 'Сарвар'], ['Орипов', 'Дамир'], ['Абдураҳимов', 'Толибҷон'], ['Собиров', 'Меҳроҷ'], ['Ҳалимов', 'Тавоно'], ['Валиева', 'Дилшода'],
  ['Қосимов', 'Муҳаммад'], ['Алиматов', 'Маҳмудҷон'], ['Назарова', 'Фарзона'], ['Раҷабов', 'Умед'], ['Юсупова', 'Мадина'], ['Шарипов', 'Ҷамшед'],
  ['Мирзоева', 'Нилуфар'], ['Саидов', 'Беҳрӯз'], ['Каримова', 'Сабрина'], ['Тоҳиров', 'Далер'], ['Исмоилова', 'Шаҳноза'], ['Ғафуров', 'Азиз'],
  ['Пӯлодова', 'Мунира'], ['Ҳакимов', 'Фирдавс'], ['Раҳмонова', 'Зарина'], ['Бобоев', 'Сино'], ['Давлатова', 'Лола'], ['Насриддинов', 'Комрон'],
]
const students: StudentDto[] = NAMES.map(([last, first], i) => {
  const cls = classes[i % 3]
  return { id: i + 1, class_id: cls.id, class_name: cls.name, first_name: first, last_name: last, parent_phone: `+992 9${String(1000000 + i * 37917).slice(0, 2)} ${String(100 + i * 7).slice(0, 3)} ${String(10 + i * 3).padStart(2, '0')} ${String(20 + i * 5).slice(-2)}`, parent_name: pick(['Фирӯза', 'Манижа', 'Гулнора', 'Шаҳло', 'Рустам', 'Ҷамшед']) + ' ' + last + (last.endsWith('а') ? '' : 'а'), username: `user${i + 1}`, is_active: true }
})

let nextId = 1000
const grades: GradeDto[] = []
const absences: AbsenceDto[] = []
for (let d = 27; d >= 0; d--) {
  const day = addDays(today, -d)
  const dow = new Date(day + 'T00:00:00').getDay()
  if (dow === 0) continue
  for (const s of students) {
    const cid = s.class_id!
    // each group has lessons on alternating days
    if ((cid + dow) % 2 === 0) continue
    const ability = 5.5 + (s.id % 5)      // pupils differ; some strong, some struggling
    if (rnd() < 0.08) { absences.push({ student_id: s.id, subject: subjectOf[cid], date: day, lesson_id: cid * 100 + d }); continue }
    if (rnd() < 0.45) grades.push({ id: nextId++, student_id: s.id, class_id: cid, subject: subjectOf[cid], value: Math.max(3, Math.min(10, Math.round(ability + (rnd() - 0.5) * 4))), grade_date: day, quarter: 1, teacher_name: teachers[teacherOf[cid] - 1].full_name, comment: rnd() < 0.12 ? pick(['Хуб кор кард', 'Вазифаро иҷро накард', 'Фаъол буд', 'Тест']) : null })
  }
}

const cameras: CameraDto[] = [
  { id: 1, class_id: 1, name: 'Room 1', rtsp_url: 'rtsp://192.168.0.50/stream', is_active: true },
  { id: 2, class_id: 2, name: 'Room 3', rtsp_url: 'rtsp://192.168.0.51/stream', is_active: true },
]
const positions: CameraPositionDto[] = [
  { id: 1, camera_id: 1, class_id: 1, class_name: 'BackEnd #1', subject: 'BackEnd #1', day_of_week: null, start_time: '15:00', end_time: '16:30' },
  { id: 2, camera_id: 1, class_id: 3, class_name: 'Design #1', subject: 'Design #1', day_of_week: null, start_time: '10:00', end_time: '11:30' },
  { id: 3, camera_id: 2, class_id: 2, class_name: 'FrontEnd #2', subject: 'FrontEnd #2', day_of_week: null, start_time: '17:00', end_time: '18:30' },
]
let settings: SchoolSettingsDto = { live_video_enabled: true, group_mode: true, sms_enabled: true, attendance_notifications_enabled: true, is_active: true }

const announcements: AnnouncementDto[] = [
  { id: 1, title: 'Имтиҳони ниҳоӣ — BackEnd #1', body: 'Рӯзи ҷумъа соати 15:00 имтиҳони лоиҳавӣ. Ноутбук ва зарядкаро фаромӯш накунед.', class_id: 1, created_at: addDays(today, -1) + 'T10:20:00' },
  { id: 2, title: 'Рӯзи кушода дар академия', body: 'Шанбеи оянда волидон метавонанд дарсҳоро бинанд ва бо муаллимон сӯҳбат кунанд. Оғоз — 11:00.', class_id: null, created_at: addDays(today, -4) + 'T09:00:00' },
  { id: 3, title: 'Ҷадвали нав аз душанбе', body: 'Гурӯҳи FrontEnd #2 аз ҳафтаи оянда соати 17:00 дарс мехонад.', class_id: 2, created_at: addDays(today, -9) + 'T16:45:00' },
]
const events: CalendarEventDto[] = [
  { id: 1, title: 'Имтиҳони BackEnd #1', event_type: 'exam', start_date: addDays(today, 3), class_id: 1 },
  { id: 2, title: 'Рӯзи кушода', event_type: 'event', start_date: addDays(today, 8), description: 'Барои волидон' },
  { id: 3, title: 'Маҷлиси муаллимон', event_type: 'meeting', start_date: addDays(today, 1) },
  { id: 4, title: 'Таътили тирамоҳӣ', event_type: 'holiday', start_date: addDays(today, 20), end_date: addDays(today, 26) },
  { id: 5, title: 'Ҳакатон', event_type: 'event', start_date: addDays(today, -6), description: '24 соат' },
]

const blocksPython: BlockDto[] = [
  { block_type: 'page', body: 'Рӯйхат (list) — сохтори додаҳои тағйирёбанда: [1, 2, 3]. Кортеж (tuple) — тағйирнопазир: (1, 2, 3).\n\nРӯйхат барои маҷмӯаҳое, ки илова ва нест кардан лозим аст; кортеж — барои додаҳои доимӣ, масалан координатҳо.', points: 0, position: 0 },
  { block_type: 'question', question_type: 'single', body: 'Кадом усул унсурро ба охири рӯйхат илова мекунад?', options: ['add()', 'append()', 'insert()', 'push()'], correct: { index: 1 }, points: 1, position: 1 },
  { block_type: 'question', question_type: 'truefalse', body: 'Кортежро пас аз эҷод тағйир додан мумкин аст.', correct: { value: false }, points: 1, position: 2 },
  { block_type: 'question', question_type: 'fill', body: 'Функсияе, ки дарозии рӯйхатро бармегардонад: ____()', correct: { answers: ['len'] }, points: 1, position: 3 },
  { block_type: 'question', question_type: 'match', body: 'Мувофиқ кунед', options: { left: ['list', 'tuple', 'dict'], right: ['{}', '[]', '()'] }, correct: { pairs: [[0, 1], [1, 2], [2, 0]] }, points: 2, position: 4 },
  { block_type: 'question', question_type: 'order', body: 'Қадамҳои коркарди рӯйхатро ба тартиб гузоред', options: ['чоп кардан', 'эҷод кардан', 'илова кардан'], correct: { order: [1, 2, 0] }, points: 2, position: 5 },
]
const materials: MaterialFullDto[] = [
  { id: 1, title: 'Python: рӯйхатҳо ва кортежҳо', description: 'Дарси кӯтоҳ ва тест барои санҷиши дониш.', subject: 'BackEnd #1', blocks: blocksPython },
  { id: 2, title: 'HTTP ва REST — асосҳо', description: 'Усулҳо, кодҳои ҷавоб, JSON.', subject: 'BackEnd #1', blocks: [
    { block_type: 'page', body: 'HTTP — протоколи мубодилаи маълумот байни клиент ва сервер. Усулҳои асосӣ: GET, POST, PUT, DELETE.', points: 0, position: 0 },
    { block_type: 'question', question_type: 'single', body: 'Кадом код маънои «ёфт нашуд»-ро дорад?', options: ['200', '301', '404', '500'], correct: { index: 2 }, points: 1, position: 1 },
    { block_type: 'question', question_type: 'single', body: 'Барои эҷоди захира кадом усул истифода мешавад?', options: ['GET', 'POST', 'HEAD', 'OPTIONS'], correct: { index: 1 }, points: 1, position: 2 },
    { block_type: 'question', question_type: 'truefalse', body: 'GET бояд ҳолати серверро тағйир диҳад.', correct: { value: false }, points: 1, position: 3 },
  ] },
]
const materialMeta: Record<number, { updated_at: string }> = { 1: { updated_at: addDays(today, -2) + 'T14:10:00' }, 2: { updated_at: addDays(today, -7) + 'T11:30:00' } }

interface DemoResult { student_id: number; score: number; percent: number; attempts: number; submitted_at: string; transferred: boolean }
const assignments: (AssignmentDto & { results: DemoResult[] })[] = []
function makeAssignment(materialId: number, classId: number, mode: string, publishedDaysAgo: number, dueAt: string | null, maxAttempts: number | null, fill: number): AssignmentDto & { results: DemoResult[] } {
  const m = materials.find((x) => x.id === materialId)!
  const qs = m.blocks.filter((b) => b.block_type === 'question')
  const max = qs.reduce((s, b) => s + b.points, 0)
  const roster = students.filter((s) => s.class_id === classId)
  const results: DemoResult[] = roster.filter(() => rnd() < fill).map((s) => { const score = Math.round(max * (0.4 + rnd() * 0.6)); return { student_id: s.id, score, percent: Math.round((score / max) * 100), attempts: 1 + Math.floor(rnd() * 2), submitted_at: addDays(today, -Math.floor(rnd() * publishedDaysAgo)) + 'T18:' + String(10 + Math.floor(rnd() * 49)) + ':00', transferred: false } })
  return { id: assignments.length + 1, material_id: materialId, material_title: m.title, subject: m.subject, class_id: classId, class_name: classes.find((c) => c.id === classId)!.name, mode, due_at: dueAt, max_attempts: maxAttempts, published_at: addDays(today, -publishedDaysAgo) + 'T12:00:00', grades_transferred_at: null, question_count: qs.length, max_score: max, student_count: roster.length, submitted_count: results.length, results_visible: mode === 'practice' || !dueAt || dueAt < today, results }
}
assignments.push(makeAssignment(1, 1, 'control', 5, addDays(today, -1) + 'T23:59:00', 1, 0.8))
assignments.push(makeAssignment(2, 1, 'practice', 2, null, null, 0.4))

const diary: Record<string, DiaryEntryDto[]> = {}
function diaryFor(classId: number, on: string): DiaryEntryDto[] {
  const key = `${classId}|${on}`
  if (!diary[key]) {
    const dow = new Date(on + 'T00:00:00').getDay()
    const cls = classes.find((c) => c.id === classId)!
    diary[key] = dow === 0 || (classId + dow) % 2 === 0 ? [] : [{ lesson_id: classId * 1000 + Number(on.replace(/-/g, '')) % 1000, subject: subjectOf[classId], start_time: cls.start_time!, duration_minutes: 90, room: `Room ${classId}`, teacher_id: teacherOf[classId], teacher_name: teachers[teacherOf[classId] - 1].full_name, homework: on < today ? pick(['Машқҳои 3–7 аз дафтар', 'Лоиҳаро ба GitHub гузоред', 'Маводи дарсро такрор кунед', null]) : null, teacher_comment: on < today && rnd() < 0.3 ? 'Гурӯҳ фаъол буд' : null }]
  }
  return diary[key]
}

// ------------------------------------------------------------ analytics

function avgOf(list: GradeDto[]): number | null { return list.length ? list.reduce((s, g) => s + g.value, 0) / list.length : null }
function ranking(filter: (s: StudentDto) => boolean): LeaderboardEntryDto[] {
  const rows = students.filter(filter).map((s) => ({ s, avg: avgOf(grades.filter((g) => g.student_id === s.id)) })).filter((r) => r.avg != null).sort((a, b) => b.avg! - a.avg!)
  return rows.map((r, i) => ({ student_id: r.s.id, first_name: r.s.first_name, last_name: r.s.last_name, class_id: r.s.class_id, class_name: r.s.class_name, overall_average: r.avg, position: i + 1, out_of: rows.length }))
}
function analytics(id: number): AnalyticsDto {
  const s = students.find((x) => x.id === id)!
  const own = grades.filter((g) => g.student_id === id)
  const bySubject = [...new Set(own.map((g) => g.subject))].map((sub) => { const l = own.filter((g) => g.subject === sub); return { subject: sub, average: avgOf(l)!, grade_count: l.length } }).sort((a, b) => b.average - a.average)
  const cls = ranking((x) => x.class_id === s.class_id), all = ranking(() => true)
  const lessons = grades.filter((g) => g.student_id === id).length + absences.filter((a) => a.student_id === id).length
  return { student_id: id, first_name: s.first_name, last_name: s.last_name, quarter: 1, school_year: 2026, overall_average: avgOf(own), class_rank: { position: cls.find((r) => r.student_id === id)?.position ?? null, out_of: cls.length }, parallel_rank: { position: cls.find((r) => r.student_id === id)?.position ?? null, out_of: cls.length }, school_rank: { position: all.find((r) => r.student_id === id)?.position ?? null, out_of: all.length }, class_average: avgOf(grades.filter((g) => g.class_id === s.class_id)), parallel_average: avgOf(grades.filter((g) => g.class_id === s.class_id)), school_average: avgOf(grades), subject_breakdown: bySubject, strongest_subject: bySubject[0]?.subject ?? null, weakest_subject: bySubject[bySubject.length - 1]?.subject ?? null, lesson_attendance_rate: lessons ? 1 - absences.filter((a) => a.student_id === id).length / lessons : null }
}
function needsAttention(): NeedsAttentionDto {
  const all = ranking(() => true)
  const decl = students.map((s) => { const own = grades.filter((g) => g.student_id === s.id); const recent = own.filter((g) => g.grade_date >= addDays(today, -10)), earlier = own.filter((g) => g.grade_date < addDays(today, -10)); const a = avgOf(recent), b = avgOf(earlier); return a != null && b != null ? { student_id: s.id, first_name: s.first_name, last_name: s.last_name, class_name: s.class_name, current_average: a, previous_average: b, delta: a - b } : null }).filter((x): x is NonNullable<typeof x> => !!x && x.delta < -0.5).sort((a, b) => a.delta - b.delta).slice(0, 5)
  return { bottom_performers: all.slice(-5).reverse(), biggest_decliners: decl }
}

// ------------------------------------------------------------- live state

function cameraStatus(): CameraStatusDto[] {
  const now = new Date(); const hm = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`
  return cameras.map((c) => {
    const slot = positions.find((p) => p.camera_id === c.id && p.start_time <= hm && hm < p.end_time)
    return { camera_id: c.id, class_id: slot?.class_id ?? c.class_id ?? null, camera_name: c.name, class_name: slot?.class_name ?? classes.find((k) => k.id === c.class_id)?.name ?? null, connected: c.id !== 2 || now.getSeconds() % 50 > 5, detecting: !!slot, phase: slot ? 'detecting' : 'dars vaqti emas', roll_call: false }
  })
}
const manual = new Map<number, string>()
function liveStatus(): LiveStatusDto[] {
  const now = new Date(); const hm = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`
  return students.map((s) => {
    const cls = classes.find((c) => c.id === s.class_id)!
    const state = hm < cls.start_time! ? 'upcoming' : hm < cls.end_time! ? 'running' : 'finished'
    const seen = state !== 'upcoming' && s.id % 7 !== 0
    const m = manual.get(s.id)
    return { student_id: s.id, first_name: s.first_name, last_name: s.last_name, class_id: s.class_id, class_name: s.class_name, class_lesson_state: state, status: m ?? (seen ? (s.id % 5 === 0 ? 'late' : 'present') : state === 'finished' ? 'absent' : 'not_detected'), time_in: m === 'present' ? new Date().toISOString() : seen ? `${today}T${cls.start_time}:0${s.id % 10}` : null }
  })
}

// ---------------------------------------------------------------- router

type Handler = (m: RegExpMatchArray, q: Record<string, string>, body: any, form: FormData | undefined) => unknown
const routes: [string, RegExp, Handler][] = []
const on = (method: string, re: RegExp, h: Handler) => routes.push([method, re, h])
const teacherMe = () => teachers[0]

on('POST', /^auth\/(director|teacher)\/login$/, (m) => (m[1] === 'director' ? { access_token: 'demo', director: { id: 1, full_name: 'Шарипов Шоҳрух', email: 'director@cict.tj' } } : { access_token: 'demo', teacher: teacherMe() }))
on('GET', /^classes$/, () => classes)
on('POST', /^classes$/, (_m, _q, b) => { const c = { id: classes.length + 1, name: b.name, grade: b.grade ?? null }; classes.push(c); return c })
on('DELETE', /^classes\/(\d+)$/, (m) => { const i = classes.findIndex((c) => c.id === +m[1]); if (i >= 0) classes.splice(i, 1); return null })
on('GET', /^classes\/(\d+)\/subjects$/, (m) => teachers.filter((t) => teacherOf[+m[1]] === t.id).map((t): ClassSubjectDto => ({ id: t.id, subject: subjectOf[+m[1]], teacher_id: t.id, teacher_name: t.full_name })))
on('GET', /^students$/, () => students)
on('POST', /^students\/director-create$/, (_m, _q, _b, f) => { const cid = Number(f!.get('class_id')); const s: StudentDto = { id: students.length + 1, class_id: cid, class_name: classes.find((c) => c.id === cid)?.name, first_name: String(f!.get('first_name')), last_name: String(f!.get('last_name')), parent_phone: String(f!.get('parent_phone')), parent_name: (f!.get('parent_full_name') as string) || null, username: `user${students.length + 1}`, is_active: true }; students.push(s); return s })
on('PUT', /^students\/(\d+)$/, (m, _q, _b, f) => { const s = students.find((x) => x.id === +m[1])!; const cid = Number(f!.get('class_id')); Object.assign(s, { first_name: f!.get('first_name'), last_name: f!.get('last_name'), class_id: cid, class_name: classes.find((c) => c.id === cid)?.name, parent_phone: (f!.get('parent_phone') as string) || s.parent_phone, username: (f!.get('username') as string) || s.username }); return s })
on('DELETE', /^students\/(\d+)$/, (m) => { const i = students.findIndex((s) => s.id === +m[1]); if (i >= 0) students.splice(i, 1); return null })
on('GET', /^teachers$/, () => teachers)
on('POST', /^teachers$/, (_m, _q, b) => { const t: TeacherDto = { id: teachers.length + 1, full_name: b.full_name, email: b.email, subject: b.subject ?? null, is_active: true }; teachers.push(t); return t })
on('POST', /^teachers\/(\d+)\/classes$/, (m, _q, b): ClassAssignmentDto => { teacherOf[b.class_id] = +m[1]; subjectOf[b.class_id] = b.subject; return { id: 90 + +m[1], class_id: b.class_id, subject: b.subject, class_name: classes.find((c) => c.id === b.class_id)?.name } })
on('GET', /^cameras$/, () => cameras)
on('GET', /^cameras\/status$/, () => cameraStatus())
on('POST', /^cameras$/, (_m, _q, b) => { const c: CameraDto = { id: cameras.length + 1, ...b }; cameras.push(c); return c })
on('PUT', /^cameras\/(\d+)$/, (m, _q, b) => { const c = cameras.find((x) => x.id === +m[1])!; Object.assign(c, b); return c })
on('DELETE', /^cameras\/(\d+)$/, (m) => { const i = cameras.findIndex((c) => c.id === +m[1]); if (i >= 0) cameras.splice(i, 1); return null })
on('GET', /^cameras\/(\d+)\/positions$/, (m) => positions.filter((p) => p.camera_id === +m[1]))
on('POST', /^cameras\/(\d+)\/positions$/, (m, _q, b) => { const p: CameraPositionDto = { id: nextId++, camera_id: +m[1], class_id: b.class_id, class_name: classes.find((c) => c.id === b.class_id)?.name, subject: b.subject ?? null, day_of_week: b.day_of_week ?? null, start_time: b.start_time, end_time: b.end_time }; positions.push(p); return p })
on('DELETE', /^cameras\/\d+\/positions\/(\d+)$/, (m) => { const i = positions.findIndex((p) => p.id === +m[1]); if (i >= 0) positions.splice(i, 1); return null })
on('GET', /^attendance\/live-status$/, () => liveStatus())
on('POST', /^attendance\/manual$/, (_m, _q, b) => { manual.set(b.student_id, b.status); return liveStatus().find((x) => x.student_id === b.student_id) })
on('GET', /^school\/settings$/, () => settings)
on('PUT', /^school\/settings$/, (_m, _q, b) => { settings = { ...settings, ...b }; return settings })
on('GET', /^announcements$/, () => announcements)
on('POST', /^announcements$/, (_m, _q, b) => { const a: AnnouncementDto = { id: nextId++, title: b.title, body: b.body, class_id: b.class_id ?? null, created_at: new Date().toISOString() }; announcements.unshift(a); return a })
on('DELETE', /^announcements\/(\d+)$/, (m) => { const i = announcements.findIndex((a) => a.id === +m[1]); if (i >= 0) announcements.splice(i, 1); return null })
on('GET', /^calendar\/events$/, () => events)
on('POST', /^calendar\/events$/, (_m, _q, b) => { const e: CalendarEventDto = { id: nextId++, ...b }; events.push(e); return e })
on('DELETE', /^calendar\/events\/(\d+)$/, (m) => { const i = events.findIndex((e) => e.id === +m[1]); if (i >= 0) events.splice(i, 1); return null })
on('GET', /^grades$/, (_m, q) => grades.filter((g) => (!q.class_id || g.class_id === +q.class_id) && (!q.subject || g.subject === q.subject) && (!q.student_id || g.student_id === +q.student_id)).sort((a, b) => b.grade_date.localeCompare(a.grade_date)))
on('POST', /^grades$/, (_m, _q, b) => { const g: GradeDto = { id: nextId++, student_id: b.student_id, class_id: b.class_id, subject: b.subject, value: b.value, comment: b.comment ?? null, grade_date: today, quarter: 1, teacher_name: teacherMe().full_name }; grades.push(g); return g })
on('PATCH', /^grades\/(\d+)$/, (m, _q, b) => { const g = grades.find((x) => x.id === +m[1])!; if (b.value != null) g.value = b.value; if ('comment' in b) g.comment = b.comment; return g })
on('DELETE', /^grades\/(\d+)$/, (m) => { const i = grades.findIndex((g) => g.id === +m[1]); if (i >= 0) grades.splice(i, 1); return null })
on('GET', /^journal\/absences$/, (_m, q) => absences.filter((a) => (!q.class_id || students.find((s) => s.id === a.student_id)?.class_id === +q.class_id) && (!q.subject || a.subject === q.subject)))
on('GET', /^analytics\/student\/(\d+)$/, (m) => analytics(+m[1]))
on('GET', /^analytics\/school\/ranking$/, () => ranking(() => true))
on('GET', /^analytics\/class\/(\d+)\/ranking$/, (m) => ranking((s) => s.class_id === +m[1]))
on('GET', /^analytics\/school\/needs-attention$/, () => needsAttention())
on('GET', /^analytics\/class\/(\d+)\/subjects$/, (m): ClassSubjectAverageDto[] => { const l = grades.filter((g) => g.class_id === +m[1]); return [...new Set(l.map((g) => g.subject))].map((sub) => { const x = l.filter((g) => g.subject === sub); return { subject: sub, average: avgOf(x)!, grade_count: x.length, student_count: new Set(x.map((g) => g.student_id)).size } }) })

on('GET', /^teachers\/me\/classes$/, (): ClassAssignmentDto[] => classes.filter((c) => teacherOf[c.id] === 1 || c.id === 3).map((c) => ({ id: c.id, class_id: c.id, subject: subjectOf[c.id], class_name: c.name })))
on('GET', /^teachers\/me\/classes\/(\d+)\/students$/, (m) => students.filter((s) => s.class_id === +m[1]))
on('GET', /^diary$/, (_m, q) => diaryFor(+q.class_id, q.on))
on('PATCH', /^diary\/(\d+)$/, (m, q, b) => { const l = Object.values(diary).flat().find((x) => x.lesson_id === +m[1]) ?? diaryFor(1, q.on)[0]; if (l) Object.assign(l, b); return l })
on('GET', /^materials$/, (): MaterialSummaryDto[] => materials.map((m) => ({ id: m.id, title: m.title, description: m.description, subject: m.subject, teacher_id: 1, teacher_name: teacherMe().full_name, question_count: m.blocks.filter((b) => b.block_type === 'question').length, page_count: m.blocks.filter((b) => b.block_type === 'page').length, max_score: m.blocks.reduce((s, b) => s + b.points, 0), assigned_class_count: new Set(assignments.filter((a) => a.material_id === m.id).map((a) => a.class_id)).size, updated_at: materialMeta[m.id]?.updated_at ?? new Date().toISOString() })))
on('GET', /^materials\/(\d+)$/, (m) => materials.find((x) => x.id === +m[1]))
on('POST', /^materials$/, (_m, _q, b) => { const m: MaterialFullDto = { id: nextId++, title: b.title, description: b.description ?? null, subject: b.subject ?? 'BackEnd #1', blocks: b.blocks }; materials.unshift(m); materialMeta[m.id] = { updated_at: new Date().toISOString() }; return m })
on('PATCH', /^materials\/(\d+)$/, (m, _q, b) => { const x = materials.find((y) => y.id === +m[1])!; if (b.title) x.title = b.title; if ('description' in b) x.description = b.description; if (b.blocks) x.blocks = b.blocks; materialMeta[x.id] = { updated_at: new Date().toISOString() }; return x })
on('DELETE', /^materials\/(\d+)$/, (m) => { const i = materials.findIndex((x) => x.id === +m[1]); if (i >= 0) materials.splice(i, 1); return null })
on('POST', /^materials\/ai\/generate$/, async (_m, _q, _b, f): Promise<AiGenerateResponse> => {
  await sleep(4500 + Math.random() * 2500)
  const topic = String(f?.get('topic') || 'Мавзӯи дарс')
  const test = f?.get('kind') === 'test'
  const n = Math.max(2, Math.min(15, Number(f?.get('question_count') || 6)))
  const pool: BlockDto[] = [
    { block_type: 'question', question_type: 'single', body: `${topic}: кадоме аз инҳо дуруст аст?`, options: ['Варианти A', 'Варианти B', 'Варианти C', 'Варианти D'], correct: { index: 1 }, points: 1 },
    { block_type: 'question', question_type: 'truefalse', body: `${topic} — ин мафҳуми асосии курс аст.`, correct: { value: true }, points: 1 },
    { block_type: 'question', question_type: 'fill', body: `Истилоҳи асосии мавзӯи «${topic}»-ро нависед: ____`, correct: { answers: [topic.split(/[:\s]/)[0]] }, points: 1 },
    { block_type: 'question', question_type: 'single', body: `Дар мавзӯи «${topic}» кадом қадам аввал иҷро мешавад?`, options: ['Таҳлил', 'Амалӣ кардан', 'Санҷиш', 'Ҳуҷҷатнигорӣ'], correct: { index: 0 }, points: 1 },
    { block_type: 'question', question_type: 'order', body: 'Марҳилаҳоро ба тартиб гузоред', options: ['санҷиш', 'банақшагирӣ', 'иҷро'], correct: { order: [1, 2, 0] }, points: 2 },
    { block_type: 'question', question_type: 'match', body: 'Мафҳумҳоро мувофиқ кунед', options: { left: ['Клиент', 'Сервер', 'Протокол'], right: ['қоидаҳо', 'дархост мефиристад', 'ҷавоб медиҳад'] }, correct: { pairs: [[0, 1], [1, 2], [2, 0]] }, points: 2 },
  ]
  const blocks: BlockDto[] = test ? [] : [{ block_type: 'page', body: `${topic}\n\nИн саҳифаи дарс аз ҷониби ҲС дар реҷаи намоишӣ тайёр шудааст. Дар сервери воқеӣ матни пурраи дарс, мисолҳо ва хулоса дар ин ҷо меистад.`, points: 0 }]
  for (let i = 0; i < n; i++) blocks.push({ ...pool[i % pool.length], body: pool[i % pool.length].body + (i >= pool.length ? ` (${Math.floor(i / pool.length) + 1})` : '') })
  return { title: topic, description: `Мавод оид ба «${topic}» (намоишӣ).`, blocks: blocks.map((b, i) => ({ ...b, position: i })), dropped_count: 0 }
})
on('GET', /^material-assignments$/, () => assignments.map(({ results: _r, ...a }) => a))
on('POST', /^material-assignments$/, (_m, _q, b) => b.class_ids.map((cid: number) => { const a = makeAssignment(b.material_id, cid, b.mode, 0, b.due_at ?? null, b.max_attempts ?? null, 0); assignments.push(a); const { results: _r, ...rest } = a; return rest }))
on('GET', /^material-assignments\/(\d+)\/results$/, (m): AssignmentResultsDto => { const a = assignments.find((x) => x.id === +m[1])!; const { results, ...rest } = a; return { assignment: rest, results_visible: a.results_visible, rows: students.filter((s) => s.class_id === a.class_id).map((s) => { const r = results.find((x) => x.student_id === s.id); return { student_id: s.id, student_name: `${s.last_name} ${s.first_name}`, submitted_at: r?.submitted_at ?? null, attempt_count: r?.attempts ?? 0, score: r?.score ?? null, max_score: a.max_score, percent: r?.percent ?? null, suggested_grade: r ? Math.max(2, Math.min(10, Math.round(r.percent / 10))) : null, transferred: r?.transferred ?? false } }) } })
on('POST', /^material-assignments\/(\d+)\/transfer-grades$/, (m, q, b) => { const a = assignments.find((x) => x.id === +m[1])!; for (const it of b.items) { const r = a.results.find((x) => x.student_id === it.student_id); if (r) r.transferred = true; grades.push({ id: nextId++, student_id: it.student_id, class_id: a.class_id, subject: a.subject, value: it.value, grade_date: today, quarter: 1, teacher_name: teacherMe().full_name, comment: a.material_title }) } a.grades_transferred_at = new Date().toISOString(); return routes.find((r) => r[0] === 'GET' && r[1].source.includes('results'))![2](m, q, null, undefined) })

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

export async function demoRequest<T>(method: string, path: string, query: Record<string, string>, body: unknown, form?: FormData): Promise<T> {
  const clean = path.replace(/^\//, '').replace(/\/$/, '')
  for (const [m, re, h] of routes) {
    if (m !== method) continue
    const match = clean.match(re)
    if (match) {
      await sleep(120 + Math.random() * 280)
      return (await h(match, query, body, form)) as T
    }
  }
  throw new Error(`demo: no route for ${method} ${clean}`)
}
