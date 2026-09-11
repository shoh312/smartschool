// Shapes as the school server returns them (snake_case kept on purpose: one
// less place for a field name to drift from the API).

export type Role = 'director' | 'teacher'

export interface Session {
  token: string
  role: Role
  id: number
  fullName: string
  email: string
  subject?: string | null
  serverUrl: string
}

export interface TeacherDto { id: number; full_name: string; email: string; subject?: string | null; is_active?: boolean }
export interface DirectorDto { id: number; school_id?: number | null; full_name: string; email: string }

export interface ClassDto { id: number; name: string; grade?: number | null; start_time?: string | null; end_time?: string | null }
export interface ClassAssignmentDto { id: number; class_id: number; subject?: string | null; class_name?: string | null }
export interface ClassSubjectDto { id: number; subject?: string | null; teacher_id: number; teacher_name: string }
export interface ClassSubjectAverageDto { subject: string; average: number; grade_count: number; student_count: number }

export interface StudentDto {
  id: number
  class_id?: number | null
  class_name?: string | null
  parent_phone?: string | null
  parent_name?: string | null
  username?: string | null
  first_name: string
  last_name: string
  is_active?: boolean
}

export interface GradeDto {
  id: number
  student_id: number
  class_id?: number
  subject: string
  value: number
  comment?: string | null
  teacher_name?: string | null
  grade_date: string
  quarter?: number | null
}
export interface AbsenceDto { student_id: number; subject: string; date: string; lesson_id: number }

export interface CameraDto { id: number; class_id?: number | null; name: string; ip_address?: string | null; rtsp_url?: string | null; is_active?: boolean }
export interface CameraStatusDto {
  camera_id: number
  camera_name?: string | null
  class_name?: string | null
  connected?: boolean
  detecting?: boolean
  phase?: string | null
  roll_call?: boolean
  seconds_to_detect?: number | null
  seconds_to_roll_call_close?: number | null
  detecting_for?: number | null
  stale_seconds?: number | null
}
export interface CameraPositionDto {
  id: number
  camera_id: number
  class_id: number
  class_name?: string | null
  subject?: string | null
  day_of_week?: number | null
  start_time: string
  end_time: string
}

export interface LiveStatusDto {
  student_id: number
  first_name: string
  last_name: string
  class_id?: number | null
  class_name?: string | null
  class_lesson_state?: string
  status: string
  time_in?: string | null
  last_seen?: string | null
  detected_at?: string | null
}

export interface SchoolSettingsDto { live_video_enabled: boolean; group_mode: boolean; sms_enabled: boolean; is_active: boolean }

export interface LeaderboardEntryDto {
  student_id: number
  first_name: string
  last_name: string
  class_id?: number | null
  class_name?: string | null
  overall_average?: number | null
  position: number
  out_of: number
}
export interface DeclinerDto {
  student_id: number
  first_name: string
  last_name: string
  class_name?: string | null
  current_average: number
  previous_average: number
  delta: number
}
export interface NeedsAttentionDto { bottom_performers: LeaderboardEntryDto[]; biggest_decliners: DeclinerDto[] }

export interface RankDto { position?: number | null; out_of: number }
export interface SubjectAverageDto { subject: string; average: number; grade_count: number }
export interface AnalyticsDto {
  student_id: number
  first_name: string
  last_name: string
  quarter: number
  school_year?: number | null
  overall_average?: number | null
  class_rank: RankDto
  parallel_rank: RankDto
  school_rank: RankDto
  class_average?: number | null
  parallel_average?: number | null
  school_average?: number | null
  subject_breakdown: SubjectAverageDto[]
  strongest_subject?: string | null
  weakest_subject?: string | null
  lesson_attendance_rate?: number | null
}

export interface AnnouncementDto { id: number; class_id?: number | null; title: string; body: string; created_at?: string | null }
export interface CalendarEventDto { id: number; title: string; description?: string | null; event_type: string; start_date: string; end_date?: string | null; class_id?: number | null }

export interface DiaryEntryDto {
  lesson_id: number
  subject: string
  start_time: string
  duration_minutes: number
  room?: string | null
  teacher_id?: number | null
  teacher_name?: string | null
  homework?: string | null
  teacher_comment?: string | null
}

// ---------------------------------------------------------------- materials

export type BlockType = 'page' | 'question'
export type QuestionType = 'single' | 'truefalse' | 'fill' | 'match' | 'order'

export interface BlockDto {
  id?: number
  position?: number
  block_type: BlockType
  body: string
  question_type?: QuestionType | null
  options?: unknown
  correct?: unknown
  points: number
}
export interface MaterialSummaryDto {
  id: number
  title: string
  description?: string | null
  subject: string
  teacher_id: number
  teacher_name?: string | null
  question_count: number
  page_count: number
  max_score: number
  assigned_class_count: number
  updated_at?: string | null
}
export interface MaterialFullDto { id: number; title: string; description?: string | null; subject: string; blocks: BlockDto[] }
export interface AiGenerateResponse { title: string; description?: string | null; blocks: BlockDto[]; dropped_count: number }

export interface AssignmentDto {
  id: number
  material_id: number
  material_title: string
  subject: string
  class_id: number
  class_name?: string | null
  mode: string
  due_at?: string | null
  max_attempts?: number | null
  published_at?: string | null
  grades_transferred_at?: string | null
  question_count: number
  max_score: number
  student_count: number
  submitted_count: number
  results_visible: boolean
}
export interface ResultRowDto {
  student_id: number
  student_name: string
  submitted_at?: string | null
  attempt_count: number
  score?: number | null
  max_score?: number | null
  percent?: number | null
  suggested_grade?: number | null
  transferred: boolean
}
export interface AssignmentResultsDto { assignment: AssignmentDto; results_visible: boolean; rows: ResultRowDto[] }
