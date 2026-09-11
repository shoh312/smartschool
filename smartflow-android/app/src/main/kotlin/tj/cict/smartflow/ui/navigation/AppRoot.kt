package tj.cict.smartflow.ui.navigation

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import org.koin.androidx.compose.koinViewModel
import tj.cict.smartflow.core.session.Role
import tj.cict.smartflow.ui.achievements.AchievementsScreen
import tj.cict.smartflow.ui.alerts.AlertsScreen
import tj.cict.smartflow.ui.announcements.AnnouncementsScreen
import tj.cict.smartflow.ui.assignments.AssignmentPlayerScreen
import tj.cict.smartflow.ui.assignments.AssignmentsScreen
import tj.cict.smartflow.ui.attendance.AttendanceScreen
import tj.cict.smartflow.ui.auth.LoginScreen
import tj.cict.smartflow.ui.auth.SetPasswordScreen
import tj.cict.smartflow.ui.auth.VerifyScreen
import tj.cict.smartflow.ui.calendar.CalendarScreen
import tj.cict.smartflow.ui.components.PageBackground
import tj.cict.smartflow.ui.diary.DiaryScreen
import tj.cict.smartflow.ui.grades.GradesScreen
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.home.HomeScreen
import tj.cict.smartflow.ui.home.StudentHomeScreen
import tj.cict.smartflow.ui.homework.HomeworkScreen
import tj.cict.smartflow.ui.onboarding.OnboardingScreen
import tj.cict.smartflow.ui.rating.RatingScreen
import tj.cict.smartflow.data.dto.ClassDto
import tj.cict.smartflow.ui.director.CamerasScreen
import tj.cict.smartflow.ui.director.ClassDetailScreen
import tj.cict.smartflow.ui.director.ClassesScreen
import tj.cict.smartflow.ui.director.DirectorAnalyticsScreen
import tj.cict.smartflow.ui.director.DirectorAnnouncementsScreen
import tj.cict.smartflow.ui.director.DirectorCalendarScreen
import tj.cict.smartflow.ui.director.DirectorHomeScreen
import tj.cict.smartflow.ui.director.LiveAttendanceScreen
import tj.cict.smartflow.ui.director.LiveVideoScreen
import tj.cict.smartflow.ui.director.LiveViewModel
import tj.cict.smartflow.ui.director.SchoolHubScreen
import tj.cict.smartflow.ui.director.SchoolViewModel
import tj.cict.smartflow.ui.director.SettingsScreen
import tj.cict.smartflow.ui.director.StudentsScreen
import tj.cict.smartflow.ui.director.TeachersScreen
import tj.cict.smartflow.ui.teacher.ClassJournalScreen
import tj.cict.smartflow.ui.teacher.JournalClassesScreen
import tj.cict.smartflow.ui.teacher.MaterialsScreen
import tj.cict.smartflow.ui.teacher.ResultsScreen
import tj.cict.smartflow.ui.teacher.ScanJournalScreen
import tj.cict.smartflow.ui.teacher.TeacherAnnouncementsScreen
import tj.cict.smartflow.ui.teacher.TeacherCalendarScreen
import tj.cict.smartflow.ui.teacher.TeacherClassesViewModel
import tj.cict.smartflow.ui.teacher.TeacherDiaryScreen
import tj.cict.smartflow.ui.teacher.TeacherHomeScreen

@Composable
fun AppRoot() {
    val sessionVm: SessionViewModel = koinViewModel()
    val state by sessionVm.state.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { sessionVm.refreshSchoolServer() }

    AnimatedContent(
        targetState = state,
        transitionSpec = { fadeIn(tween(350)) togetherWith fadeOut(tween(250)) },
        contentKey = { (it as? SessionState.SignedIn)?.session?.role ?: it::class },
        label = "session",
    ) { s ->
        when (s) {
            SessionState.Loading -> PageBackground { Box(Modifier.fillMaxSize()) }
            SessionState.Onboarding -> OnboardingScreen(onDone = sessionVm::finishOnboarding)
            SessionState.SignedOut -> AuthGraph()
            is SessionState.SignedIn -> when (s.session.role) {
                Role.PARENT -> ParentGraph(parentId = s.session.ownerId, parentName = s.session.fullName, onSignOut = sessionVm::signOut)
                Role.STUDENT -> StudentGraph(studentId = s.session.ownerId, name = s.session.fullName, className = s.session.className, onSignOut = sessionVm::signOut)
                Role.TEACHER -> TeacherGraph(teacherId = s.session.ownerId, name = s.session.fullName, subject = s.session.className, onSignOut = sessionVm::signOut)
                Role.DIRECTOR -> DirectorGraph(name = s.session.fullName, onSignOut = sessionVm::signOut)
            }
        }
    }
}

