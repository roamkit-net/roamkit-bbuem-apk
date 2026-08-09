package net.roamkit.device

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

/**
 * Shared RemoteViews binder for compact (2×2) and wide (4×2) widgets.
 *
 * Paints only from the atomic Flutter JSON snapshot. Does not evaluate eSIM
 * health, remaining, or expiry.
 */
object RoamKitWidgetBinder {
    const val STORAGE_KEY = "widget_snapshot_v1"
    private const val SCHEMA_VERSION = 1

    private const val COLOR_GREEN = 0xFF15803D.toInt()
    private const val COLOR_RED = 0xFFB91C1C.toInt()
    private const val COLOR_SLATE = 0xFF334155.toInt()
    private const val COLOR_TEXT = 0xFFFFFFFF.toInt()

    enum class Size {
        Compact,
        Wide,
    }

    data class Snapshot(
        val schema: Int,
        val surface: String,
        val hero: String,
        val remaining: String,
        val expires: String,
        val planTitle: String,
        val planSubtitle: String,
        val planFlag: String,
        val planIcon: String,
    )

    fun updateAll(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        size: Size,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val snapshot = readSnapshot(prefs)
        for (appWidgetId in appWidgetIds) {
            val views = buildViews(context, size, snapshot, appWidgetId)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    fun readSnapshot(prefs: SharedPreferences): Snapshot {
        val raw = prefs.getString(STORAGE_KEY, null)
        return parseOrFailSafe(raw)
    }

    fun parseOrFailSafe(raw: String?): Snapshot {
        if (raw.isNullOrBlank()) {
            return failSafe()
        }
        return try {
            val json = JSONObject(raw)
            val schema = json.optInt("schema", -1)
            val surface = json.optString("surface", "")
            if (schema != SCHEMA_VERSION || !isKnownSurface(surface)) {
                return failSafe()
            }
            Snapshot(
                schema = schema,
                surface = surface,
                hero = json.optString("hero", "UNAVAILABLE").ifBlank { "UNAVAILABLE" },
                remaining = json.optString("remaining", "—").ifBlank { "—" },
                expires = json.optString("expires", "—").ifBlank { "—" },
                planTitle = json.optString("plan_title", ""),
                planSubtitle = json.optString("plan_subtitle", ""),
                planFlag = json.optString("plan_flag", ""),
                planIcon = json.optString("plan_icon", ""),
            )
        } catch (_: Exception) {
            failSafe()
        }
    }

    private fun failSafe(): Snapshot =
        Snapshot(
            schema = SCHEMA_VERSION,
            surface = "slateError",
            hero = "UNAVAILABLE",
            remaining = "Open RoamKit",
            expires = "—",
            planTitle = "",
            planSubtitle = "",
            planFlag = "",
            planIcon = "",
        )

    private fun isKnownSurface(surface: String): Boolean =
        surface == "green" ||
            surface == "red" ||
            surface == "slateLoading" ||
            surface == "slateError"

    private fun buildViews(
        context: Context,
        size: Size,
        snapshot: Snapshot,
        appWidgetId: Int,
    ): RemoteViews {
        val layoutId =
            when (size) {
                Size.Compact -> R.layout.roamkit_status_widget_2x2
                Size.Wide -> R.layout.roamkit_status_widget_4x2
            }
        val views = RemoteViews(context.packageName, layoutId)
        val background = backgroundColor(snapshot.surface)

        views.setInt(R.id.widget_root, "setBackgroundColor", background)
        views.setTextColor(R.id.widget_hero, COLOR_TEXT)
        views.setTextViewText(R.id.widget_hero, snapshot.hero)
        views.setTextColor(R.id.widget_remaining, COLOR_TEXT)
        views.setTextViewText(R.id.widget_remaining, snapshot.remaining)

        if (size == Size.Wide) {
            bindPlanBlock(views, snapshot)
            views.setTextColor(R.id.widget_expires, COLOR_TEXT)
            val expiresLabel =
                if (snapshot.expires == "—" || snapshot.expires.isBlank()) {
                    "Exp —"
                } else {
                    "Exp ${snapshot.expires}"
                }
            views.setTextViewText(R.id.widget_expires, expiresLabel)
            // Prefix remaining for wide layout when not fail-safe open hint.
            if (snapshot.remaining != "Open RoamKit" && snapshot.remaining != "—") {
                views.setTextViewText(R.id.widget_remaining, "Left ${snapshot.remaining}")
            }
        }

        views.setOnClickPendingIntent(
            R.id.widget_root,
            launchPendingIntent(context, size, appWidgetId),
        )
        return views
    }

    private fun bindPlanBlock(views: RemoteViews, snapshot: Snapshot) {
        val hasPlan = snapshot.planTitle.isNotBlank()
        views.setViewVisibility(
            R.id.widget_plan_block,
            if (hasPlan) View.VISIBLE else View.GONE,
        )
        if (!hasPlan) {
            return
        }
        val icon =
            when {
                snapshot.planFlag.isNotBlank() -> snapshot.planFlag
                snapshot.planIcon == "globe" -> "🌐"
                snapshot.planIcon == "regional" -> "🗺️"
                else -> "•"
            }
        views.setTextColor(R.id.widget_plan_icon, COLOR_TEXT)
        views.setTextViewText(R.id.widget_plan_icon, icon)
        views.setTextColor(R.id.widget_plan_title, COLOR_TEXT)
        views.setTextViewText(R.id.widget_plan_title, snapshot.planTitle)
        val subtitle = snapshot.planSubtitle
        if (subtitle.isBlank()) {
            views.setViewVisibility(R.id.widget_plan_subtitle, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_plan_subtitle, View.VISIBLE)
            views.setTextColor(R.id.widget_plan_subtitle, COLOR_TEXT)
            views.setTextViewText(R.id.widget_plan_subtitle, subtitle)
        }
    }

    private fun backgroundColor(surface: String): Int =
        when (surface) {
            "green" -> COLOR_GREEN
            "red" -> COLOR_RED
            else -> COLOR_SLATE
        }

    private fun launchPendingIntent(
        context: Context,
        size: Size,
        appWidgetId: Int,
    ): PendingIntent {
        val intent =
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                // No credential, ICCID, or device_external_id extras.
            }
        val requestCode =
            when (size) {
                Size.Compact -> 2100 + appWidgetId
                Size.Wide -> 2200 + appWidgetId
            }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
