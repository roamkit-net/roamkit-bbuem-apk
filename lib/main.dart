import 'package:flutter/material.dart';

import 'api/device_coverage_client.dart';
import 'api/device_packages_client.dart';
import 'api/device_status_client.dart';
import 'managed_config/managed_config_reader.dart';
import 'ui/device_status_page.dart';
import 'widget/widget_background_refresh.dart';
import 'widget/widget_snapshot_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoamKitDeviceApp());
}

/// WorkManager headless entrypoint. Must stay a top-level function in main.dart.
@pragma('vm:entry-point')
void widgetBackgroundRefresh() {
  widgetBackgroundRefreshImpl();
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
      title: 'RoamKit.net',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090B0F),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF171A20),
          primary: Color(0xFF7467F0),
        ),
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