@Composable
private fun AuthGraph() {
    val nav = rememberNavController()
    NavHost(
        nav,
        startDestination = LoginRoute,
        enterTransition = { slideInHorizontally(tween(320)) { it / 3 } + fadeIn(tween(320)) },
        exitTransition = { fadeOut(tween(200)) },
        popEnterTransition = { fadeIn(tween(250)) },
        popExitTransition = { slideOutHorizontally(tween(260)) { it / 3 } + fadeOut(tween(200)) },
    ) {
        composable<LoginRoute> {
            LoginScreen(onNeedsPassword = { phone -> nav.navigate(VerifyRoute(phone)) })
        }
        composable<VerifyRoute> { entry ->
            val route = entry.toRoute<VerifyRoute>()
            VerifyScreen(
                phone = route.phone,
                onBack = { nav.popBackStack() },
                onVerified = { token, name -> nav.navigate(SetPasswordRoute(route.phone, token, name)) },
            )
        }
        composable<SetPasswordRoute> { entry ->
            val route = entry.toRoute<SetPasswordRoute>()
            SetPasswordScreen(setupToken = route.setupToken, initialName = route.fullName, onBack = { nav.popBackStack() })
        }
    }
}

/** The detail pages both roles share; a pupil is just a family of one. */
private fun NavGraphBuilder.childDetails(nav: NavHostController, childrenVm: ChildrenViewModel, canAnswer: Boolean) {
    composable<AttendanceRoute> { e -> AttendanceScreen(e.toRoute<AttendanceRoute>().childId, childrenVm, onBack = { nav.popBackStack() }) }
    composable<GradesRoute> { e -> GradesScreen(e.toRoute<GradesRoute>().childId, childrenVm, onBack = { nav.popBackStack() }) }
    composable<HomeworkRoute> { e -> HomeworkScreen(e.toRoute<HomeworkRoute>().childId, childrenVm, onBack = { nav.popBackStack() }) }
    composable<CalendarRoute> { e -> CalendarScreen(e.toRoute<CalendarRoute>().childId, childrenVm, onBack = { nav.popBackStack() }) }
    composable<AnnouncementsRoute> { e -> AnnouncementsScreen(e.toRoute<AnnouncementsRoute>().childId, childrenVm, onBack = { nav.popBackStack() }) }
    composable<AchievementsRoute> { e -> AchievementsScreen(e.toRoute<AchievementsRoute>().childId, childrenVm, onBack = { nav.popBackStack() }) }
    composable<AssignmentDetailRoute> { e ->
        val r = e.toRoute<AssignmentDetailRoute>()
        AssignmentPlayerScreen(r.childId, r.assignmentId, canAnswer = canAnswer, onBack = { nav.popBackStack() })
    }
}

@Composable
private fun ParentGraph(parentId: Int, parentName: String, onSignOut: () -> Unit) {
    val nav = rememberNavController()
    // Shared across every tab and detail page: the children and which one
    // is in focus. Scoped to the activity, not to a back-stack entry.
    val childrenVm: ChildrenViewModel = koinViewModel()

    MainShell(nav, parentTabs) { padding ->
        NavHost(
            nav,
            startDestination = HomeRoute,
            modifier = Modifier.fillMaxSize(),
            enterTransition = { slideInHorizontally(tween(300)) { it / 4 } + fadeIn(tween(300)) },
            exitTransition = { fadeOut(tween(180)) },
            popEnterTransition = { fadeIn(tween(220)) },
            popExitTransition = { slideOutHorizontally(tween(240)) { it / 4 } + fadeOut(tween(180)) },
        ) {
            composable<HomeRoute> {
                HomeScreen(
                    childrenVm = childrenVm,
                    parentName = parentName,
                    bottomPadding = padding,
                    onSignOut = onSignOut,
                    onAttendance = { nav.navigate(AttendanceRoute(it)) },
                    onGrades = { nav.navigate(GradesRoute(it)) },
                    onHomework = { nav.navigate(HomeworkRoute(it)) },
                    onAssignments = { nav.navigate(AssignmentsRoute(it)) },
                    onCalendar = { nav.navigate(CalendarRoute(it)) },
                    onAnnouncements = { nav.navigate(AnnouncementsRoute(it)) },
                )
            }
            composable<DiaryRoute> { DiaryScreen(childrenVm, bottomPadding = padding) }
            composable<RatingRoute> { RatingScreen(childrenVm, bottomPadding = padding) }
            composable<AlertsRoute> { AlertsScreen(parentId = parentId, childrenVm = childrenVm, bottomPadding = padding) }
            composable<AssignmentsRoute> { e ->
                val id = e.toRoute<AssignmentsRoute>().childId
                AssignmentsScreen(id, childrenVm, onBack = { nav.popBackStack() }, onOpen = { nav.navigate(AssignmentDetailRoute(id, it)) })
            }
            childDetails(nav, childrenVm, canAnswer = false)
        }
    }
}

