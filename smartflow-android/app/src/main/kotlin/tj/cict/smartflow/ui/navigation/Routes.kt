package tj.cict.smartflow.ui.navigation

import kotlinx.serialization.Serializable

// Type-safe destinations. Anything with a childId is a detail page pushed
// on top of the tabbed shell.

@Serializable object LoginRoute
@Serializable data class VerifyRoute(val phone: String)
@Serializable data class SetPasswordRoute(val phone: String, val setupToken: String, val fullName: String)

@Serializable object HomeRoute
@Serializable object DiaryRoute
@Serializable object RatingRoute
@Serializable object AlertsRoute

@Serializable data class AttendanceRoute(val childId: Int)
@Serializable data class GradesRoute(val childId: Int)
@Serializable data class HomeworkRoute(val childId: Int)
@Serializable data class AssignmentsRoute(val childId: Int)
@Serializable data class CalendarRoute(val childId: Int)
@Serializable data class AnnouncementsRoute(val childId: Int)

@Serializable object TasksRoute
@Serializable data class AssignmentDetailRoute(val childId: Int, val assignmentId: Int)
@Serializable data class AchievementsRoute(val childId: Int)

@Serializable object JournalRoute
@Serializable object MaterialsRoute
@Serializable data class ClassJournalRoute(val classId: Int, val subject: String, val className: String)
@Serializable data class ScanRoute(val classId: Int?)
@Serializable data class ResultsRoute(val assignmentId: Int)
@Serializable object TeacherCalendarRoute
@Serializable object TeacherAnnouncementsRoute

@Serializable object LiveRoute
@Serializable object SchoolRoute
@Serializable object AnalyticsRoute
@Serializable object LiveVideoRoute
@Serializable object ClassesRoute
@Serializable data class ClassDetailRoute(val classId: Int, val name: String, val grade: Int?)
@Serializable object StudentsRoute
@Serializable object TeachersRoute
@Serializable object CamerasRoute
@Serializable object DirectorAnnouncementsRoute
@Serializable object DirectorCalendarRoute
@Serializable object SettingsRoute

@Serializable data class PositionsRoute(val cameraId: Int, val cameraName: String)

@Serializable data class StudentRatingRoute(val studentId: Int, val name: String)

@Serializable data class MaterialEditorRoute(val materialId: Int?)
