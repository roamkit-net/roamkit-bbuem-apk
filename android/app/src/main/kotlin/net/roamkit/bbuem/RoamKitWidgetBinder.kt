package net.roamkit.bbuem

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Shared RemoteViews binder for both existing widget receivers.
 *
 * Paints only from the atomic Flutter JSON snapshot. Does not evaluate eSIM
 * health, remaining, or expiry. Does not call the RoamKit API.
 */
object RoamKitWidgetBinder {
    const val STORAGE_KEY = "widget_snapshot"
    const val LEGACY_STORAGE_KEY = "widget_snapshot_v1"
    const val EXTRA_ROUTE = "roamkit_widget_route"

    private const val COLOR_PRIMARY = 0xFFF5F7FA.toInt()
    private const val COLOR_SECONDARY = 0xFFA7ADB5.toInt()
    private const val COLOR_AMBER = 0xFFF2A514.toInt()

    fun updateAll(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val snapshot = readSnapshot(prefs)
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val views = buildViews(context, snapshot, appWidgetId, options)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    fun readSnapshot(prefs: SharedPreferences): WidgetSnapshotParser.Snapshot {
        val raw = prefs.getString(STORAGE_KEY, null)
            ?: prefs.getString(LEGACY_STORAGE_KEY, null)
        return parseOrFailSafe(raw)
    }

    fun parseOrFailSafe(raw: String?): WidgetSnapshotParser.Snapshot =
        WidgetSnapshotParser.parseOrFailSafe(raw)

    private fun buildViews(
        context: Context,
        snapshot: WidgetSnapshotParser.Snapshot,
        appWidgetId: Int,
        options: Bundle,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.roamkit_status_widget_4x3)
        val minH =
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        val hideLegend = minH < 170
        val hideCoverage = minH < 190 || !snapshot.coverageAvailable
        val hidePercent = minH < 150 || snapshot.unlimited || !snapshot.hasUsage
        val hideRing = minH < 130

        views.setTextViewText(
            R.id.widget_status,
            WidgetSnapshotParser.statusBadge(snapshot.displayStatus, snapshot.statusLabel),
        )

        val title = titleText(snapshot)
        setTextOrGone(views, R.id.widget_title, title)

        val caption = captionText(snapshot)
        views.setTextColor(
            R.id.widget_caption,
            if (snapshot.updateUnavailable) COLOR_AMBER else COLOR_SECONDARY,
        )
        setTextOrGone(views, R.id.widget_caption, caption)

        views.setViewVisibility(
            R.id.widget_coverage,
            if (hideCoverage) View.GONE else View.VISIBLE,
        )

        bindCenter(context, views, snapshot, hideRing)

        val remainingLine = remainingLine(snapshot)
        views.setTextColor(
            R.id.widget_remaining_line,
            if (snapshot.hasUsage && !snapshot.unlimited) 0xFFDDFB55.toInt() else COLOR_PRIMARY,
        )
        setTextOrGone(views, R.id.widget_remaining_line, remainingLine)

        if (hidePercent || remainingLine.isEmpty()) {
            views.setViewVisibility(R.id.widget_percent, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_percent, View.VISIBLE)
            views.setTextViewText(R.id.widget_percent, "${snapshot.percent}%")
        }

        val showLegend =
            !hideLegend && snapshot.hasUsage && !snapshot.unlimited && snapshot.usedText.isNotBlank()
        views.setViewVisibility(
            R.id.widget_legend,
            if (showLegend) View.VISIBLE else View.GONE,
        )
        if (showLegend) {
            views.setTextViewText(R.id.widget_used, "${snapshot.usedText} used")
            views.setTextViewText(
                R.id.widget_remaining_legend,
                "${snapshot.remainingText} remaining",
            )
        }

        views.setOnClickPendingIntent(
            R.id.widget_root,
            launchPendingIntent(
                context,
                appWidgetId,
                WidgetSnapshotParser.rootRoute(snapshot.displayStatus),
                2100,
            ),
        )
        views.setOnClickPendingIntent(
            R.id.widget_coverage,
            launchPendingIntent(context, appWidgetId, "coverage", 2200),
        )

        views.setContentDescription(R.id.widget_root, talkBack(snapshot))
        return views
    }