@Composable
private fun StudentGraph(studentId: Int, name: String, className: String?, onSignOut: () -> Unit) {
    val nav = rememberNavController()
    val childrenVm: ChildrenViewModel = koinViewModel()

    MainShell(nav, studentTabs) { padding ->
        NavHost(
            nav,
            startDestination = HomeRoute,
            modifier = Modifier.fillMaxSize(),
            enterTransition = { slideInHorizontally(tween(300)) { it / 4 } + fadeIn(tween(300)) },
            exitTransition = { fadeOut(tween(180)) },
            popEnterTransition = { fadeIn(tween(220)) },
            popExitTransition = { slideOutHorizontally(tween(240)) { it / 4 } + fadeOut(tween(180)) },
        ) {
            composable<HomeRoute> {
                StudentHomeScreen(
                    childrenVm = childrenVm,
                    studentId = studentId,
                    name = name,
                    className = className,
                    bottomPadding = padding,
                    onSignOut = onSignOut,
                    onAttendance = { nav.navigate(AttendanceRoute(it)) },
                    onGrades = { nav.navigate(GradesRoute(it)) },
                    onHomework = { nav.navigate(HomeworkRoute(it)) },
                    onAchievements = { nav.navigate(AchievementsRoute(it)) },
                    onCalendar = { nav.navigate(CalendarRoute(it)) },
                    onAnnouncements = { nav.navigate(AnnouncementsRoute(it)) },
                )
            }
            composable<DiaryRoute> { DiaryScreen(childrenVm, bottomPadding = padding) }
            composable<TasksRoute> {
                AssignmentsScreen(studentId, childrenVm, onBack = null, bottomPadding = padding, onOpen = { nav.navigate(AssignmentDetailRoute(studentId, it)) })
            }
            composable<RatingRoute> { RatingScreen(childrenVm, bottomPadding = padding) }
            childDetails(nav, childrenVm, canAnswer = true)
        }
    }
}

@Composable
private fun TeacherGraph(teacherId: Int, name: String, subject: String?, onSignOut: () -> Unit) {
    val nav = rememberNavController()
    val classesVm: TeacherClassesViewModel = koinViewModel()

    MainShell(nav, teacherTabs) { padding ->
        NavHost(
            nav,
            startDestination = HomeRoute,
            modifier = Modifier.fillMaxSize(),
            enterTransition = { slideInHorizontally(tween(300)) { it / 4 } + fadeIn(tween(300)) },
            exitTransition = { fadeOut(tween(180)) },
            popEnterTransition = { fadeIn(tween(220)) },
            popExitTransition = { slideOutHorizontally(tween(240)) { it / 4 } + fadeOut(tween(180)) },
        ) {
            composable<HomeRoute> {
                TeacherHomeScreen(
                    classesVm = classesVm, name = name, subject = subject, bottomPadding = padding, onSignOut = onSignOut,
                    onOpenClass = { nav.navigate(ClassJournalRoute(it.classId, it.subject.orEmpty(), it.className.orEmpty())) },
                    onScan = { nav.navigate(ScanRoute(null)) },
                    onMaterials = { nav.navigate(MaterialsRoute) { launchSingleTop = true } },
                    onCalendar = { nav.navigate(TeacherCalendarRoute) },
                    onAnnouncements = { nav.navigate(TeacherAnnouncementsRoute) },
                )
            }
            composable<JournalRoute> {
                JournalClassesScreen(classesVm, bottomPadding = padding, onOpenClass = { nav.navigate(ClassJournalRoute(it.classId, it.subject.orEmpty(), it.className.orEmpty())) })
            }
            composable<DiaryRoute> { TeacherDiaryScreen(classesVm, teacherId = teacherId, bottomPadding = padding) }
            composable<MaterialsRoute> { MaterialsScreen(bottomPadding = padding, onBack = null, onOpenResults = { nav.navigate(ResultsRoute(it)) }) }

            composable<ClassJournalRoute> { e ->
                val r = e.toRoute<ClassJournalRoute>()
                ClassJournalScreen(r.classId, r.subject, r.className, onBack = { nav.popBackStack() }, onScan = { nav.navigate(ScanRoute(r.classId)) })
            }
            composable<ScanRoute> { e -> ScanJournalScreen(classesVm, e.toRoute<ScanRoute>().classId, onBack = { nav.popBackStack() }) }
            composable<ResultsRoute> { e -> ResultsScreen(e.toRoute<ResultsRoute>().assignmentId, onBack = { nav.popBackStack() }) }
            composable<TeacherCalendarRoute> { TeacherCalendarScreen(onBack = { nav.popBackStack() }) }
            composable<TeacherAnnouncementsRoute> { TeacherAnnouncementsScreen(onBack = { nav.popBackStack() }) }
        }
    }
}

