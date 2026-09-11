package tj.cict.smartflow.di

import org.koin.android.ext.koin.androidContext
import org.koin.core.module.dsl.viewModel
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.module
import tj.cict.smartflow.core.network.ApiClient
import tj.cict.smartflow.core.network.SchoolApiClient
import org.koin.core.qualifier.named
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.repo.AuthRepository
import tj.cict.smartflow.data.repo.ParentRepository
import tj.cict.smartflow.data.repo.DirectorRepository
import tj.cict.smartflow.data.repo.TeacherRepository
import tj.cict.smartflow.ui.director.ClassDetailViewModel
import tj.cict.smartflow.ui.director.DirectorAnalyticsViewModel
import tj.cict.smartflow.ui.director.DirectorNoticesViewModel
import tj.cict.smartflow.ui.director.LiveVideoViewModel
import tj.cict.smartflow.ui.director.LiveViewModel
import tj.cict.smartflow.ui.director.PositionsViewModel
import tj.cict.smartflow.ui.director.SchoolViewModel
import tj.cict.smartflow.ui.director.SettingsViewModel
import tj.cict.smartflow.ui.teacher.ClassJournalViewModel
import tj.cict.smartflow.ui.teacher.MaterialsViewModel
import tj.cict.smartflow.ui.teacher.ResultsViewModel
import tj.cict.smartflow.ui.teacher.ScanJournalViewModel
import tj.cict.smartflow.ui.teacher.SchoolInfoViewModel
import tj.cict.smartflow.ui.teacher.TeacherClassesViewModel
import tj.cict.smartflow.ui.teacher.TeacherDiaryViewModel
import tj.cict.smartflow.ui.achievements.AchievementsViewModel
import tj.cict.smartflow.ui.alerts.AlertsViewModel
import tj.cict.smartflow.ui.assignments.PlayerViewModel
import tj.cict.smartflow.ui.announcements.AnnouncementsViewModel
import tj.cict.smartflow.ui.assignments.AssignmentsViewModel
import tj.cict.smartflow.ui.attendance.AttendanceViewModel
import tj.cict.smartflow.ui.auth.AuthViewModel
import tj.cict.smartflow.ui.calendar.CalendarViewModel
import tj.cict.smartflow.ui.diary.DiaryViewModel
import tj.cict.smartflow.ui.grades.GradesViewModel
import tj.cict.smartflow.ui.home.ChildrenViewModel
import tj.cict.smartflow.ui.homework.HomeworkViewModel
import tj.cict.smartflow.ui.navigation.SessionViewModel
import tj.cict.smartflow.ui.rating.RatingViewModel

val appModule = module {
    single { SessionStore(androidContext()) }
    single { ApiClient.okHttp(get()) }
    single { ApiClient.publicApi(get()) }
    single { AuthRepository(get(), get()) }
    single { ParentRepository(get(), get()) }
    single(named("school")) { SchoolApiClient.okHttp(get()) }
    single { SchoolApiClient.api(get(named("school"))) }
    single { TeacherRepository(get(), get()) }
    single { DirectorRepository(get(), get()) }

    viewModelOf(::SessionViewModel)
    viewModelOf(::AuthViewModel)
    viewModelOf(::ChildrenViewModel)
    viewModelOf(::AttendanceViewModel)
    viewModelOf(::GradesViewModel)
    viewModelOf(::DiaryViewModel)
    viewModelOf(::HomeworkViewModel)
    viewModelOf(::AssignmentsViewModel)
    viewModelOf(::CalendarViewModel)
    viewModelOf(::AnnouncementsViewModel)
    viewModelOf(::AlertsViewModel)
    viewModelOf(::RatingViewModel)
    viewModelOf(::AchievementsViewModel)
    viewModelOf(::PlayerViewModel)
    viewModelOf(::TeacherClassesViewModel)
    viewModelOf(::ClassJournalViewModel)
    viewModelOf(::TeacherDiaryViewModel)
    viewModelOf(::ScanJournalViewModel)
    viewModelOf(::MaterialsViewModel)
    viewModelOf(::ResultsViewModel)
    viewModelOf(::SchoolInfoViewModel)
    viewModelOf(::LiveViewModel)
    viewModel { LiveVideoViewModel(get(), get(named("school"))) }
    viewModelOf(::SchoolViewModel)
    viewModelOf(::ClassDetailViewModel)
    viewModelOf(::SettingsViewModel)
    viewModelOf(::PositionsViewModel)
    viewModelOf(::DirectorAnalyticsViewModel)
    viewModelOf(::DirectorNoticesViewModel)
}
