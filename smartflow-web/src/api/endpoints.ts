import { del, get, patch, post, publicBase, put, request } from './client'
import type {
  AbsenceDto, AiGenerateResponse, AnalyticsDto, AnnouncementDto, AnswerOutDto, AssignmentDto, AssignmentResultsDto,
  AttemptResultDto, AttendanceRowDto, BlockDto, CalendarEventDto, CameraDto, CameraPositionDto, CameraStatusDto, ClassAssignmentDto,
  ClassDto, ClassSubjectAverageDto, ClassSubjectDto, DiaryEntryDto, DirectorDto, GradeDto, LeaderboardEntryDto,
  LiveStatusDto, MaterialFullDto, MaterialSummaryDto, NeedsAttentionDto, NotificationDto, SchoolSettingsDto,
  StudentAssignmentDetailDto, StudentAssignmentDto, StudentDto, TeacherDto,
} from './types'

// ------------------------------------------------------------------ auth
export const auth = {
  teacherLogin: (email: string, password: string) =>
    post<{ access_token: string; teacher: TeacherDto }>('auth/teacher/login', { email, password }, { auth: false }),
  directorLogin: (email: string, password: string) =>
    post<{ access_token: string; director?: DirectorDto | null; must_change_password?: boolean }>('auth/director/login', { email, password }, { auth: false }),
  // Parents and pupils authenticate on the public server, not the school.
  parentLogin: (phone: string, password: string) =>
    post<{ status: string; access_token?: string; parent_id?: number; full_name?: string; phone?: string }>(
      'auth/login', { phone, password }, { auth: false, base: publicBase() }),
  studentLogin: (username: string, password: string) =>
    post<{ status: string; access_token: string; student_id: number; full_name: string; class_name?: string | null }>(
      'auth/student/login', { username, password }, { auth: false, base: publicBase() }),
}

// --------------------------------------------------------------- family
// One API for both parent and pupil; the token decides whose data comes back.
export const family = {
  children: () => get<StudentDto[]>('students/me'),
  grades: (studentId: number) => get<GradeDto[]>('grades', { student_id: studentId, limit: 2000 }),
  attendance: (studentId: number) => get<AttendanceRowDto[]>('attendance/history', { student_id: studentId, limit: 400 }),
  diary: (studentId: number, on: string) => get<DiaryEntryDto[]>(`diary/${studentId}`, { on }),
  analytics: (studentId: number, quarter?: number | null) => get<AnalyticsDto>(`analytics/student/${studentId}`, { quarter: quarter ?? undefined }),
  announcements: (studentId: number) => get<AnnouncementDto[]>('announcements', { student_id: studentId }),
  calendar: (studentId: number) => get<CalendarEventDto[]>('calendar/events', { student_id: studentId }),
  notifications: (parentId: number) => get<NotificationDto[]>(`notifications/parent/${parentId}`, { limit: 100 }),

  assignments: (studentId: number) => get<StudentAssignmentDto[]>('materials/assignments', { student_id: studentId }),
  assignment: (id: number, studentId: number) => get<StudentAssignmentDetailDto>(`materials/assignments/${id}`, { student_id: studentId }),
  startAttempt: (id: number, studentId: number) =>
    request<StudentAssignmentDetailDto>(`materials/assignments/${id}/start`, { method: 'POST', query: { student_id: studentId } }),
  answer: (attemptId: number, blockId: number, answer: unknown) =>
    post<AnswerOutDto>(`materials/attempts/${attemptId}/answer`, { block_id: blockId, answer }),
  submit: (attemptId: number) => post<AttemptResultDto>(`materials/attempts/${attemptId}/submit`),
}

// --------------------------------------------------------------- teacher
export const teacher = {
  classes: () => get<ClassAssignmentDto[]>('teachers/me/classes'),
  roster: (classId: number) => get<StudentDto[]>(`teachers/me/classes/${classId}/students`),
  grades: (classId: number, subject?: string | null) => get<GradeDto[]>('grades', { class_id: classId, subject: subject ?? undefined, limit: 3000 }),
  createGrade: (b: { student_id: number; class_id: number; subject: string; value: number; comment?: string | null }) => post<GradeDto>('grades', b),
  updateGrade: (id: number, b: { value?: number; comment?: string | null }) => patch<GradeDto>(`grades/${id}`, b),
  deleteGrade: (id: number) => del<void>(`grades/${id}`),
  absences: (classId: number, subject?: string | null) => get<AbsenceDto[]>('journal/absences', { class_id: classId, subject: subject ?? undefined }),
  diary: (classId: number, on: string) => get<DiaryEntryDto[]>('diary', { class_id: classId, on }),
  updateDiary: (lessonId: number, on: string, b: { homework?: string | null; teacher_comment?: string | null }) =>
    request<DiaryEntryDto>(`diary/${lessonId}`, { method: 'PATCH', body: b, query: { on } }),

  materials: (scope = 'mine') => get<MaterialSummaryDto[]>('materials', { scope }),
  material: (id: number) => get<MaterialFullDto>(`materials/${id}`),
  createMaterial: (b: { title: string; description?: string | null; subject?: string | null; blocks: BlockDto[] }) => post<MaterialFullDto>('materials', b),
  updateMaterial: (id: number, b: { title?: string; description?: string | null; blocks?: BlockDto[] }) => patch<MaterialFullDto>(`materials/${id}`, b),
  deleteMaterial: (id: number) => del<void>(`materials/${id}`),
  aiGenerate: (form: FormData) => request<AiGenerateResponse>('materials/ai/generate', { method: 'POST', form, timeoutMs: 400000 }),

  assignments: () => get<AssignmentDto[]>('material-assignments'),
  assign: (b: { material_id: number; class_ids: number[]; mode: string; due_at?: string | null; max_attempts?: number | null }) => post<AssignmentDto[]>('material-assignments', b),
  results: (id: number) => get<AssignmentResultsDto>(`material-assignments/${id}/results`),
  transfer: (id: number, items: { student_id: number; value: number }[]) => post<AssignmentResultsDto>(`material-assignments/${id}/transfer-grades`, { items }),

  calendar: () => get<CalendarEventDto[]>('calendar/events'),
  announcements: () => get<AnnouncementDto[]>('announcements'),
}

