import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage.dart';
import 'package:roamkit_bbuem_apk/api/device_coverage_client.dart';
import 'package:roamkit_bbuem_apk/api/device_packages.dart';
import 'package:roamkit_bbuem_apk/api/device_packages_client.dart';
import 'package:roamkit_bbuem_apk/api/device_status.dart';
import 'package:roamkit_bbuem_apk/api/device_status_client.dart';
import 'package:roamkit_bbuem_apk/api/device_status_errors.dart';
import 'package:roamkit_bbuem_apk/managed_config/managed_config.dart';
import 'package:roamkit_bbuem_apk/managed_config/managed_config_reader.dart';
import 'package:roamkit_bbuem_apk/ui/device_status_page.dart';
import 'package:roamkit_bbuem_apk/widget/widget_snapshot_store.dart';

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
  String? lastSerial;
  String? lastExternalId;
  Completer<DeviceStatus>? delay;

  @override
  Future<DeviceStatus> fetchStatus({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) async {
    calls += 1;
    lastSerial = deviceSerial;
    lastExternalId = deviceExternalId;
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

class _FakeCoverageClient implements DeviceCoverageClient {
  _FakeCoverageClient();

  DeviceCoverage? coverage;
  int calls = 0;

  @override
  Future<DeviceCoverage> fetchCoverage({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) async {
    calls += 1;
    return coverage ??
        DeviceCoverage(
          deviceExternalId: deviceExternalId ?? 'dev-1',
          coverageType: 'regional',
          coverage: const [
            DeviceCoverageCountry(
              countryCode: 'HR',
              countryName: 'Croatia',
              operators: ['A1'],
            ),
          ],
          checkedAt: DateTime.utc(2026, 8, 9),
        );
  }
}

class _FakePackagesClient implements DevicePackagesClient {
  _FakePackagesClient({this.snapshot, this.error});

  DevicePackages? snapshot;
  Object? error;
  int calls = 0;
  String? lastSerial;
  String? lastExternalId;
  String? lastCredential;
  Completer<DevicePackages>? delay;

  @override
  Future<DevicePackages> fetchPackages({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) async {
    calls += 1;
    lastSerial = deviceSerial;
    lastExternalId = deviceExternalId;
    lastCredential = credential;
    if (delay != null) {
      return delay!.future;
    }
    if (error != null) {
      throw error!;
    }
    return snapshot ??
        DevicePackages(
          deviceExternalId: deviceExternalId,
          iccid: _testIccid,
          results: const [],
          checkedAt: DateTime.utc(2026, 8, 9, 14, 21),
        );
  }
}

AppliedPackage _samplePackage({
  String id = '1',
  String kind = 'esim',
  String status = 'active',
  String dataAllowance = '1 GB',
  int validityDays = 7,
  bool isUnlimited = false,
  String? paidUsd = '11.50',
}) {
  return AppliedPackage(
    id: id,
    kind: kind,
    status: status,
    dataAllowance: dataAllowance,
    validityDays: validityDays,
    isUnlimited: isUnlimited,
    remainingMb: isUnlimited ? null : 900,
    createdAt: DateTime.utc(2026, 8, 1),
    activatedAt: status == 'not_active' ? null : '2026-08-12T10:50:00+00:00',
    expiresAt: status == 'not_active' ? null : '2026-08-19T10:50:00+00:00',
    paidUsd: paidUsd,
    currency: 'USD',
  );
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
  DeviceCoverageClient? coverageClient,
  DevicePackagesClient? packagesClient,
  Duration foregroundRefreshInterval = const Duration(minutes: 10),
  Duration resumeDebounce = const Duration(seconds: 60),
}) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: DeviceStatusPage(
        reader: reader,
        statusClient: client,
        coverageClient: coverageClient ?? _FakeCoverageClient(),
        packagesClient: packagesClient ?? _FakePackagesClient(),
        now: now ?? () => DateTime.utc(2026, 8, 9, 12),
        snapshotStore: snapshotStore ?? NoopWidgetSnapshotStore(),
        foregroundRefreshInterval: foregroundRefreshInterval,
        resumeDebounce: resumeDebounce,
      ),
    ),
  );
  // Short intervals: do not pumpAndSettle (one-shot would re-fire forever).
  if (foregroundRefreshInterval < const Duration(seconds: 1)) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  } else {
    await tester.pumpAndSettle();
  }
}

