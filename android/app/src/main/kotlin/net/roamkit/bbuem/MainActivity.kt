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

    private var restrictionsReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, managedMethodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManagedConfig" -> result.success(readManagedConfig())
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
