package tj.cict.smartflow.core.util

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale
import tj.cict.smartflow.R
import tj.cict.smartflow.core.network.ApiError

/** The locale the app is actually rendering in, not the phone's default. */
@Composable
fun currentLocale(): Locale = LocalConfiguration.current.locales[0] ?: Locale.getDefault()

fun LocalTime.hhmm(): String = format(DateTimeFormatter.ofPattern("HH:mm"))
fun LocalDateTime.hhmm(): String = toLocalTime().hhmm()

fun LocalDate.dayMonth(locale: Locale): String =
    format(DateTimeFormatter.ofPattern("d MMMM", locale))

fun LocalDate.dayMonthYear(locale: Locale): String =
    format(DateTimeFormatter.ofPattern("d MMMM yyyy", locale))

fun LocalDate.monthYear(locale: Locale): String =
    format(DateTimeFormatter.ofPattern("LLLL yyyy", locale)).replaceFirstChar { it.titlecase(locale) }

fun LocalDate.weekdayShort(locale: Locale): String =
    dayOfWeek.getDisplayName(TextStyle.SHORT, locale).replaceFirstChar { it.titlecase(locale) }

fun LocalDate.weekdayLong(locale: Locale): String =
    dayOfWeek.getDisplayName(TextStyle.FULL, locale).replaceFirstChar { it.titlecase(locale) }

fun LocalDateTime.dayMonthTime(locale: Locale): String =
    "${toLocalDate().dayMonth(locale)}, ${hhmm()}"

/** "HH:mm" or "HH:mm:ss" from the diary's start_time string. */
fun parseTime(raw: String): LocalTime? = runCatching { LocalTime.parse(raw.take(8)) }
    .recoverCatching { LocalTime.parse(raw.take(5)) }.getOrNull()

fun formatAverage(value: Double?): String = value?.let { String.format(Locale.US, "%.1f", it) } ?: "—"

@Composable
fun ApiError.message(): String = when (this) {
    ApiError.Network -> stringResource(R.string.error_network)
    ApiError.Unauthorized -> stringResource(R.string.error_session)
    is ApiError.Detail -> when (code) {
        "phone_not_registered" -> stringResource(R.string.error_phone_not_registered)
        "invalid_credentials" -> stringResource(R.string.error_invalid_credentials)
        "too_many_requests", "too_many_attempts" -> stringResource(R.string.error_too_many)
        "code_invalid" -> stringResource(R.string.error_code_invalid)
        "code_expired" -> stringResource(R.string.error_code_expired)
        "code_not_requested" -> stringResource(R.string.error_code_not_requested)
        "code_already_used" -> stringResource(R.string.error_code_expired)
        "password_too_short" -> stringResource(R.string.error_password_short)
        "school_not_found" -> stringResource(R.string.server_not_found)
        "school_offline" -> stringResource(R.string.server_not_found)
        // A sentence rather than a code: the server already said it in words
        // ("this time is taken 14:00-15:00"), so show it as is.
        else -> if (code.contains(' ')) code else stringResource(R.string.error_generic)
    }
    is ApiError.Unknown -> stringResource(R.string.error_generic)
}

/** Digits typed on a number pad, shown as HH:MM -- the colon is not on that keyboard. */
fun formatTimeInput(raw: String): String {
    val d = raw.filter(Char::isDigit).take(4)
    return if (d.length <= 2) d else d.substring(0, 2) + ":" + d.substring(2)
}

/** Same for dates: 20260915 -> 2026-09-15. */
fun formatDateInput(raw: String): String {
    val d = raw.filter(Char::isDigit).take(8)
    return when {
        d.length <= 4 -> d
        d.length <= 6 -> d.substring(0, 4) + "-" + d.substring(4)
        else -> d.substring(0, 4) + "-" + d.substring(4, 6) + "-" + d.substring(6)
    }
}
