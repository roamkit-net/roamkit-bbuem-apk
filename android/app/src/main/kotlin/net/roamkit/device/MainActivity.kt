package net.roamkit.device

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.RestrictionsManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.UserManager
import android.telephony.SubscriptionManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Android managed configuration (RestrictionsManager) to Flutter,
 * plus ADR 021 ICCID readability spike (default data subscription only).
 *
 * UEM keys (PR1):
 * - roamkit.device_external_id
 * - roamkit.device_credential
 */
class MainActivity : FlutterActivity() {
    private val managedMethodChannelName = "net.roamkit.device/managed_config"
    private val managedEventChannelName = "net.roamkit.device/managed_config_events"
    private val iccidSpikeChannelName = "net.roamkit.device/iccid_spike"

    private var restrictionsReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null
    private var permissionResult: MethodChannel.Result? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, iccidSpikeChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestReadPhoneState" -> requestReadPhoneState(result)
                    "getIccidSpikeSnapshot" -> result.success(readIccidSpikeSnapshot())
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_READ_PHONE_STATE) {
            return
        }
        val granted =
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
        permissionResult?.success(granted)
        permissionResult = null
    }

    override fun onDestroy() {
        unregisterRestrictionsReceiver()
        eventSink = null
        permissionResult = null
        super.onDestroy()
    }

    private fun requestReadPhoneState(result: MethodChannel.Result) {
        if (hasReadPhoneState()) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.success(false)
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_PHONE_STATE),
            REQUEST_READ_PHONE_STATE,
        )
    }

    private fun hasReadPhoneState(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_STATE,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isManagedProfile(userManager: UserManager?): Boolean {
        if (userManager == null) {
            return false
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            userManager.isManagedProfile
        } else {
            @Suppress("DEPRECATION")
            userManager.userProfiles.size > 1 && !userManager.isSystemUser
        }
    }

    private fun readManagedConfig(): Map<String, String?> {
        val manager = getSystemService(Context.RESTRICTIONS_SERVICE) as RestrictionsManager
        val bundle = manager.applicationRestrictions
        return mapOf(
            "roamkit.device_external_id" to bundle.getString("roamkit.device_external_id"),
            "roamkit.device_credential" to bundle.getString("roamkit.device_credential"),
        )
    }

    /**
     * Spike: resolve default data subscription, then try ICCID.
     * Never logs ICCID. Failure reasons are fixed strings for the Flutter UI.
     */
    private fun readIccidSpikeSnapshot(): Map<String, Any?> {
        val userManager = getSystemService(UserManager::class.java)
        val dpm = getSystemService(DevicePolicyManager::class.java)
        val packageName = packageName

        val base =
            mutableMapOf<String, Any?>(
                "androidVersion" to Build.VERSION.RELEASE,
                "androidSdkInt" to Build.VERSION.SDK_INT,
                "defaultDataSubscriptionId" to null,
                "readPhoneStateGranted" to hasReadPhoneState(),
                "isManagedProfile" to isManagedProfile(userManager),
                "isProfileOwnerApp" to (dpm?.isProfileOwnerApp(packageName) == true),
                "isDeviceOwnerApp" to (dpm?.isDeviceOwnerApp(packageName) == true),
                "iccid" to null,
                "failureReason" to null,
            )

        if (!hasReadPhoneState()) {
            base["failureReason"] = FAILURE_PERMISSION_DENIED
            return base
        }

        val subscriptionManager =
            getSystemService(SubscriptionManager::class.java)
                ?: run {
                    base["failureReason"] = FAILURE_ICCID_UNAVAILABLE
                    return base
                }

        val defaultDataSubId = SubscriptionManager.getDefaultDataSubscriptionId()
        if (defaultDataSubId == SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            base["failureReason"] = FAILURE_NO_DEFAULT_DATA
            return base
        }
        base["defaultDataSubscriptionId"] = defaultDataSubId

        val info =
            try {
                subscriptionManager.getActiveSubscriptionInfo(defaultDataSubId)
            } catch (_: SecurityException) {
                base["failureReason"] = FAILURE_PERMISSION_DENIED
                return base
            }

        if (info == null) {
            val activeCount =
                try {
                    subscriptionManager.activeSubscriptionInfoList?.size ?: 0
                } catch (_: SecurityException) {
                    0
                }
            base["failureReason"] =
                if (activeCount > 1) {
                    FAILURE_AMBIGUOUS
                } else {
                    FAILURE_ICCID_UNAVAILABLE
                }
            return base
        }

        val iccid = info.iccId?.trim().orEmpty()
        if (iccid.isEmpty()) {
            base["failureReason"] = FAILURE_ICCID_UNAVAILABLE
            return base
        }

        base["iccid"] = iccid
        base["failureReason"] = null
        return base
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

    companion object {
        private const val REQUEST_READ_PHONE_STATE = 41021
        private const val FAILURE_PERMISSION_DENIED = "permission_denied"
        private const val FAILURE_NO_DEFAULT_DATA = "no_default_data_subscription"
        private const val FAILURE_ICCID_UNAVAILABLE = "iccid_unavailable"
        private const val FAILURE_AMBIGUOUS = "ambiguous_subscription"
    }
}
