package net.roamkit.bbuem

import org.json.JSONObject

/** JVM-safe snapshot parse. No Android framework types. */
object WidgetSnapshotParser {
    const val SCHEMA_VERSION = 2

    data class Snapshot(
        val schemaVersion: Int,
        val displayStatus: String,
        val statusLabel: String,
        val activePackageTitle: String?,
        val hasUsage: Boolean,
        val remainingText: String,
        val totalText: String,
        val usedText: String,
        val percent: Int,
        val unlimited: Boolean,
        val coverageAvailable: Boolean,
        val updateUnavailable: Boolean,
    )

    fun parseOrFailSafe(raw: String?): Snapshot {
        if (raw.isNullOrBlank()) {
            return failSafe()
        }
        return try {
            val json = JSONObject(raw)
            val schema = json.optInt("schema_version", json.optInt("schema", -1))
            val status = json.optString("display_status", "")
            if (schema != SCHEMA_VERSION || !isKnownStatus(status)) {
                return failSafe()
            }
            val titleRaw = json.optString("active_package_title", "")
            Snapshot(
                schemaVersion = schema,
                displayStatus = status,
                statusLabel = json.optString("status_label", "UNAVAILABLE"),
                activePackageTitle =
                    titleRaw.takeIf { it.isNotBlank() && it != "null" },
                hasUsage = json.optBoolean("has_usage", false),
                remainingText = json.optString("remaining_text", ""),
                totalText = json.optString("total_text", ""),
                usedText = json.optString("used_text", ""),
                percent = WidgetRingMath.clampPercent(json.optInt("percent", 0)),
                unlimited = json.optBoolean("unlimited", false),
                coverageAvailable = json.optBoolean("coverage_available", false),
                updateUnavailable = json.optBoolean("update_unavailable", false),
            )
        } catch (_: Exception) {
            failSafe()
        }
    }

    fun failSafe(): Snapshot =
        Snapshot(
            schemaVersion = SCHEMA_VERSION,
            displayStatus = "unavailable",
            statusLabel = "UNAVAILABLE",
            activePackageTitle = null,
            hasUsage = false,
            remainingText = "",
            totalText = "",
            usedText = "",
            percent = 0,
            unlimited = false,
            coverageAvailable = false,
            updateUnavailable = false,
        )

    fun isKnownStatus(status: String): Boolean =
        status == "active" ||
            status == "inactive" ||
            status == "expired" ||
            status == "unavailable"

    fun rootRoute(status: String): String =
        when (status) {
            "inactive", "expired" -> "packages"
            "unavailable" -> "refresh"
            "active" -> "home"
            else -> "home"
        }

    fun statusBadge(status: String, label: String): String {
        val glyph =
            when (status) {
                "active" -> "✓"
                "inactive" -> "○"
                "expired" -> "!"
                else -> "↻"
            }
        val word = label.ifBlank { status.uppercase() }
        return "$glyph $word"
    }
}
