package net.roamkit.bbuem

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object WidgetWorkScheduler {
    const val REFRESH_WORK = "roamkit_widget_refresh"
    const val STALE_WORK = "roamkit_widget_stale"

    fun hasAnyWidgets(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        val compact =
            manager.getAppWidgetIds(
                ComponentName(context, RoamKitCompactWidgetProvider::class.java),
            )
        val wide =
            manager.getAppWidgetIds(
                ComponentName(context, RoamKitWideWidgetProvider::class.java),
            )
        return compact.isNotEmpty() || wide.isNotEmpty()
    }

    fun ensureScheduled(context: Context) {
        if (!hasAnyWidgets(context)) {
            return
        }
        val constraints =
            Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
        val refresh =
            PeriodicWorkRequestBuilder<WidgetRefreshWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            REFRESH_WORK,
            ExistingPeriodicWorkPolicy.KEEP,
            refresh,
        )
    }

    fun scheduleStale(context: Context, lastSuccessAtIso: String) {
        if (!hasAnyWidgets(context)) {
            return
        }
        val last = IsoTime.parseMillis(lastSuccessAtIso) ?: return
        val fireAt = last + 60L * 60L * 1000L
        val delayMs = (fireAt - System.currentTimeMillis()).coerceAtLeast(0L)
        val request =
            OneTimeWorkRequestBuilder<WidgetStaleWorker>()
                .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
                .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            STALE_WORK,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    fun cancelIfNoWidgets(context: Context) {
        if (hasAnyWidgets(context)) {
            return
        }
        val wm = WorkManager.getInstance(context)
        wm.cancelUniqueWork(REFRESH_WORK)
        wm.cancelUniqueWork(STALE_WORK)
    }
}
