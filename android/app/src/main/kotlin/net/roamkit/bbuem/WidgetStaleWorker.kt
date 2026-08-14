package net.roamkit.bbuem

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

/** No-network stale flip. Does not call the API or evaluate eSIM health. */
class WidgetStaleWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {
    override fun doWork(): Result {
        val prefs = HomeWidgetPlugin.getData(applicationContext)
        val raw = prefs.getString(RoamKitWidgetBinder.STORAGE_KEY, null) ?: return Result.success()
        return try {
            val json = JSONObject(raw)
            val last = json.optString("last_success_at", "")
            if (last.isBlank()) {
                return Result.success()
            }
            val lastAt = IsoTime.parseMillis(last) ?: return Result.success()
            if (System.currentTimeMillis() < lastAt + 60L * 60L * 1000L) {
                return Result.success()
            }
            if (json.optString("display_status") == "unavailable" &&
                json.optBoolean("update_unavailable", false)
            ) {
                return Result.success()
            }
            json.put("display_status", "unavailable")
            json.put("status_label", "UNAVAILABLE")
            json.put("active_package_title", JSONObject.NULL)
            json.put("update_unavailable", true)
            json.put("generated_at", IsoTime.nowIso())
            prefs.edit().putString(RoamKitWidgetBinder.STORAGE_KEY, json.toString()).apply()
            rebind(applicationContext)
            Result.success()
        } catch (_: Exception) {
            Result.success()
        }
    }

    private fun rebind(context: Context) {
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
    }
}
