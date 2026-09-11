package tj.cict.smartflow.core.session

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "session")

enum class Role { PARENT, STUDENT, TEACHER, DIRECTOR }

data class Session(
    val token: String,
    val role: Role,
    /** Parent id for a parent, the pupil's own id for a student. */
    val ownerId: Int,
    val fullName: String,
    /** Phone for a parent, username for a student. */
    val login: String,
    val className: String? = null,
    /** School-server base URL for roles that talk to the LAN server. */
    val serverUrl: String? = null,
)

/** Whoever is signed in, persisted across launches. */
class SessionStore(private val context: Context) {
    private object Keys {
        val token = stringPreferencesKey("token")
        val role = stringPreferencesKey("role")
        val ownerId = intPreferencesKey("owner_id")
        val fullName = stringPreferencesKey("full_name")
        val login = stringPreferencesKey("login")
        val className = stringPreferencesKey("class_name")
        val selectedChild = intPreferencesKey("selected_child")
        val serverUrl = stringPreferencesKey("server_url")
        val lastServerUrl = stringPreferencesKey("last_server_url")
        val onboarded = booleanPreferencesKey("onboarded")
    }

    val onboarded: Flow<Boolean> = context.dataStore.data.map { it[Keys.onboarded] ?: false }

    suspend fun markOnboarded() {
        context.dataStore.edit { it[Keys.onboarded] = true }
    }

    val session: Flow<Session?> = context.dataStore.data.map { prefs ->
        val token = prefs[Keys.token] ?: return@map null
        val ownerId = prefs[Keys.ownerId] ?: return@map null
        Session(
            token = token,
            role = runCatching { Role.valueOf(prefs[Keys.role] ?: "PARENT") }.getOrDefault(Role.PARENT),
            ownerId = ownerId,
            fullName = prefs[Keys.fullName].orEmpty(),
            login = prefs[Keys.login].orEmpty(),
            className = prefs[Keys.className],
            serverUrl = prefs[Keys.serverUrl],
        )
    }

    /** The last school-server address that answered, kept across sign-outs. */
    suspend fun lastServerUrl(): String? = context.dataStore.data.first()[Keys.lastServerUrl]

    suspend fun rememberServerUrl(url: String) {
        context.dataStore.edit { it[Keys.lastServerUrl] = url }
    }

    /** Read once per request by the school-server interceptor. */
    suspend fun serverUrl(): String? = context.dataStore.data.first().let { it[Keys.serverUrl] ?: it[Keys.lastServerUrl] }

    val selectedChildId: Flow<Int?> = context.dataStore.data.map { it[Keys.selectedChild] }

    /** Read once, off the flow, for the interceptor. */
    suspend fun token(): String? = context.dataStore.data.first()[Keys.token]

    suspend fun current(): Session? = session.first()

    suspend fun save(session: Session) {
        context.dataStore.edit { prefs ->
            prefs[Keys.token] = session.token
            prefs[Keys.role] = session.role.name
            prefs[Keys.ownerId] = session.ownerId
            prefs[Keys.fullName] = session.fullName
            prefs[Keys.login] = session.login
            session.className?.let { prefs[Keys.className] = it } ?: prefs.remove(Keys.className)
            session.serverUrl?.let { prefs[Keys.serverUrl] = it; prefs[Keys.lastServerUrl] = it } ?: prefs.remove(Keys.serverUrl)
        }
    }

    /** The school server moved (LAN <-> relay) while signed in. */
    suspend fun updateServerUrl(url: String) {
        context.dataStore.edit { it[Keys.serverUrl] = url; it[Keys.lastServerUrl] = url }
    }

    suspend fun rememberChild(id: Int) {
        context.dataStore.edit { it[Keys.selectedChild] = id }
    }

    suspend fun clear() {
        context.dataStore.edit { prefs ->
            val keep = prefs[Keys.lastServerUrl]
            val onboarded = prefs[Keys.onboarded]
            prefs.clear()
            keep?.let { prefs[Keys.lastServerUrl] = it }
            onboarded?.let { prefs[Keys.onboarded] = it }
        }
    }
}
