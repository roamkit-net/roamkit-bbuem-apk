package net.roamkit.bbuem

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Starts the Dart [widgetBackgroundRefresh] entrypoint. Kotlin does not call
 * the RoamKit API or evaluate lifecycle.
 */
class WidgetRefreshWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {
    override fun doWork(): Result {
        if (!WidgetWorkScheduler.hasAnyWidgets(applicationContext)) {
            return Result.success()
        }
        val latch = CountDownLatch(1)
        val ok = booleanArrayOf(false)
        val engineHolder = arrayOfNulls<FlutterEngine>(1)
        Handler(Looper.getMainLooper()).post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val engine = FlutterEngine(applicationContext)
                engineHolder[0] = engine
                GeneratedPluginRegistrant.registerWith(engine)
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    "net.roamkit.bbuem/managed_config",
                ).setMethodCallHandler { call, result ->
                    if (call.method == "getManagedConfig") {
                        val manager =
                            applicationContext.getSystemService(Context.RESTRICTIONS_SERVICE)
                                as android.content.RestrictionsManager
                        val bundle = manager.applicationRestrictions
                        result.success(
                            mapOf(
                                "roamkit.device_serial" to bundle.getString("roamkit.device_serial"),
                                "roamkit.device_external_id" to
                                    bundle.getString("roamkit.device_external_id"),
                                "roamkit.device_credential" to
                                    bundle.getString("roamkit.device_credential"),
                            ),
                        )
                    } else {
                        result.notImplemented()
                    }
                }
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    "net.roamkit.bbuem/widget_work",
                ).setMethodCallHandler { call, result ->
                    when (call.method) {
                        "onSnapshotSuccess" -> {
                            val last = call.argument<String>("last_success_at")
                            if (!last.isNullOrBlank()) {
                                WidgetWorkScheduler.scheduleStale(
                                    applicationContext,
                                    last,
                                )
                            }
                            WidgetWorkScheduler.ensureScheduled(applicationContext)
                            result.success(null)
                        }
                        "ensureScheduled" -> {
                            WidgetWorkScheduler.ensureScheduled(applicationContext)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    "net.roamkit.bbuem/widget_background_done",
                ).setMethodCallHandler { call, result ->
                    if (call.method == "refreshFinished") {
                        ok[0] = call.argument<Boolean>("ok") == true
                        result.success(null)
                        latch.countDown()
                    } else {
                        result.notImplemented()
                    }
                }
                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "widgetBackgroundRefresh",
                    ),
                )
            } catch (_: Exception) {
                latch.countDown()
            }
        }
        latch.await(90, TimeUnit.SECONDS)
        Handler(Looper.getMainLooper()).post {
            engineHolder[0]?.destroy()
        }
        return if (ok[0]) Result.success() else Result.retry()
    }
}