bool _hasForegroundTimer(WidgetTester tester) {
  final state = tester.state(find.byType(DeviceStatusPage));
  return (state as dynamic).debugHasForegroundTimer as bool;
}

void main() {
  testWidgets('GREEN ACTIVE shows ICCID and never renders credential', (
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

    expect(find.text('✓ ACTIVE'), findsOneWidget);
    expect(find.text('of 100 MB remaining'), findsOneWidget);
    expect(find.text('88 MB used'), findsOneWidget);
    expect(find.text('Cronet (Croatia)'), findsNothing);
    expect(find.text('Unlimited · 3 days'), findsNothing);
    expect(find.text('🇭🇷'), findsNothing);
    expect(find.text(secret), findsNothing);
    expect(find.text(_testIccid), findsOneWidget);

    await tester.tap(find.byTooltip('Support menu'));
    await tester.pumpAndSettle();
    expect(find.text('Credential'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Auto-topup'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);
    expect(find.text(secret), findsNothing);
    expect(find.text('Device binding'), findsOneWidget);
    expect(client.calls, 1);
    expect(client.lastCredential, secret);
  });

  testWidgets('serial managed config prefers serial status path', (tester) async {
    const serial = '36281JEGR04531';
    final reader = _FakeReader(
      const ManagedConfig(
        deviceSerial: serial,
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret-must-not-be-sent',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);

    expect(find.text('✓ ACTIVE'), findsOneWidget);
    expect(client.calls, 1);
    expect(client.lastSerial, serial);
    expect(client.lastExternalId, isNull);
    expect(client.lastCredential, isNull);

    await tester.tap(find.byTooltip('Support menu'));
    await tester.pumpAndSettle();
    expect(find.text('Device serial'), findsOneWidget);
    expect(find.text(serial), findsOneWidget);
  });

  testWidgets('serial-only config loads status without PR18 keys', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceSerial: '36281JEGR04531',
        deviceExternalId: null,
        deviceCredential: null,
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);

    expect(find.text('✓ ACTIVE'), findsOneWidget);
    expect(client.calls, 1);
    expect(client.lastSerial, '36281JEGR04531');
    expect(client.lastCredential, isNull);
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
    expect(find.text('○ INACTIVE'), findsOneWidget);
    expect(find.text('No active data package'), findsOneWidget);
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
    expect(find.text('↻ UNAVAILABLE'), findsOneWidget);
    expect(find.text('Status is temporarily unavailable'), findsOneWidget);
    expect(find.text('✓ ACTIVE'), findsNothing);
  });

  testWidgets('missing managed config is slate UNAVAILABLE', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(deviceExternalId: null, deviceCredential: null),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('↻ UNAVAILABLE'), findsOneWidget);
    expect(find.text('Status is temporarily unavailable'), findsOneWidget);
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
    expect(find.text('↻ UNAVAILABLE'), findsOneWidget);
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
    expect(find.text('✓ ACTIVE'), findsOneWidget);
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
    expect(find.text('↻ UNAVAILABLE'), findsOneWidget);
    expect(find.text('Status is temporarily unavailable'), findsOneWidget);

    client.error = DeviceStatusNetworkException('DNS lookup failed');
    await tester.tap(find.byTooltip('Reload status'));
    await tester.pumpAndSettle();
    expect(find.text('↻ UNAVAILABLE'), findsOneWidget);
    expect(find.text('Status is temporarily unavailable'), findsOneWidget);
  });

  testWidgets('failed refresh keeps last-good ACTIVE hero', (
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
    expect(find.text('✓ ACTIVE'), findsOneWidget);
    expect(find.text(_testIccid), findsOneWidget);

    client
      ..status = null
      ..error = DeviceStatusNetworkException('down');
    await tester.tap(find.byTooltip('Reload status'));
    await tester.pumpAndSettle();
    expect(find.text('✓ ACTIVE'), findsOneWidget);
    expect(find.text(_testIccid), findsOneWidget);
    expect(find.text('Couldn’t refresh status'), findsOneWidget);
    expect(find.text('OFFLINE'), findsNothing);
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
          coverageClient: _FakeCoverageClient(),
          packagesClient: _FakePackagesClient(),
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
    expect(find.text('✓ ACTIVE'), findsOneWidget);
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
          coverageClient: _FakeCoverageClient(),
          packagesClient: _FakePackagesClient(),
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
    expect(store.published.last.displayStatus, 'active');
    expect(store.published.last.statusLabel, 'ACTIVE');
    expect(store.published.last.activePackageTitle, isNull);
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
    expect(store.published.last.displayStatus, 'unavailable');
    expect(store.published.last.statusLabel, 'UNAVAILABLE');
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
    expect(store.published.single.displayStatus, 'active');

    final delay = Completer<DeviceStatus>();
    client.delay = delay;
    await tester.tap(find.byTooltip('Reload status'));
    await tester.pump();
    expect(store.published.length, 1);
    expect(store.published.single.displayStatus, isNot('unavailable'));

    delay.complete(
      _sampleStatus(dataRemaining: '1 GB'),
    );
    await tester.pumpAndSettle();
    expect(store.published.length, 2);
    expect(store.published.last.remainingText, '1 GB');
  });

  testWidgets('regional coverage shows affordance and opens Coverage screen', (
    tester,
  ) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(
      status: _sampleStatus(
        plan: const DeviceStatusPlan(
          title: 'Europe',
          dataAllowance: '5 GB',
          validityDays: 30,
          coverageType: 'regional',
          coverageSummary: DeviceStatusCoverageSummary(
            available: true,
            countryCount: 2,
          ),
        ),
      ),
    );
    final coverage = _FakeCoverageClient();
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      coverageClient: coverage,
    );
    expect(find.text('View coverage'), findsOneWidget);

    await tester.tap(find.text('View coverage'));
    await tester.pumpAndSettle();
    expect(find.text('Coverage'), findsOneWidget);
    expect(find.text('Croatia'), findsOneWidget);
    expect(coverage.calls, 1);
  });

  testWidgets(
    'support menu Coverage opens country list after sheet closes',
    (tester) async {
      final reader = _FakeReader(
        const ManagedConfig(
          deviceSerial: '36281JEGR04531',
          deviceExternalId: null,
          deviceCredential: null,
        ),
      );
      final client = _FakeStatusClient(
        status: _sampleStatus(
          plan: const DeviceStatusPlan(
            title: '300 MB - 3 days',
            dataAllowance: '300 MB',
            validityDays: 3,
            coverageType: 'global',
            coverageSummary: DeviceStatusCoverageSummary(
              available: true,
              countryCount: 165,
            ),
          ),
        ),
      );
      final coverage = _FakeCoverageClient();
      addTearDown(reader.dispose);

      await _pumpPage(
        tester,
        reader: reader,
        client: client,
        coverageClient: coverage,
      );

      await tester.tap(find.byTooltip('Support menu'));
      await tester.pumpAndSettle();
      expect(find.text('Coverage'), findsOneWidget);
      expect(find.text('165 countries'), findsOneWidget);

      await tester.tap(find.text('Coverage'));
      await tester.pumpAndSettle();
      // Sheet must be gone; Coverage screen shows the country list.
      expect(find.text('165 countries'), findsNothing);
      expect(find.text('Croatia'), findsOneWidget);
      expect(find.text('1 country'), findsOneWidget);
      expect(coverage.calls, 1);
    },
  );

  testWidgets('local plan does not show Coverage entry', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(
      status: _sampleStatus(
        plan: const DeviceStatusPlan(
          title: 'Cronet (Croatia)',
          dataAllowance: 'Unlimited',
          validityDays: 3,
          countryCode: 'HR',
          coverageType: 'local',
          coverageSummary: DeviceStatusCoverageSummary(
            available: false,
            countryCount: 1,
          ),
        ),
      ),
    );
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text('View coverage'), findsNothing);

    await tester.tap(find.byTooltip('Support menu'));
    await tester.pumpAndSettle();
    expect(find.text('Coverage'), findsNothing);
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
    expect(find.text('✓ ACTIVE'), findsOneWidget);
    expect(find.text('Cronet (Croatia)'), findsNothing);
    expect(find.text(_testIccid), findsOneWidget);
  });

  testWidgets('plan title is never a hero fallback', (tester) async {
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
    expect(find.text(longTitle), findsNothing);
    expect(find.text('Discover'), findsNothing);
    expect(find.byIcon(Icons.map_outlined), findsNothing);
  });

  testWidgets('hero title comes from active_package not plan', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(
      status: _sampleStatus(
        plan: const DeviceStatusPlan(
          title: '300 MB - 3 days',
          dataAllowance: '300 MB',
          validityDays: 3,
        ),
      ),
    );
    final active = _samplePackage(
      id: 'topup-active',
      kind: 'topup',
      status: 'active',
      dataAllowance: '1 GB',
      validityDays: 7,
    );
    final packages = _FakePackagesClient(
      snapshot: DevicePackages(
        deviceExternalId: 'dev-1',
        iccid: _testIccid,
        results: [
          _samplePackage(
            id: 'esim-old',
            kind: 'esim',
            status: 'expired',
            dataAllowance: '300 MB',
            validityDays: 3,
          ),
          active,
          _samplePackage(id: 'queued', kind: 'topup', status: 'queued'),
        ],
        activePackage: active,
        checkedAt: DateTime.utc(2026, 8, 9),
      ),
    );
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      packagesClient: packages,
    );
    expect(find.text('Top-up · 1 GB · 7 days'), findsWidgets);
    expect(find.text('300 MB - 3 days'), findsNothing);
    expect(find.textContaining('Previous'), findsOneWidget);
    expect(find.textContaining('300 MB · 3 days'), findsWidgets);
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
    expect(find.textContaining('Updated'), findsOneWidget);
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('initial load complete arms one-shot; fires only after interval', (
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

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      foregroundRefreshInterval: const Duration(milliseconds: 100),
      resumeDebounce: const Duration(milliseconds: 50),
    );
    expect(client.calls, 1);
    expect(_hasForegroundTimer(tester), isTrue);

    await tester.pump(const Duration(milliseconds: 50));
    expect(client.calls, 1);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 2);
    expect(_hasForegroundTimer(tester), isTrue);
  });

  testWidgets('long-running reload does not catch-up refresh on complete', (
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
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(
          reader: reader,
          statusClient: client,
          packagesClient: _FakePackagesClient(),
          now: () => DateTime.utc(2026, 8, 9, 12),
          snapshotStore: NoopWidgetSnapshotStore(),
          foregroundRefreshInterval: const Duration(milliseconds: 80),
        ),
      ),
    );
    await tester.pump();
    expect(client.calls, 1);
    expect(_hasForegroundTimer(tester), isFalse);

    // Stay in-flight longer than the interval would have been.
    await tester.pump(const Duration(milliseconds: 120));
    expect(client.calls, 1);

    delay.complete(_sampleStatus());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 1);
    expect(_hasForegroundTimer(tester), isTrue);

    // Next fire only after a full interval from completion.
    await tester.pump(const Duration(milliseconds: 40));
    expect(client.calls, 1);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 2);
  });

  testWidgets('managed-config reload resets one-shot cadence', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      foregroundRefreshInterval: const Duration(milliseconds: 100),
    );
    expect(client.calls, 1);

    await tester.pump(const Duration(milliseconds: 60));
    reader.emit(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 2);

    // Config reload re-armed: must wait full interval again.
    await tester.pump(const Duration(milliseconds: 60));
    expect(client.calls, 2);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 3);
  });

  testWidgets('pause cancels timer; resume debounce skips recent reload', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 9, 12);
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      now: () => now,
      foregroundRefreshInterval: const Duration(minutes: 10),
      resumeDebounce: const Duration(seconds: 60),
    );
    expect(client.calls, 1);
    expect(_hasForegroundTimer(tester), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(_hasForegroundTimer(tester), isFalse);

    now = now.add(const Duration(seconds: 30));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 1);
    expect(_hasForegroundTimer(tester), isTrue);

    now = now.add(const Duration(seconds: 45));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 2);
  });

  testWidgets('clock rollback fail-opens resume reload', (tester) async {
    var now = DateTime.utc(2026, 8, 9, 12);
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      now: () => now,
      resumeDebounce: const Duration(hours: 1),
      foregroundRefreshInterval: const Duration(hours: 1),
    );
    expect(client.calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = now.subtract(const Duration(hours: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 2);
  });

  testWidgets('dispose while in-flight does not re-arm timer', (tester) async {
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
          packagesClient: _FakePackagesClient(),
          snapshotStore: NoopWidgetSnapshotStore(),
          foregroundRefreshInterval: const Duration(milliseconds: 50),
        ),
      ),
    );
    await tester.pump();
    expect(client.calls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    delay.complete(_sampleStatus());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 1);
  });

  testWidgets('resume and timer race still single-flight; one timer remains', (
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
    addTearDown(reader.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(
          reader: reader,
          statusClient: client,
          packagesClient: _FakePackagesClient(),
          snapshotStore: NoopWidgetSnapshotStore(),
          foregroundRefreshInterval: const Duration(milliseconds: 40),
          resumeDebounce: const Duration(hours: 1),
        ),
      ),
    );
    await tester.pump();
    expect(client.calls, 1);

    delay.complete(_sampleStatus());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 1);
    expect(_hasForegroundTimer(tester), isTrue);

    // Fire the one-shot and resume in the same turn; single-flight joins.
    await tester.pump(const Duration(milliseconds: 40));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    // Resume is debounced (1h); only the timer fire should reload.
    expect(client.calls, 2);
    expect(_hasForegroundTimer(tester), isTrue);

    for (var i = 0; i < 3; i++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(_hasForegroundTimer(tester), isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(_hasForegroundTimer(tester), isTrue);
    }
  });

  testWidgets('open loads packages; timer refreshes status only', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    final packages = _FakePackagesClient(
      snapshot: DevicePackages(
        deviceExternalId: 'dev-1',
        iccid: _testIccid,
        results: [
          _samplePackage(),
          _samplePackage(id: '2', kind: 'topup', status: 'not_active'),
        ],
        checkedAt: DateTime.utc(2026, 8, 9),
      ),
    );
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      packagesClient: packages,
      foregroundRefreshInterval: const Duration(milliseconds: 100),
    );
    expect(client.calls, 1);
    expect(packages.calls, 1);
    expect(find.text('1 active · 1 queued'), findsOneWidget);
    expect(find.text('Starts on first use'), findsOneWidget);
    expect(find.text('Packages'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 1));
    expect(client.calls, 2);
    expect(packages.calls, 1);
  });

  testWidgets('packages failure keeps hero and shows Retry', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    final packages = _FakePackagesClient(
      error: const DevicePackagesProviderUnavailableException(),
    );
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      packagesClient: packages,
    );
    expect(find.text('✓ ACTIVE'), findsOneWidget);
    expect(find.text(_testIccid), findsOneWidget);
    expect(find.text('of 100 MB remaining'), findsOneWidget);
    expect(find.text('Couldn’t refresh packages'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('copy ICCID shows Copied confirmation', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    addTearDown(reader.dispose);

    await _pumpPage(tester, reader: reader, client: client);
    expect(find.text(_testIccid), findsOneWidget);
    await tester.tap(find.byTooltip('Copy ICCID'));
    await tester.pump();
    expect(find.text('ICCID copied'), findsWidgets);
  });

  testWidgets('unknown package is not labeled Expired', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    final packages = _FakePackagesClient(
      snapshot: DevicePackages(
        deviceExternalId: 'dev-1',
        iccid: _testIccid,
        results: [
          _samplePackage(id: 'u', status: 'mystery'),
        ],
        checkedAt: DateTime.utc(2026, 8, 9),
      ),
    );
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      packagesClient: packages,
    );
    expect(find.text('Unknown'), findsNothing);
    expect(find.text('Queued'), findsNothing);
    expect(find.text('Starts on first use'), findsNothing);
    expect(find.text('Packages'), findsNothing);
  });

  testWidgets('EXPIRED hides last-good active_package title', (tester) async {
    final reader = _FakeReader(
      const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      ),
    );
    final client = _FakeStatusClient(
      status: _sampleStatus(expiresAt: DateTime.utc(2026, 8, 1)),
    );
    final active = _samplePackage(id: 'still-active', kind: 'topup');
    final packages = _FakePackagesClient(
      snapshot: DevicePackages(
        deviceExternalId: 'dev-1',
        iccid: _testIccid,
        results: [active],
        activePackage: active,
        checkedAt: DateTime.utc(2026, 8, 9),
      ),
    );
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      packagesClient: packages,
    );
    expect(find.text('! EXPIRED'), findsOneWidget);
    expect(find.text('Data package expired'), findsOneWidget);
    expect(find.text('Top-up · 1 GB · 7 days'), findsOneWidget);
    expect(find.text('Expired'), findsWidgets);
  });

  testWidgets('packages POST uses serial and never a client ICCID', (
    tester,
  ) async {
    const serial = '36281JEGR04531';
    final reader = _FakeReader(
      const ManagedConfig(
        deviceSerial: serial,
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret-must-not-be-sent',
      ),
    );
    final client = _FakeStatusClient(status: _sampleStatus());
    final packages = _FakePackagesClient();
    addTearDown(reader.dispose);

    await _pumpPage(
      tester,
      reader: reader,
      client: client,
      packagesClient: packages,
    );
    expect(packages.calls, 1);
    expect(packages.lastSerial, serial);
    expect(packages.lastCredential, isNull);
    expect(packages.lastExternalId, isNull);
  });
}