    private fun titleText(snapshot: WidgetSnapshotParser.Snapshot): String {
        if (!snapshot.activePackageTitle.isNullOrBlank()) {
            return snapshot.activePackageTitle
        }
        return when (snapshot.displayStatus) {
            "inactive" -> "No active data package"
            "expired" -> "Data package expired"
            "unavailable" ->
                if (snapshot.hasUsage) {
                    ""
                } else {
                    "Status is temporarily unavailable"
                }
            else -> ""
        }
    }

    private fun captionText(snapshot: WidgetSnapshotParser.Snapshot): String {
        if (snapshot.updateUnavailable) {
            return "Update unavailable"
        }
        if (snapshot.displayStatus == "active" && !snapshot.hasUsage) {
            return "Usage not synced"
        }
        if (snapshot.displayStatus == "unavailable" && !snapshot.hasUsage) {
            return "Open RoamKit to retry"
        }
        return ""
    }

    private fun remainingLine(snapshot: WidgetSnapshotParser.Snapshot): String {
        if (!snapshot.hasUsage) {
            return ""
        }
        if (snapshot.unlimited) {
            return "Unlimited"
        }
        if (snapshot.remainingText.isBlank() || snapshot.totalText.isBlank()) {
            return ""
        }
        return "${snapshot.remainingText} of ${snapshot.totalText} remaining"
    }

    private fun bindCenter(
        context: Context,
        views: RemoteViews,
        snapshot: WidgetSnapshotParser.Snapshot,
        hideRing: Boolean,
    ) {
        if (snapshot.hasUsage && !hideRing) {
            val px =
                TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP,
                    88f,
                    context.resources.displayMetrics,
                ).toInt()
            val bitmap =
                WidgetRingBitmap.render(px, snapshot.percent, snapshot.unlimited)
            views.setImageViewBitmap(R.id.widget_center, bitmap)
            views.setViewVisibility(R.id.widget_center, View.VISIBLE)
            return
        }
        val icon =
            when (snapshot.displayStatus) {
                "expired" -> R.drawable.widget_ic_expired
                "unavailable" -> R.drawable.widget_ic_retry
                else -> R.drawable.widget_ic_sim
            }
        views.setImageViewResource(R.id.widget_center, icon)
        views.setViewVisibility(R.id.widget_center, View.VISIBLE)
    }

    private fun talkBack(snapshot: WidgetSnapshotParser.Snapshot): String {
        val parts = mutableListOf<String>()
        parts.add(WidgetSnapshotParser.statusBadge(snapshot.displayStatus, snapshot.statusLabel))
        val title = titleText(snapshot)
        if (title.isNotBlank()) {
            parts.add(title)
        }
        val caption = captionText(snapshot)
        if (caption.isNotBlank()) {
            parts.add(caption)
        }
        val remaining = remainingLine(snapshot)
        if (remaining.isNotBlank()) {
            parts.add(remaining)
        }
        if (snapshot.coverageAvailable) {
            parts.add("View coverage")
        }
        return parts.joinToString(". ")
    }

    private fun setTextOrGone(views: RemoteViews, id: Int, text: String) {
        if (text.isBlank()) {
            views.setViewVisibility(id, View.GONE)
        } else {
            views.setViewVisibility(id, View.VISIBLE)
            views.setTextViewText(id, text)
        }
    }

    private fun launchPendingIntent(
        context: Context,
        appWidgetId: Int,
        route: String,
        base: Int,
    ): PendingIntent {
        val intent =
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_ROUTE, route)
            }
        return PendingIntent.getActivity(
            context,
            base + appWidgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