// -------------------------------------------------------------- director
export const director = {
  classes: () => get<ClassDto[]>('classes'),
  createClass: (b: { name: string; grade?: number | null }) => post<ClassDto>('classes', b),
  deleteClass: (id: number) => del<void>(`classes/${id}`),
  classSubjects: (id: number) => get<ClassSubjectDto[]>(`classes/${id}/subjects`),

  students: () => get<StudentDto[]>('students'),
  createStudent: (form: FormData) => request<StudentDto>('students/director-create', { method: 'POST', form, timeoutMs: 120000 }),
  updateStudent: (id: number, form: FormData) => request<StudentDto>(`students/${id}`, { method: 'PUT', form, timeoutMs: 120000 }),
  deleteStudent: (id: number) => del<void>(`students/${id}`),

  teachers: () => get<TeacherDto[]>('teachers'),
  createTeacher: (b: { full_name: string; email: string; password: string; subject?: string | null }) => post<TeacherDto>('teachers', b),
  assignClass: (teacherId: number, b: { class_id: number; subject: string }) => post<ClassAssignmentDto>(`teachers/${teacherId}/classes`, b),

  cameras: () => get<CameraDto[]>('cameras'),
  cameraStatus: () => get<CameraStatusDto[]>('cameras/status'),
  createCamera: (b: Partial<CameraDto>) => post<CameraDto>('cameras', b),
  updateCamera: (id: number, b: Partial<CameraDto>) => put<CameraDto>(`cameras/${id}`, b),
  deleteCamera: (id: number) => del<void>(`cameras/${id}`),
  positions: (cameraId: number) => get<CameraPositionDto[]>(`cameras/${cameraId}/positions`),
  createPosition: (cameraId: number, b: { class_id: number; start_time: string; end_time: string; subject?: string | null; day_of_week?: number | null }) =>
    post<CameraPositionDto>(`cameras/${cameraId}/positions`, b),
  deletePosition: (cameraId: number, id: number) => del<void>(`cameras/${cameraId}/positions/${id}`),

  liveStatus: () => get<LiveStatusDto[]>('attendance/live-status'),
  markAttendance: (studentId: number, status: 'present' | 'absent') => post<LiveStatusDto>('attendance/manual', { student_id: studentId, status }),
  settings: () => get<SchoolSettingsDto>('school/settings'),
  updateSettings: (b: Partial<SchoolSettingsDto>) => put<SchoolSettingsDto>('school/settings', b),

  announcements: () => get<AnnouncementDto[]>('announcements'),
  createAnnouncement: (b: { title: string; body: string; class_id?: number | null }) => post<AnnouncementDto>('announcements', b),
  deleteAnnouncement: (id: number) => del<void>(`announcements/${id}`),
  calendar: () => get<CalendarEventDto[]>('calendar/events'),
  createEvent: (b: { title: string; description?: string | null; event_type: string; start_date: string; end_date?: string | null; class_id?: number | null }) =>
    post<CalendarEventDto>('calendar/events', b),
  deleteEvent: (id: number) => del<void>(`calendar/events/${id}`),

  grades: (classId: number, subject?: string | null) => get<GradeDto[]>('grades', { class_id: classId, subject: subject ?? undefined, limit: 3000 }),
  absences: (classId: number) => get<AbsenceDto[]>('journal/absences', { class_id: classId }),

  studentAnalytics: (id: number, quarter?: number | null) => get<AnalyticsDto>(`analytics/student/${id}`, { quarter: quarter ?? undefined }),
  schoolRanking: (quarter?: number | null) => get<LeaderboardEntryDto[]>('analytics/school/ranking', { quarter: quarter ?? undefined }),
  classRanking: (id: number, quarter?: number | null) => get<LeaderboardEntryDto[]>(`analytics/class/${id}/ranking`, { quarter: quarter ?? undefined }),
  needsAttention: (quarter?: number | null) => get<NeedsAttentionDto>('analytics/school/needs-attention', { quarter: quarter ?? undefined }),
  classSubjectAverages: (id: number, quarter?: number | null) => get<ClassSubjectAverageDto[]>(`analytics/class/${id}/subjects`, { quarter: quarter ?? undefined }),
}
