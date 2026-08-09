package net.roamkit.device

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/** 4×2 home-screen widget picker entry (hero + plan + remaining + expiry). */
class RoamKitWideWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        RoamKitWidgetBinder.updateAll(
            context,
            appWidgetManager,
            appWidgetIds,
            RoamKitWidgetBinder.Size.Wide,
        )
    }
}
