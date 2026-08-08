import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_device/main.dart';
import 'package:roamkit_device/managed_config/managed_config.dart';
import 'package:roamkit_device/managed_config/managed_config_reader.dart';

class _EmptyReader implements ManagedConfigReader {
  @override
  Stream<ManagedConfig> get changes => const Stream.empty();

  @override
  Future<ManagedConfig> read() async =>
      const ManagedConfig(deviceExternalId: null, deviceCredential: null);
}

void main() {
  testWidgets('app boots to managed config debug page', (tester) async {
    await tester.pumpWidget(RoamKitDeviceApp(reader: _EmptyReader()));
    await tester.pumpAndSettle();
    expect(find.text('RoamKit Device'), findsWidgets);
    expect(find.textContaining('UEM managed configuration'), findsOneWidget);
  });
}
