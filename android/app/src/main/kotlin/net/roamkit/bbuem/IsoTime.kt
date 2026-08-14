package net.roamkit.bbuem

import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

object IsoTime {
    fun parseMillis(raw: String): Long? {
        val core =
            raw.trim()
                .removeSuffix("Z")
                .substringBefore("+")
                .substringBefore(".")
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
            sdf.timeZone = TimeZone.getTimeZone("UTC")
            sdf.parse(core)?.time
        } catch (_: Exception) {
            null
        }
    }

    fun nowIso(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        sdf.timeZone = TimeZone.getTimeZone("UTC")
        return sdf.format(System.currentTimeMillis())
    }
}
