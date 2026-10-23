package co.munyati.core.dates

import android.icu.text.DateFormat
import android.icu.util.GregorianCalendar
import android.icu.util.TimeZone
import java.time.Instant
import java.time.OffsetDateTime
import java.util.Locale

/**
 * Dates on screen use the Gregorian calendar in every language (a Saudi region would otherwise
 * default to Umm al-Qura). Month names and digits still follow the user's language. Same rule as
 * iOS `Calendar.display`.
 */
object DisplayDates {
    enum class Style(internal val icu: Int) { None(DateFormat.NONE), Short(DateFormat.SHORT), Medium(DateFormat.MEDIUM), Long(DateFormat.LONG) }

    fun format(instant: Instant, date: Style, time: Style = Style.None, locale: Locale = Locale.getDefault()): String {
        val calendar = GregorianCalendar(TimeZone.getDefault(), locale)
        val format = when {
            time == Style.None -> DateFormat.getDateInstance(calendar, date.icu, locale)
            date == Style.None -> DateFormat.getTimeInstance(calendar, time.icu, locale)
            else -> DateFormat.getDateTimeInstance(calendar, date.icu, time.icu, locale)
        }
        return format.format(java.util.Date.from(instant))
    }

    /** A custom ICU pattern ("EEEE d MMMM", "h:mm a") in the display calendar. */
    fun pattern(instant: Instant, skeleton: String, locale: Locale = Locale.getDefault()): String {
        val format = DateFormat.getInstanceForSkeleton(GregorianCalendar(TimeZone.getDefault(), locale), skeleton, locale)
        return format.format(java.util.Date.from(instant))
    }
}

/**
 * Postgres `timestamptz` JSON: ISO 8601 with or without fractional seconds
 * ("2026-10-13T15:00:00+00:00", "2026-10-13T15:00:00.123456+00:00").
 */
object PostgresDate {
    fun parse(value: String?): Instant? =
        value?.let { runCatching { OffsetDateTime.parse(it.replace(' ', 'T')).toInstant() }.getOrNull() }
}
