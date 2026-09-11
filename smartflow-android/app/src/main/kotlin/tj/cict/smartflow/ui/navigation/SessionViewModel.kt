package tj.cict.smartflow.ui.navigation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import tj.cict.smartflow.core.session.Session
import tj.cict.smartflow.core.session.SessionStore

sealed interface SessionState {
    data object Loading : SessionState
    data object SignedOut : SessionState
    data class SignedIn(val session: Session) : SessionState
}

/** Who is signed in. The navigation graph is a function of this. */
class SessionViewModel(private val store: SessionStore) : ViewModel() {
    val state: StateFlow<SessionState> = store.session
        .map { if (it == null) SessionState.SignedOut else SessionState.SignedIn(it) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, SessionState.Loading)

    fun signOut() {
        viewModelScope.launch { store.clear() }
    }
}
