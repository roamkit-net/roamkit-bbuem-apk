package net.roamkit.bbuem

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/** Rebind saved snapshot and reschedule work after boot or APK replace. */
class WidgetBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        val manager = AppWidgetManager.getInstance(context)
        val compact =
            manager.getAppWidgetIds(ComponentName(context, RoamKitCompactWidgetProvider::class.java))
        val wide =
            manager.getAppWidgetIds(ComponentName(context, RoamKitWideWidgetProvider::class.java))
        if (compact.isNotEmpty()) {
            RoamKitWidgetBinder.updateAll(context, manager, compact)
        }
        if (wide.isNotEmpty()) {
            RoamKitWidgetBinder.updateAll(context, manager, wide)
        }
        WidgetWorkScheduler.ensureScheduled(context)
    }
}
