package tj.cict.smartflow.data.repo

import tj.cict.smartflow.core.network.ApiError
import tj.cict.smartflow.core.network.ApiResult
import tj.cict.smartflow.core.network.safeCall
import tj.cict.smartflow.core.session.Role
import tj.cict.smartflow.core.session.Session
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.api.PublicApi
import tj.cict.smartflow.data.dto.LoginRequest
import tj.cict.smartflow.data.dto.LoginResponse
import tj.cict.smartflow.data.dto.PhoneRequest
import tj.cict.smartflow.data.dto.RequestCodeResponse
import tj.cict.smartflow.data.dto.SetPasswordRequest
import tj.cict.smartflow.data.dto.StudentLoginRequest
import tj.cict.smartflow.data.dto.VerifyCodeRequest
import tj.cict.smartflow.data.dto.VerifyCodeResponse

sealed interface LoginOutcome {
    data object SignedIn : LoginOutcome
    /** Registered before passwords existed -- send them to pick one. */
    data class NeedsPassword(val phone: String) : LoginOutcome
}

/** Parent and pupil sign-in, against the Public Server. */
class AuthRepository(private val api: PublicApi, private val session: SessionStore) {

    suspend fun login(phone: String, password: String?): ApiResult<LoginOutcome> {
        val result = safeCall { api.login(LoginRequest(phone, password?.takeIf { it.isNotBlank() })) }
        return when (result) {
            is ApiResult.Err -> result
            is ApiResult.Ok -> {
                val body = result.value
                if (body.status == "needs_password") {
                    ApiResult.Ok(LoginOutcome.NeedsPassword(body.phone ?: phone))
                } else {
                    persist(body, phone)?.let { ApiResult.Ok(LoginOutcome.SignedIn) }
                        ?: ApiResult.Err(ApiError.Unknown(null))
                }
            }
        }
    }

    suspend fun loginStudent(username: String, password: String): ApiResult<Unit> {
        val result = safeCall { api.studentLogin(StudentLoginRequest(username.trim(), password)) }
        return when (result) {
            is ApiResult.Err -> result
            is ApiResult.Ok -> {
                val b = result.value
                session.save(Session(b.accessToken, Role.STUDENT, b.studentId, b.fullName.orEmpty(), username.trim(), b.className))
                ApiResult.Ok(Unit)
            }
        }
    }

    suspend fun requestCode(phone: String): ApiResult<RequestCodeResponse> =
        safeCall { api.requestCode(PhoneRequest(phone)) }

    suspend fun verifyCode(phone: String, code: String): ApiResult<VerifyCodeResponse> =
        safeCall { api.verifyCode(VerifyCodeRequest(phone, code)) }

    suspend fun setPassword(setupToken: String, fullName: String, password: String): ApiResult<Unit> {
        val result = safeCall { api.setPassword(SetPasswordRequest(setupToken, fullName, password)) }
        return when (result) {
            is ApiResult.Err -> result
            is ApiResult.Ok -> persist(result.value, result.value.phone.orEmpty())?.let { ApiResult.Ok(Unit) }
                ?: ApiResult.Err(ApiError.Unknown(null))
        }
    }

    suspend fun logout() = session.clear()

    private suspend fun persist(body: LoginResponse, phone: String): Session? {
        val token = body.accessToken ?: return null
        val parentId = body.parentId ?: return null
        val s = Session(token, Role.PARENT, parentId, body.fullName.orEmpty(), body.phone ?: phone)
        session.save(s)
        return s
    }
}
