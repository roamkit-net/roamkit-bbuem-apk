import 'package:flutter/material.dart';

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
    this.snapshotStore,
  });

  final ManagedConfigReader? reader;
  final DeviceStatusClient? statusClient;
  final WidgetSnapshotStore? snapshotStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoamKit Device',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF15803D)),
        useMaterial3: true,
      ),
      home: DeviceStatusPage(
        reader: reader ?? ChannelManagedConfigReader(),
        statusClient: statusClient ?? HttpDeviceStatusClient(),
        snapshotStore: snapshotStore,
      ),
    );
  }
}
