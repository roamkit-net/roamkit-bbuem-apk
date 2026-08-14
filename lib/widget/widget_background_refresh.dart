import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../api/device_packages_client.dart';
import '../api/device_status_client.dart';
import '../api/device_status_errors.dart';
import '../managed_config/managed_config_reader.dart';
import '../status/operational_status_view.dart';
import '../status/usage_bar_view.dart';
import 'widget_refresh_lease.dart';
import 'widget_snapshot.dart';
import 'widget_snapshot_store.dart';
import 'widget_work.dart';

const _doneChannelName = 'net.roamkit.bbuem/widget_background_done';

/// Headless WorkManager body. Same evaluation as the in-app path.
Future<void> widgetBackgroundRefreshImpl() async {
  WidgetsFlutterBinding.ensureInitialized();
  var ok = false;
  try {
    await runWidgetBackgroundRefresh();
    ok = true;
  } catch (_) {
    ok = false;
  }
  try {
    await const MethodChannel(_doneChannelName).invokeMethod<void>(
      'refreshFinished',
      {'ok': ok},
    );
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
}

Future<void> runWidgetBackgroundRefresh({
  ManagedConfigReader? reader,
  DeviceStatusClient? statusClient,
  DevicePackagesClient? packagesClient,
  WidgetSnapshotStore? store,
  WidgetLeaseStore? leaseStore,
  DateTime Function()? now,
  String? owner,
}) async {
  final clock = now ?? DateTime.now;
  final leases = leaseStore ??
      WidgetLeaseStore(
        readRaw: () => HomeWidget.getWidgetData<String>(
          WidgetRefreshLease.storageKey,
        ),
        writeRaw: (raw) => HomeWidget.saveWidgetData<String>(
          WidgetRefreshLease.storageKey,
          raw,
        ),
      );
  final acquired = await leases.tryAcquire(
    owner: owner ?? newLeaseOwner(),
    now: clock(),
  );
  if (acquired == null) {
    return;
  }
  final snapshotStore = store ?? const HomeWidgetSnapshotStore();
  try {
    final config = await (reader ?? ChannelManagedConfigReader()).read();
    if (!config.isComplete) {
      final last = await snapshotStore.readLast();
      final snap = WidgetSnapshot.fromState(
        view: OperationalStatusView.fromException(
          const MissingManagedConfigException(),
        ),
        bar: const UsageBarView.unavailable(),
        coverageAvailable: false,
        packagesFailed: true,
        lastGood: last,
        now: clock(),
      );
      if (await leases.stillOwns(acquired, clock())) {
        await snapshotStore.publish(snap);
      }
      return;
    }

    Object? packagesError;
    final status = await () async {
      try {
        return config.prefersSerialAuth
            ? await (statusClient ?? HttpDeviceStatusClient()).fetchStatus(
                deviceSerial: config.deviceSerial!,
              )
            : await (statusClient ?? HttpDeviceStatusClient()).fetchStatus(
                deviceExternalId: config.deviceExternalId!,
                credential: config.deviceCredential!,
              );
      } catch (_) {
        return null;
      }
    }();

    var packages = await () async {
      try {
        return config.prefersSerialAuth
            ? await (packagesClient ?? HttpDevicePackagesClient())
                .fetchPackages(deviceSerial: config.deviceSerial!)
            : await (packagesClient ?? HttpDevicePackagesClient())
                .fetchPackages(
                deviceExternalId: config.deviceExternalId!,
                credential: config.deviceCredential!,
              );
      } catch (error) {
        packagesError = error;
        return null;
      }
    }();

    final last = await snapshotStore.readLast();
    final view = status == null
        ? OperationalStatusView.fromException(
            const DeviceStatusUnexpectedException('Could not load status'),
          )
        : evaluateOperationalView(status, now: clock());
    final usageBar = status == null
        ? const UsageBarView.unavailable()
        : buildUsageBarView(
            dataRemaining: status.usage.dataRemaining,
            dataUsed: status.usage.dataUsed,
          );
    final snap = WidgetSnapshot.fromState(
      view: view,
      activePackage: packages?.activePackage,
      bar: usageBar,
      coverageAvailable: status?.plan?.coverageSummary?.available == true,
      packagesFailed: packagesError != null,
      lastGood: last,
      now: clock(),
    );
    if (!await leases.stillOwns(acquired, clock())) {
      return;
    }
    await snapshotStore.publish(snap);
    if (snap.lastSuccessAt != null && !snap.updateUnavailable) {
      await WidgetWorkBridge.onSnapshotSuccess(
        lastSuccessAt: snap.lastSuccessAt!,
      );
    }
  } finally {
    await leases.release(acquired);
  }
}
