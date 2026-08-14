package net.roamkit.bbuem

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

/** Existing compact receiver — kept so upgrade does not drop home-screen instances. */
class RoamKitCompactWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        RoamKitWidgetBinder.updateAll(context, appWidgetManager, appWidgetIds)
        WidgetWorkScheduler.ensureScheduled(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        RoamKitWidgetBinder.updateAll(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onEnabled(context: Context) {
        WidgetWorkScheduler.ensureScheduled(context)
    }

    override fun onDisabled(context: Context) {
        WidgetWorkScheduler.cancelIfNoWidgets(context)
    }
}
