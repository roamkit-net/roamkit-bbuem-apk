import 'package:flutter/material.dart';

import 'api/device_coverage_client.dart';
import 'api/device_packages_client.dart';
import 'api/device_status_client.dart';
import 'managed_config/managed_config_reader.dart';
import 'ui/device_status_page.dart';
import 'widget/widget_snapshot_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoamKitDeviceApp());
}

class RoamKitDeviceApp extends StatelessWidget {
  const RoamKitDeviceApp({
    super.key,
    this.reader,
    this.statusClient,
    this.coverageClient,
    this.packagesClient,
    this.snapshotStore,
  });

  final ManagedConfigReader? reader;
  final DeviceStatusClient? statusClient;
  final DeviceCoverageClient? coverageClient;
  final DevicePackagesClient? packagesClient;
  final WidgetSnapshotStore? snapshotStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoamKit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF15803D)),
        useMaterial3: true,
      ),
      home: DeviceStatusPage(
        reader: reader ?? ChannelManagedConfigReader(),
        statusClient: statusClient ?? HttpDeviceStatusClient(),
        coverageClient: coverageClient,
        packagesClient: packagesClient,
        snapshotStore: snapshotStore,
      ),
    );
  }
}
