package net.roamkit.bbuem

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.RestrictionsManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Android managed configuration (RestrictionsManager) to Flutter.
 *
 * UEM keys (ADR 021 Option C″):
 * - roamkit.device_serial (normative; UEM %SerialNumber%)
 * - roamkit.device_external_id + roamkit.device_credential (PR18 fallback)
 */
class MainActivity : FlutterActivity() {
    private val managedMethodChannelName = "net.roamkit.bbuem/managed_config"
    private val managedEventChannelName = "net.roamkit.bbuem/managed_config_events"
    private val routeChannelName = "net.roamkit.bbuem/widget_route"
    private val workChannelName = "net.roamkit.bbuem/widget_work"

    private var restrictionsReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingRoute: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        pendingRoute = routeFrom(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingRoute = routeFrom(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, managedMethodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManagedConfig" -> result.success(readManagedConfig())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, routeChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingRoute" -> {
                        val route = pendingRoute
                        pendingRoute = null
                        result.success(route)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, workChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "onSnapshotSuccess" -> {
                        val last = call.argument<String>("last_success_at")
                        if (!last.isNullOrBlank()) {
                            WidgetWorkScheduler.scheduleStale(this, last)
                        }
                        WidgetWorkScheduler.ensureScheduled(this)
                        result.success(null)
                    }
                    "ensureScheduled" -> {
                        WidgetWorkScheduler.ensureScheduled(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, managedEventChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        eventSink = events
                        registerRestrictionsReceiver()
                    }

                    override fun onCancel(arguments: Any?) {
                        unregisterRestrictionsReceiver()
                        eventSink = null
                    }
                },
            )
    }

    override fun onDestroy() {
        unregisterRestrictionsReceiver()
        eventSink = null
        super.onDestroy()
    }

    private fun routeFrom(intent: Intent?): String? {
        val raw = intent?.getStringExtra(RoamKitWidgetBinder.EXTRA_ROUTE) ?: return null
        return when (raw) {
            "home", "packages", "refresh", "coverage" -> raw
            else -> "home"
        }
    }

    private fun readManagedConfig(): Map<String, String?> {
        val manager = getSystemService(Context.RESTRICTIONS_SERVICE) as RestrictionsManager
        val bundle = manager.applicationRestrictions
        return mapOf(
            "roamkit.device_serial" to bundle.getString("roamkit.device_serial"),
            "roamkit.device_external_id" to bundle.getString("roamkit.device_external_id"),
            "roamkit.device_credential" to bundle.getString("roamkit.device_credential"),
        )
    }

    private fun registerRestrictionsReceiver() {
        if (restrictionsReceiver != null) {
            return
        }
        val receiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    eventSink?.success(readManagedConfig())
                }
            }
        val filter = IntentFilter(Intent.ACTION_APPLICATION_RESTRICTIONS_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
        restrictionsReceiver = receiver
    }

    private fun unregisterRestrictionsReceiver() {
        restrictionsReceiver?.let { unregisterReceiver(it) }
        restrictionsReceiver = null
    }
}