@Composable
private fun DirectorGraph(name: String, onSignOut: () -> Unit) {
    val nav = rememberNavController()
    val liveVm: LiveViewModel = koinViewModel()
    val schoolVm: SchoolViewModel = koinViewModel()

    MainShell(nav, directorTabs) { padding ->
        NavHost(
            nav,
            startDestination = HomeRoute,
            modifier = Modifier.fillMaxSize(),
            enterTransition = { slideInHorizontally(tween(300)) { it / 4 } + fadeIn(tween(300)) },
            exitTransition = { fadeOut(tween(180)) },
            popEnterTransition = { fadeIn(tween(220)) },
            popExitTransition = { slideOutHorizontally(tween(240)) { it / 4 } + fadeOut(tween(180)) },
        ) {
            composable<HomeRoute> {
                DirectorHomeScreen(
                    liveVm = liveVm, name = name, bottomPadding = padding, onSignOut = onSignOut,
                    onVideo = { nav.navigate(LiveVideoRoute) },
                    onClasses = { nav.navigate(ClassesRoute) },
                    onStudents = { nav.navigate(StudentsRoute) },
                    onTeachers = { nav.navigate(TeachersRoute) },
                    onCameras = { nav.navigate(CamerasRoute) },
                    onAnnouncements = { nav.navigate(DirectorAnnouncementsRoute) },
                    onCalendar = { nav.navigate(DirectorCalendarRoute) },
                    onSettings = { nav.navigate(SettingsRoute) },
                )
            }
            composable<LiveRoute> { LiveAttendanceScreen(liveVm, bottomPadding = padding) }
            composable<SchoolRoute> {
                SchoolHubScreen(
                    schoolVm, bottomPadding = padding,
                    onClasses = { nav.navigate(ClassesRoute) }, onStudents = { nav.navigate(StudentsRoute) },
                    onTeachers = { nav.navigate(TeachersRoute) }, onCameras = { nav.navigate(CamerasRoute) },
                )
            }
            composable<AnalyticsRoute> { DirectorAnalyticsScreen(schoolVm, bottomPadding = padding) }

            composable<LiveVideoRoute> { LiveVideoScreen(onBack = { nav.popBackStack() }) }
            composable<ClassesRoute> { ClassesScreen(schoolVm, onBack = { nav.popBackStack() }, onOpen = { nav.navigate(ClassDetailRoute(it.id, it.name, it.grade)) }) }
            composable<ClassDetailRoute> { e ->
                val r = e.toRoute<ClassDetailRoute>()
                ClassDetailScreen(ClassDto(r.classId, r.name, r.grade), schoolVm, onBack = { nav.popBackStack() })
            }
            composable<StudentsRoute> { StudentsScreen(schoolVm, onBack = { nav.popBackStack() }) }
            composable<TeachersRoute> { TeachersScreen(schoolVm, onBack = { nav.popBackStack() }) }
            composable<CamerasRoute> { CamerasScreen(schoolVm, liveVm, onBack = { nav.popBackStack() }) }
            composable<DirectorAnnouncementsRoute> { DirectorAnnouncementsScreen(schoolVm, onBack = { nav.popBackStack() }) }
            composable<DirectorCalendarRoute> { DirectorCalendarScreen(schoolVm, onBack = { nav.popBackStack() }) }
            composable<SettingsRoute> { SettingsScreen(onBack = { nav.popBackStack() }) }
        }
    }
}
