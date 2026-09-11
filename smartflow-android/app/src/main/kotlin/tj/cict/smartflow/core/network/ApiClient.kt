package tj.cict.smartflow.core.network

import java.util.concurrent.TimeUnit
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import tj.cict.smartflow.BuildConfig
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.api.PublicApi

/** Attaches the parent's bearer token to every request that has one. */
class AuthInterceptor(private val session: SessionStore) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val token = runBlocking { session.token() }
        val request = if (token.isNullOrEmpty()) chain.request() else {
            chain.request().newBuilder().header("Authorization", "Bearer $token").build()
        }
        return chain.proceed(request)
    }
}

object ApiClient {
    val json: Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        explicitNulls = false
    }

    fun okHttp(session: SessionStore): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .addInterceptor(AuthInterceptor(session))
        .apply {
            if (BuildConfig.DEBUG) {
                addInterceptor(HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BASIC })
            }
        }
        .build()

    fun publicApi(client: OkHttpClient): PublicApi = Retrofit.Builder()
        .baseUrl(BuildConfig.PUBLIC_SERVER_URL)
        .client(client)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()
        .create(PublicApi::class.java)
}
