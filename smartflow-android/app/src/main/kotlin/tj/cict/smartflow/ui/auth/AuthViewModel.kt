package tj.cict.smartflow.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.data.repo.AuthRepository
import tj.cict.smartflow.data.repo.LoginOutcome
import tj.cict.smartflow.data.repo.DirectorRepository
import tj.cict.smartflow.data.repo.TeacherRepository

data class LoginUi(
    val phone: String = "+992 ",
    val password: String = "",
    val busy: Boolean = false,
    val error: ApiError? = null,
    /** Which tab of the sign-in card is showing: 0 parent, 1 student, 2 teacher. */
    val tab: Int = 0,
    val username: String = "",
    val studentPassword: String = "",
    val email: String = "",
    val teacherPassword: String = "",
    /** School-server lookup, teacher tab only. */
    val serverUrl: String? = null,
    val serverSearching: Boolean = false,
) {
    val student: Boolean get() = tab == 1
    val teacher: Boolean get() = tab == 2
    val director: Boolean get() = tab == 3
    /** Teacher and director both sign in against the school server. */
    val school: Boolean get() = tab >= 2
}

data class VerifyUi(
    val code: String = "",
    val busy: Boolean = false,
    val sending: Boolean = false,
    val delivered: Boolean = true,
    val phoneMasked: String = "",
    val resendIn: Int = 0,
    val error: ApiError? = null,
)

data class SetupUi(
    val name: String = "",
    val password: String = "",
    val busy: Boolean = false,
    val error: ApiError? = null,
)

/** One view-model for the three sign-in screens; state per screen. */
class AuthViewModel(private val repo: AuthRepository, private val teachers: TeacherRepository, private val directors: DirectorRepository) : ViewModel() {

    private val _login = MutableStateFlow(LoginUi())
    val login: StateFlow<LoginUi> = _login.asStateFlow()

    private val _verify = MutableStateFlow(VerifyUi())
    val verify: StateFlow<VerifyUi> = _verify.asStateFlow()

    private val _setup = MutableStateFlow(SetupUi())
    val setup: StateFlow<SetupUi> = _setup.asStateFlow()

    private var countdown: Job? = null

    // ------------------------------------------------------------ login

    fun onPhone(v: String) = _login.update { it.copy(phone = v, error = null) }
    fun onPassword(v: String) = _login.update { it.copy(password = v, error = null) }

    fun setTab(tab: Int) {
        _login.update { it.copy(tab = tab, error = null) }
        if (tab >= 2 && _login.value.serverUrl == null && !_login.value.serverSearching) findServer()
    }

    fun onEmail(v: String) = _login.update { it.copy(email = v, error = null) }
    fun onTeacherPassword(v: String) = _login.update { it.copy(teacherPassword = v, error = null) }

    fun findServer() {
        _login.update { it.copy(serverSearching = true) }
        viewModelScope.launch {
            val url = teachers.resolveServer()
            _login.update { it.copy(serverSearching = false, serverUrl = url) }
        }
    }

    fun submitTeacherLogin() {
        val ui = _login.value
        if (ui.busy || ui.email.isBlank()) return
        _login.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            // Discovery runs quietly when the tab opens; if it has not found
            // the server yet (or failed), one more try before giving up.
            val server = ui.serverUrl ?: teachers.resolveServer().also { url -> _login.update { it.copy(serverUrl = url) } }
            if (server == null) {
                _login.update { it.copy(busy = false, error = ApiError.Detail("school_not_found", 0)) }
                return@launch
            }
            val r = if (ui.director) directors.login(ui.email, ui.teacherPassword, server) else teachers.login(ui.email, ui.teacherPassword, server)
            when (r) {
                is ApiResult.Ok -> _login.update { it.copy(busy = false) }
                is ApiResult.Err -> _login.update { it.copy(busy = false, error = r.error) }
            }
        }
    }
    fun onUsername(v: String) = _login.update { it.copy(username = v, error = null) }
    fun onStudentPassword(v: String) = _login.update { it.copy(studentPassword = v, error = null) }

    fun submitStudentLogin() {
        val ui = _login.value
        if (ui.busy || ui.username.isBlank()) return
        _login.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.loginStudent(ui.username, ui.studentPassword)) {
                is ApiResult.Ok -> _login.update { it.copy(busy = false) }
                is ApiResult.Err -> _login.update { it.copy(busy = false, error = r.error) }
            }
        }
    }

    fun submitLogin(onNeedsPassword: (String) -> Unit) {
        val ui = _login.value
        if (ui.busy) return
        val phone = ui.phone.digits()
        if (phone.length < 9) return
        _login.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.login(phone, ui.password)) {
                is ApiResult.Ok -> {
                    _login.update { it.copy(busy = false) }
                    when (val o = r.value) {
                        LoginOutcome.SignedIn -> Unit // session flow flips the graph
                        is LoginOutcome.NeedsPassword -> onNeedsPassword(o.phone)
                    }
                }
                is ApiResult.Err -> _login.update { it.copy(busy = false, error = r.error) }
            }
        }
    }

    // ----------------------------------------------------------- verify

    fun onCode(v: String) = _verify.update { it.copy(code = v.filter(Char::isDigit).take(6), error = null) }

    fun requestCode(phone: String) {
        if (_verify.value.sending || _verify.value.resendIn > 0) return
        _verify.update { it.copy(sending = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.requestCode(phone)) {
                is ApiResult.Ok -> {
                    _verify.update { it.copy(sending = false, delivered = r.value.delivered, phoneMasked = r.value.phoneMasked) }
                    startCountdown(60)
                }
                is ApiResult.Err -> _verify.update { it.copy(sending = false, error = r.error) }
            }
        }
    }

    fun submitCode(phone: String, onVerified: (setupToken: String, fullName: String) -> Unit) {
        val ui = _verify.value
        if (ui.busy || ui.code.length < 6) return
        _verify.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.verifyCode(phone, ui.code)) {
                is ApiResult.Ok -> {
                    _verify.update { it.copy(busy = false) }
                    onVerified(r.value.setupToken, r.value.fullName.orEmpty())
                }
                is ApiResult.Err -> _verify.update { it.copy(busy = false, error = r.error) }
            }
        }
    }

    private fun startCountdown(seconds: Int) {
        countdown?.cancel()
        countdown = viewModelScope.launch {
            var left = seconds
            while (left > 0) {
                _verify.update { it.copy(resendIn = left) }
                delay(1000)
                left--
            }
            _verify.update { it.copy(resendIn = 0) }
        }
    }

    // ------------------------------------------------------------ setup

    fun onName(v: String) = _setup.update { it.copy(name = v, error = null) }
    fun onNewPassword(v: String) = _setup.update { it.copy(password = v, error = null) }
    fun seedName(name: String) {
        if (_setup.value.name.isEmpty() && name.isNotBlank()) _setup.update { it.copy(name = name) }
    }

    fun submitSetup(setupToken: String) {
        val ui = _setup.value
        if (ui.busy) return
        if (ui.password.length < 4) {
            _setup.update { it.copy(error = ApiError.Detail("password_too_short", 400)) }
            return
        }
        _setup.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            when (val r = repo.setPassword(setupToken, ui.name.trim(), ui.password)) {
                is ApiResult.Ok -> _setup.update { it.copy(busy = false) }
                is ApiResult.Err -> _setup.update { it.copy(busy = false, error = r.error) }
            }
        }
    }
}

/** What the server keys parents by: digits only. */
fun String.digits(): String = filter(Char::isDigit)
