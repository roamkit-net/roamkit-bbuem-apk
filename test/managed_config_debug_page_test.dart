import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_device/managed_config/managed_config.dart';
import 'package:roamkit_device/managed_config/managed_config_keys.dart';
import 'package:roamkit_device/managed_config/managed_config_reader.dart';
import 'package:roamkit_device/ui/managed_config_debug_page.dart';

class _FakeReader implements ManagedConfigReader {
  _FakeReader(this._config);

  ManagedConfig _config;
  final _controller = StreamController<ManagedConfig>.broadcast();

  @override
  Stream<ManagedConfig> get changes => _controller.stream;

  @override
  Future<ManagedConfig> read() async => _config;

  void emit(ManagedConfig config) {
    _config = config;
    _controller.add(config);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  testWidgets('shows managed config values including temporary credential', (
    tester,
  ) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'rk_dev_test',
        deviceCredential: 'plain-secret-for-uem-proof',
      ),
    );
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ManagedConfigDebugPage(reader: reader)),
    );
    await tester.pumpAndSettle();

    expect(find.text(ManagedConfigKeys.deviceExternalId), findsOneWidget);
    expect(find.text('rk_dev_test'), findsOneWidget);
    expect(find.text('plain-secret-for-uem-proof'), findsOneWidget);
    expect(
      find.textContaining('Both values present'),
      findsOneWidget,
    );
    expect(find.textContaining('DEBUG: plaintext credential'), findsOneWidget);
  });

  testWidgets('shows waiting state when values missing', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(deviceExternalId: null, deviceCredential: null),
    );
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ManagedConfigDebugPage(reader: reader)),
    );
    await tester.pumpAndSettle();

    expect(find.text('(missing)'), findsNWidgets(2));
    expect(find.textContaining('Waiting for UEM'), findsOneWidget);
  });
}
