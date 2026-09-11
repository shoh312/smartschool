package tj.cict.smartflow.core.network

import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketTimeoutException
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import tj.cict.smartflow.BuildConfig
import tj.cict.smartflow.core.session.SessionStore
import tj.cict.smartflow.data.api.SchoolApi

/**
 * Finding the school server on the LAN. Same protocol the Flutter app and
 * the server's `discovery.py` speak: one UDP broadcast, one reply naming
 * the API port. The sender's address is the server's address.
 */
object SchoolDiscovery {
    /**
     * Reachability checks must hit the address they are given. The school
     * API client rewrites every request's host to the saved server address
     * (see [SchoolHostInterceptor]) -- probing the relay through it would
     * silently probe the old LAN address instead and always fail off-site.
     */
    val probeClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(4, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build()

    const val PORT = 8734
    private const val REQUEST = "SMARTSCHOOL_DISCOVER_V1"
    private const val REPLY_PREFIX = "SMARTSCHOOL_HERE:"
    const val DEFAULT_URL = "http://192.168.0.124:8080/"

    /**
     * The school server through the Public Server's tunnel. The school box
     * keeps one websocket open to the public one, which answers for it under
     * /relay -- so this works from anywhere with internet, just slower.
     */
    const val RELAY_URL = BuildConfig.PUBLIC_SERVER_URL + "relay/"

    suspend fun broadcast(timeoutMs: Long = 2500): String? = withContext(Dispatchers.IO) {
        runCatching {
            DatagramSocket().use { socket ->
                socket.broadcast = true
                socket.soTimeout = timeoutMs.toInt()
                val payload = REQUEST.toByteArray()
                socket.send(DatagramPacket(payload, payload.size, InetAddress.getByName("255.255.255.255"), PORT))
                val buffer = ByteArray(256)
                val packet = DatagramPacket(buffer, buffer.size)
                try {
                    socket.receive(packet)
                } catch (_: SocketTimeoutException) {
                    return@use null
                }
                val text = String(packet.data, 0, packet.length).trim()
                if (!text.startsWith(REPLY_PREFIX)) return@use null
                val port = text.removePrefix(REPLY_PREFIX).toIntOrNull() ?: return@use null
                "http://${packet.address.hostAddress}:$port/"
            }
        }.getOrNull()
    }

    /** True if something at [url] answers like the school server. */
    suspend fun isReachable(client: OkHttpClient, url: String, timeoutMs: Long = 3000): Boolean = withContext(Dispatchers.IO) {
        withTimeoutOrNull(timeoutMs) {
            runCatching {
                client.newCall(Request.Builder().url(url).build()).execute().use { r ->
                    r.isSuccessful && (r.body?.string()?.contains("SmartSchool Backend") == true)
                }
            }.getOrDefault(false)
        } ?: false
    }

    /**
     * Saved LAN address first (fast, no broadcast when it still answers),
     * then the broadcast, then the compiled-in LAN fallback, and only then
     * the relay. A saved *relay* address is not trusted first: it answers
     * from anywhere, so it would pin a phone to the slow path even on the
     * school Wi-Fi -- the LAN is always asked again before it.
     */
    suspend fun resolve(client: OkHttpClient, saved: String?): String? {
        if (saved != null && saved != RELAY_URL && isReachable(client, saved)) return saved
        broadcast()?.let { if (isReachable(client, it)) return it }
        if (isReachable(client, DEFAULT_URL)) return DEFAULT_URL
        if (isReachable(client, RELAY_URL, timeoutMs = 8000)) return RELAY_URL
        return null
    }

    fun normalise(input: String): String? {
        var s = input.trim()
        if (s.isEmpty()) return null
        if (!s.startsWith("http")) s = "http://$s"
        if (!s.endsWith("/")) s += "/"
        return s.toHttpUrlOrNull()?.toString()
    }
}

/**
 * Retrofit needs a base URL at build time; the school server's is only
 * known at run time. Every request is built against a placeholder host and
 * this swaps in whatever address the session holds.
 */
class SchoolHostInterceptor(private val session: SessionStore) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val target = runBlocking { session.serverUrl() }?.toHttpUrlOrNull()
            ?: return chain.proceed(chain.request())
        val original = chain.request().url
        // The target may carry a path prefix (the relay lives under /relay/),
        // so the request path is appended to it rather than replacing it.
        val builder = target.newBuilder()
        // "http://h/relay/" parses to segments ["relay", ""]; the empty tail
        // would otherwise become a double slash in the middle of the path.
        if (target.encodedPathSegments.lastOrNull() == "") builder.removePathSegment(target.encodedPathSegments.size - 1)
        original.encodedPathSegments.filter { it.isNotEmpty() }.forEach { builder.addEncodedPathSegment(it) }
        builder.encodedQuery(original.encodedQuery)
        return chain.proceed(chain.request().newBuilder().url(builder.build()).build())
    }
}

/**
 * Calls that wait on Gemini (drafting a material, reading a journal page)
 * take minutes, not seconds. They carry a marker header and get a long read
 * timeout; everything else keeps the short one so a dead LAN fails fast.
 */
const val LONG_TIMEOUT_HEADER = "X-Long-Timeout"

class LongTimeoutInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        if (request.header(LONG_TIMEOUT_HEADER) == null) return chain.proceed(request)
        return chain.withReadTimeout(360, TimeUnit.SECONDS).withWriteTimeout(120, TimeUnit.SECONDS)
            .proceed(request.newBuilder().removeHeader(LONG_TIMEOUT_HEADER).build())
    }
}

object SchoolApiClient {
    const val PLACEHOLDER = "http://school.placeholder/"

    fun okHttp(session: SessionStore): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .addInterceptor(SchoolHostInterceptor(session))
        .addInterceptor(AuthInterceptor(session))
        .addInterceptor(LongTimeoutInterceptor())
        .apply {
            if (BuildConfig.DEBUG) addInterceptor(HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BASIC })
        }
        .build()

    fun api(client: OkHttpClient): SchoolApi = Retrofit.Builder()
        .baseUrl(PLACEHOLDER)
        .client(client)
        .addConverterFactory(ApiClient.json.asConverterFactory("application/json".toMediaType()))
        .build()
        .create(SchoolApi::class.java)
}
