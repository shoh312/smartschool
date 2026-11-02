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
    /** Email (director / teacher), phone number (parent) or username (pupil). */
    val ident: String = "",
    val password: String = "",
    val busy: Boolean = false,
    val error: ApiError? = null,
    /** School-server lookup, needed once the login looks like an email. */
    val serverUrl: String? = null,
    val serverSearching: Boolean = false,
) {
    val kind: LoginKind get() = loginKindOf(ident)
}

enum class LoginKind { STAFF, PARENT, STUDENT }

/** No role tabs: an email is staff, a phone number a parent, anything else a pupil's username. */
fun loginKindOf(ident: String): LoginKind {
    val v = ident.trim()
    return when {
        '@' in v -> LoginKind.STAFF
        Regex("""^\+?[\d\s()-]{7,}$""").matches(v) -> LoginKind.PARENT
        else -> LoginKind.STUDENT
    }
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

    fun onIdent(v: String) {
        _login.update { it.copy(ident = v, error = null) }
        // Start finding the school server as soon as it is clearly staff.
        val ui = _login.value
        if (ui.kind == LoginKind.STAFF && ui.serverUrl == null && !ui.serverSearching) findServer()
    }
    fun onPassword(v: String) = _login.update { it.copy(password = v, error = null) }

    fun findServer() {
        _login.update { it.copy(serverSearching = true) }
        viewModelScope.launch {
            val url = teachers.resolveServer()
            _login.update { it.copy(serverSearching = false, serverUrl = url) }
        }
    }

    fun submit(onNeedsPassword: (String) -> Unit) {
        val ui = _login.value
        if (ui.busy || ui.ident.isBlank() || ui.password.isEmpty()) return
        _login.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            val r = when (ui.kind) {
                LoginKind.STAFF -> staffLogin(ui)
                LoginKind.STUDENT -> repo.loginStudent(ui.ident.trim(), ui.password)
                LoginKind.PARENT -> when (val p = repo.login(ui.ident.digits(), ui.password)) {
                    is ApiResult.Ok -> {
                        if (p.value is LoginOutcome.NeedsPassword) onNeedsPassword((p.value as LoginOutcome.NeedsPassword).phone)
                        ApiResult.Ok(Unit)
                    }
                    // A pupil's username can be all digits -- not a parent, try that.
                    is ApiResult.Err -> if ((p.error as? ApiError.Detail)?.code == "phone_not_registered") {
                        repo.loginStudent(ui.ident.trim(), ui.password).let { s -> if (s is ApiResult.Err) p else s }
                    } else p
                }
            }
            when (r) {
                is ApiResult.Ok -> _login.update { it.copy(busy = false) } // session flow flips the graph
                is ApiResult.Err -> _login.update { it.copy(busy = false, error = r.error.asLoginError()) }
            }
        }
    }

    private suspend fun staffLogin(ui: LoginUi): ApiResult<Unit> {
        // Discovery runs quietly while typing; one more try if it has not finished.
        val server = ui.serverUrl ?: teachers.resolveServer().also { url -> _login.update { it.copy(serverUrl = url) } }
            ?: return ApiResult.Err(ApiError.Detail("school_not_found", 0))
        val email = ui.ident.trim()
        val r = teachers.staffLogin(email, ui.password, server)
        // School server not updated yet: no single staff login there.
        if (r !is ApiResult.Err || (r.error as? ApiError.Detail)?.status != 404) return r
        val d = directors.login(email, ui.password, server)
        return if (d is ApiResult.Err && d.error == ApiError.Unauthorized) teachers.login(email, ui.password, server) else d
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

/** On a sign-in screen a 401 is a wrong password, not an expired session. */
private fun ApiError.asLoginError(): ApiError = if (this == ApiError.Unauthorized) ApiError.Detail("wrong_credentials", 401) else this
