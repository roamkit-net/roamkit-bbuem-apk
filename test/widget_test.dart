import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_status.dart';
import 'package:roamkit_bbuem_apk/api/device_status_client.dart';
import 'package:roamkit_bbuem_apk/main.dart';
import 'package:roamkit_bbuem_apk/managed_config/managed_config.dart';
import 'package:roamkit_bbuem_apk/managed_config/managed_config_reader.dart';
import 'package:roamkit_bbuem_apk/widget/widget_snapshot_store.dart';

class _EmptyReader implements ManagedConfigReader {
  @override
  Stream<ManagedConfig> get changes => const Stream.empty();

  @override
  Future<ManagedConfig> read() async =>
      const ManagedConfig(deviceExternalId: null, deviceCredential: null);
}

class _NoopClient implements DeviceStatusClient {
  @override
  Future<DeviceStatus> fetchStatus({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) {
    throw StateError('should not be called without managed config');
  }
}

void main() {
  testWidgets('app boots to device status page', (tester) async {
    await tester.pumpWidget(
      RoamKitDeviceApp(
        reader: _EmptyReader(),
        statusClient: _NoopClient(),
        snapshotStore: NoopWidgetSnapshotStore(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('RoamKit'), findsOneWidget);
    expect(find.text('UNAVAILABLE'), findsOneWidget);
  });
}
