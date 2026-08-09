package net.roamkit.device

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/** 2×2 home-screen widget picker entry (hero + remaining). */
class RoamKitCompactWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        RoamKitWidgetBinder.updateAll(
            context,
            appWidgetManager,
            appWidgetIds,
            RoamKitWidgetBinder.Size.Compact,
        )
    }
}
