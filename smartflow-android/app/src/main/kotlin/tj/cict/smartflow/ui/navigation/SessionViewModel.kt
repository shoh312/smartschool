package tj.cict.smartflow.ui.navigation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import tj.cict.smartflow.core.session.Session
import tj.cict.smartflow.core.session.Role
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.repo.TeacherRepository

sealed interface SessionState {
    data object Loading : SessionState
    /** First launch, nobody signed in: the language and intro pages. */
    data object Onboarding : SessionState
    data object SignedOut : SessionState
    data class SignedIn(val session: Session) : SessionState
}

/** Who is signed in. The navigation graph is a function of this. */
class SessionViewModel(private val store: SessionStore, private val teachers: TeacherRepository) : ViewModel() {
    val state: StateFlow<SessionState> = combine(store.session, store.onboarded) { session, onboarded ->
        when {
            session != null -> SessionState.SignedIn(session)
            !onboarded -> SessionState.Onboarding
            else -> SessionState.SignedOut
        }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, SessionState.Loading)

    fun finishOnboarding() {
        viewModelScope.launch { store.markOnboarded() }
    }

    /**
     * A teacher or director who signed in on the school Wi-Fi and reopens the
     * app on mobile data (or the other way round) keeps their token, but the
     * address it was issued against is now wrong. Re-run the search on every
     * launch and quietly repoint the session -- the LAN wins when it answers.
     */
    fun refreshSchoolServer() {
        viewModelScope.launch {
            val s = store.current() ?: return@launch
            if (s.role != Role.TEACHER && s.role != Role.DIRECTOR) return@launch
            val url = teachers.resolveServer() ?: return@launch
            if (url != s.serverUrl) store.updateServerUrl(url)
        }
    }

    fun signOut() {
        viewModelScope.launch { store.clear() }
    }
}
