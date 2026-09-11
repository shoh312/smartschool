package tj.cict.smartflow.core.network

import java.io.IOException
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import retrofit2.HttpException

/**
 * Every failure a screen can show, named by what the parent should be told
 * rather than by what went wrong on the wire.
 */
sealed class ApiError : Exception() {
    /** No route to the server at all. */
    data object Network : ApiError()
    /** Token rejected -- the session is over. */
    data object Unauthorized : ApiError()
    /** The server explained itself with a `detail` string. */
    data class Detail(val code: String, val status: Int) : ApiError()
    data class Unknown(val reason: Throwable?) : ApiError()
}

sealed interface ApiResult<out T> {
    data class Ok<T>(val value: T) : ApiResult<T>
    data class Err(val error: ApiError) : ApiResult<Nothing>
}

inline fun <T, R> ApiResult<T>.map(transform: (T) -> R): ApiResult<R> = when (this) {
    is ApiResult.Ok -> ApiResult.Ok(transform(value))
    is ApiResult.Err -> this
}

val <T> ApiResult<T>.valueOrNull: T? get() = (this as? ApiResult.Ok)?.value

private val lenientJson = Json { ignoreUnknownKeys = true }

/** Runs one Retrofit call and folds every way it can fail into [ApiError]. */
suspend fun <T> safeCall(block: suspend () -> T): ApiResult<T> = try {
    ApiResult.Ok(block())
} catch (e: HttpException) {
    ApiResult.Err(e.toApiError())
} catch (e: IOException) {
    ApiResult.Err(ApiError.Network)
} catch (e: SerializationException) {
    ApiResult.Err(ApiError.Unknown(e))
}

fun HttpException.toApiError(): ApiError {
    if (code() == 401) return ApiError.Unauthorized
    val body = response()?.errorBody()?.string().orEmpty()
    val detail = runCatching {
        lenientJson.parseToJsonElement(body).jsonObject["detail"]?.jsonPrimitive?.content
    }.getOrNull()
    return if (detail != null) ApiError.Detail(detail, code()) else ApiError.Unknown(this)
}
