import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_device/api/device_status.dart';
import 'package:roamkit_device/api/device_status_client.dart';
import 'package:roamkit_device/api/device_status_errors.dart';
import 'package:roamkit_device/managed_config/managed_config.dart';
import 'package:roamkit_device/managed_config/managed_config_reader.dart';
import 'package:roamkit_device/ui/device_status_page.dart';

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

class _FakeStatusClient implements DeviceStatusClient {
  _FakeStatusClient({this.status, this.error});

  DeviceStatus? status;
  DeviceStatusException? error;
  int calls = 0;
  String? lastCredential;

  @override
  Future<DeviceStatus> fetchStatus({
    required String deviceExternalId,
    required String credential,
  }) async {
    calls += 1;
    lastCredential = credential;
    if (error != null) {
      throw error!;
    }
    return status!;
  }
}

DeviceStatus _sampleStatus() {
  return DeviceStatus(
    deviceExternalId: 'dev-1',
    bindingStatus: 'active',
    esim: const DeviceStatusEsim(id: 9, iccid: '8910', status: 'ACTIVE'),
    usage: DeviceStatusUsage(
      dataRemaining: '12 MB',
      dataUsed: '88 MB',
      expiresAt: DateTime.utc(2026, 9, 1),
    ),
    autoTopup: const DeviceStatusAutoTopup(enabled: true),
    checkedAt: DateTime.utc(2026, 8, 9),
  );
}

void main() {
  testWidgets('shows status and never renders plaintext credential', (
    tester,
  ) async {
    const secret = 'plain-secret-must-not-appear';
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: secret,
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(reader: reader, statusClient: client),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Credential'), findsOneWidget);
    expect(find.text('present'), findsOneWidget);
    expect(find.text(secret), findsNothing);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('12 MB'), findsOneWidget);
    expect(find.text('Auto-topup', skipOffstage: false), findsOneWidget);
    expect(find.text('enabled', skipOffstage: false), findsOneWidget);
    expect(client.calls, 1);
    expect(client.lastCredential, secret);
  });

  testWidgets('shows missing managed config state', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(deviceExternalId: null, deviceCredential: null),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(reader: reader, statusClient: client),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('missing'), findsNWidgets(2));
    expect(find.textContaining('Managed configuration incomplete'), findsOneWidget);
    expect(client.calls, 0);
  });

  testWidgets('shows 404 and reloads on managed config change', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret-a',
      ),
    );
    final client = _FakeStatusClient(
      error: const DeviceStatusNotFoundException(),
    );
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(reader: reader, statusClient: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('not found'), findsOneWidget);
    expect(client.calls, 1);

    client
      ..error = null
      ..status = _sampleStatus();
    reader.emit(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret-b',
      ),
    );
    await tester.pumpAndSettle();

    expect(client.calls, 2);
    expect(client.lastCredential, 'secret-b');
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('secret-a'), findsNothing);
    expect(find.text('secret-b'), findsNothing);
  });

  testWidgets('shows rate-limit and network errors', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(
      error: const DeviceStatusRateLimitedException(),
    );
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(reader: reader, statusClient: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Too many status requests'), findsOneWidget);

    client.error = const DeviceStatusNetworkException('DNS lookup failed');
    await tester.tap(find.byTooltip('Reload'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Network error'), findsOneWidget);
    expect(find.textContaining('DNS lookup failed'), findsOneWidget);
  });
}
