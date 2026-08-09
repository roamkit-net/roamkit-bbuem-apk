import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_device/api/device_status.dart';
import 'package:roamkit_device/api/device_status_client.dart';
import 'package:roamkit_device/api/device_status_errors.dart';
import 'package:roamkit_device/managed_config/managed_config.dart';
import 'package:roamkit_device/managed_config/managed_config_reader.dart';
import 'package:roamkit_device/ui/device_status_page.dart';
import 'package:roamkit_device/widget/widget_snapshot_store.dart';

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
  Completer<DeviceStatus>? delay;

  @override
  Future<DeviceStatus> fetchStatus({
    required String deviceExternalId,
    required String credential,
  }) async {
    calls += 1;
    lastCredential = credential;
    if (delay != null) {
      return delay!.future;
    }
    if (error != null) {
      throw error!;
    }
    return status!;
  }
}

const _testIccid = '8900424101001825931';

DeviceStatus _sampleStatus({
  String esimStatus = 'in_use',
  String? dataRemaining = '12 MB',
  DateTime? expiresAt,
  DeviceStatusPlan? plan = const DeviceStatusPlan(
    title: 'Cronet (Croatia)',
    dataAllowance: 'Unlimited',
    validityDays: 3,
    countryCode: 'HR',
    coverageType: 'local',
  ),
}) {
  return DeviceStatus(
    deviceExternalId: 'dev-1',
    bindingStatus: 'active',
    esim: DeviceStatusEsim(id: 9, iccid: _testIccid, status: esimStatus),
    usage: DeviceStatusUsage(
      dataRemaining: dataRemaining,
      dataUsed: '88 MB',
      expiresAt: expiresAt ?? DateTime.utc(2026, 9, 1),
    ),
    autoTopup: const DeviceStatusAutoTopup(enabled: true),
    plan: plan,
    checkedAt: DateTime.utc(2026, 8, 9, 14, 21),
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeReader reader,
  required _FakeStatusClient client,
  DateTime Function()? now,
  WidgetSnapshotStore? snapshotStore,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DeviceStatusPage(
        reader: reader,
        statusClient: client,
        now: now ?? () => DateTime.utc(2026, 8, 9, 12),
        snapshotStore: snapshotStore ?? NoopWidgetSnapshotStore(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('GREEN ACTIVE and never renders credential or ICCID', (
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

    await _pumpPage(tester, reader: reader, client: client);

    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('12 MB'), findsOneWidget);
    expect(find.text('Cronet (Croatia)'), findsOneWidget);
    expect(find.text('Unlimited · 3 days'), findsOneWidget);
    expect(find.text('🇭🇷'), findsOneWidget);
    expect(find.text(secret), findsNothing);
    expect(find.text(_testIccid), findsNothing);
    expect(find.textContaining('ICCID'), findsNothing);

    await tester.tap(find.byTooltip('Support menu'));
    await tester.pumpAndSettle();
    expect(find.text('Credential'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Auto-topup'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);
    expect(find.text(secret), findsNothing);
    expect(find.text(_testIccid), findsNothing);
    expect(client.calls, 1);
    expect(client.lastCredential, secret);
  });

  testWidgets('success RED NO DATA for zero remaining', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(
      status: _sampleStatus(dataRemaining: '0 MB'),
    );
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('NO DATA'), findsOneWidget);
    expect(find.text('No RoamKit data for this device'), findsNothing);
  });

  testWidgets('slate ICCID NO DATA is distinct from success NO DATA', (
    tester,
  ) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(
      error: const DeviceStatusIccidNotFoundException(),
    );
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('NO DATA'), findsOneWidget);
    expect(find.text('No RoamKit data for this device'), findsOneWidget);
    expect(find.text('ACTIVE'), findsNothing);
  });

  testWidgets('missing managed config is slate UNAVAILABLE', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(deviceExternalId: null, deviceCredential: null),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(find.text('Waiting for managed configuration'), findsOneWidget);
    expect(client.calls, 0);

    await tester.tap(find.byTooltip('Support menu'));
    await tester.pumpAndSettle();
    expect(find.text('Missing'), findsOneWidget);
  });

  testWidgets('404 UNAVAILABLE and reload on managed config change', (
    tester,
  ) async {
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

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('UNAVAILABLE'), findsOneWidget);
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

  testWidgets('rate limit TRY LATER and network OFFLINE', (tester) async {
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

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('TRY LATER'), findsOneWidget);

    client.error = DeviceStatusNetworkException('DNS lookup failed');
    await tester.tap(find.byTooltip('Reload status'));
    await tester.pumpAndSettle();
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Network error'), findsOneWidget);
  });

  testWidgets('failed refresh clears stale GREEN to slate error', (
    tester,
  ) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('ACTIVE'), findsOneWidget);

    client
      ..status = null
      ..error = DeviceStatusNetworkException('down');
    await tester.tap(find.byTooltip('Reload status'));
    await tester.pumpAndSettle();
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.text('OFFLINE'), findsOneWidget);
  });

  testWidgets('single-flight reload does not double-fetch', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final delay = Completer<DeviceStatus>();
    final client = _FakeStatusClient(status: _sampleStatus())..delay = delay;
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(
          reader: reader,
          statusClient: client,
          now: () => DateTime.utc(2026, 8, 9, 12),
          snapshotStore: NoopWidgetSnapshotStore(),
        ),
      ),
    );
    await tester.pump();
    expect(client.calls, 1);

    // Managed-config change during in-flight load must join the same request.
    reader.emit(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    await tester.pump();
    expect(client.calls, 1);

    delay.complete(_sampleStatus());
    await tester.pumpAndSettle();
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('publishes widget snapshot on success not during in-flight', (
    tester,
  ) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final delay = Completer<DeviceStatus>();
    final client = _FakeStatusClient(status: _sampleStatus())..delay = delay;
    final store = RecordingWidgetSnapshotStore();
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(
          reader: reader,
          statusClient: client,
          now: () => DateTime.utc(2026, 8, 9, 12),
          snapshotStore: store,
        ),
      ),
    );
    await tester.pump();
    expect(store.published, isEmpty);

    delay.complete(_sampleStatus());
    await tester.pumpAndSettle();
    expect(store.published, isNotEmpty);
    expect(store.published.last.surface, 'green');
    expect(store.published.last.hero, 'ACTIVE');
    expect(store.published.last.planTitle, 'Cronet (Croatia)');
  });

  testWidgets('publishes slate snapshot on error', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(
      error: DeviceStatusNetworkException('down'),
    );
    final store = RecordingWidgetSnapshotStore();
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      snapshotStore: store,
    );
    expect(store.published, isNotEmpty);
    expect(store.published.last.surface, 'slateError');
    expect(store.published.last.hero, 'OFFLINE');
  });

  testWidgets('in-flight refresh does not publish over prior snapshot', (
    tester,
  ) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    final store = RecordingWidgetSnapshotStore();
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      snapshotStore: store,
    );
    expect(store.published.length, 1);
    expect(store.published.single.hero, 'ACTIVE');

    final delay = Completer<DeviceStatus>();
    client.delay = delay;
    await tester.tap(find.byTooltip('Reload status'));
    await tester.pump();
    expect(store.published.length, 1);
    expect(store.published.single.surface, isNot('slateLoading'));

    delay.complete(
      _sampleStatus(dataRemaining: '1 GB'),
    );
    await tester.pumpAndSettle();
    expect(store.published.length, 2);
    expect(store.published.last.remaining, '1 GB');
  });

  testWidgets('plan null hides badge', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus(plan: null));
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Cronet (Croatia)'), findsNothing);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('long plan title uses ellipsis', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    const longTitle =
        'European Union and United Kingdom Mega Regional Roaming Pack Extra';
    final client = _FakeStatusClient(
      status: _sampleStatus(
        plan: const DeviceStatusPlan(
          title: longTitle,
          dataAllowance: '5 GB',
          validityDays: 30,
          coverageType: 'regional',
        ),
      ),
    );
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    final title = tester.widget<Text>(find.text(longTitle));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
  });

  testWidgets('global plan shows globe icon', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(
      status: _sampleStatus(
        plan: const DeviceStatusPlan(
          title: 'Discover',
          dataAllowance: '300 MB',
          validityDays: 3,
          coverageType: 'global',
        ),
      ),
    );
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets('Updated caption uses local time from UTC checkedAt', (
    tester,
  ) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final checkedAt = DateTime.utc(2026, 8, 9, 14, 21);
    final client = _FakeStatusClient(
      status: DeviceStatus(
        deviceExternalId: 'dev-1',
        bindingStatus: 'active',
        esim: const DeviceStatusEsim(
          id: 1,
          iccid: _testIccid,
          status: 'in_use',
        ),
        usage: DeviceStatusUsage(
          dataRemaining: '1.2 GB',
          dataUsed: '0 MB',
          expiresAt: DateTime.utc(2026, 9, 1),
        ),
        autoTopup: const DeviceStatusAutoTopup(enabled: false),
        checkedAt: checkedAt,
      ),
    );
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    final local = checkedAt.toLocal();
    final expected =
        'Updated ${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    expect(find.text(expected), findsOneWidget);
  });
}
