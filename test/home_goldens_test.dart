import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_packages.dart';
import 'package:roamkit_bbuem_apk/api/device_packages_client.dart';
import 'package:roamkit_bbuem_apk/api/device_status.dart';
import 'package:roamkit_bbuem_apk/api/device_status_client.dart';
import 'package:roamkit_bbuem_apk/api/device_status_errors.dart';
import 'package:roamkit_bbuem_apk/managed_config/managed_config.dart';
import 'package:roamkit_bbuem_apk/managed_config/managed_config_reader.dart';
import 'package:roamkit_bbuem_apk/ui/device_status_page.dart';
import 'package:roamkit_bbuem_apk/ui/home_tokens.dart';
import 'package:roamkit_bbuem_apk/widget/widget_snapshot_store.dart';

class _Reader implements ManagedConfigReader {
  @override
  Stream<ManagedConfig> get changes => const Stream.empty();

  @override
  Future<ManagedConfig> read() async => const ManagedConfig(
        deviceExternalId: 'dev-1',
        deviceCredential: 'secret',
      );
}

class _Status implements DeviceStatusClient {
  _Status(this.status);

  final DeviceStatus status;

  @override
  Future<DeviceStatus> fetchStatus({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) async {
    return status;
  }
}

class _Packages implements DevicePackagesClient {
  _Packages(this.snapshot, {this.error});

  final DevicePackages? snapshot;
  final Object? error;

  @override
  Future<DevicePackages> fetchPackages({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) async {
    if (error != null) {
      throw error!;
    }
    return snapshot ??
        DevicePackages(
          deviceExternalId: deviceExternalId,
          iccid: '8900424101001825931',
          results: const [],
          checkedAt: DateTime.utc(2026, 8, 9),
        );
  }
}

AppliedPackage _pkg({
  required String id,
  required String status,
  String kind = 'topup',
  String data = '1 GB',
  int days = 7,
}) {
  return AppliedPackage(
    id: id,
    kind: kind,
    status: status,
    dataAllowance: data,
    validityDays: days,
    isUnlimited: false,
    remainingMb: 900,
    createdAt: DateTime.utc(2026, 8, 1),
    activatedAt: '2026-08-12T10:50:00+00:00',
    expiresAt: '2026-08-19T10:50:00+00:00',
    paidUsd: '11.50',
    currency: 'USD',
  );
}

DeviceStatus _status({
  String esimStatus = 'in_use',
  DateTime? expiresAt,
  String remaining = '1.88 GB',
  String used = '122 MB',
}) {
  return DeviceStatus(
    deviceExternalId: 'dev-1',
    bindingStatus: 'active',
    esim: DeviceStatusEsim(
      id: 1,
      iccid: '8900424101001825931',
      status: esimStatus,
    ),
    usage: DeviceStatusUsage(
      dataRemaining: remaining,
      dataUsed: used,
      expiresAt: expiresAt ?? DateTime.utc(2026, 8, 26, 12),
    ),
    autoTopup: const DeviceStatusAutoTopup(enabled: false),
    checkedAt: DateTime.utc(2026, 8, 9, 10, 35),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required DeviceStatusClient status,
  DevicePackagesClient? packages,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: DeviceStatusPage(
        reader: _Reader(),
        statusClient: status,
        packagesClient: packages ?? _Packages(null),
        now: () => DateTime.utc(2026, 8, 14, 12),
        snapshotStore: NoopWidgetSnapshotStore(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _assertNoFullScreenStatusColor(WidgetTester tester) {
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
  expect(scaffold.backgroundColor, HomeTokens.background);
  expect(
    scaffold.backgroundColor,
    isNot(const Color(0xFF15803D)),
  );
  expect(
    scaffold.backgroundColor,
    isNot(const Color(0xFFB91C1C)),
  );
}

void main() {
  testWidgets('golden: active package', (tester) async {
    final active = _pkg(id: 'a', status: 'active');
    await _pump(
      tester,
      status: _Status(_status()),
      packages: _Packages(
        DevicePackages(
          deviceExternalId: 'dev-1',
          iccid: '8900424101001825931',
          results: [active],
          activePackage: active,
          checkedAt: DateTime.utc(2026, 8, 9),
        ),
      ),
    );
    _assertNoFullScreenStatusColor(tester);
    expect(find.text('Top-up · 1 GB · 7 days'), findsWidgets);
    await expectLater(
      find.byType(DeviceStatusPage),
      matchesGoldenFile('goldens/home_active.png'),
    );
  });

  testWidgets('golden: active without package title', (tester) async {
    await _pump(tester, status: _Status(_status()));
    expect(find.text('Top-up · 1 GB · 7 days'), findsNothing);
    _assertNoFullScreenStatusColor(tester);
    await expectLater(
      find.byType(DeviceStatusPage),
      matchesGoldenFile('goldens/home_active_no_title.png'),
    );
  });

  testWidgets('golden: expired', (tester) async {
    await _pump(
      tester,
      status: _Status(_status(expiresAt: DateTime.utc(2026, 8, 1))),
    );
    expect(find.text('! EXPIRED'), findsOneWidget);
    _assertNoFullScreenStatusColor(tester);
    await expectLater(
      find.byType(DeviceStatusPage),
      matchesGoldenFile('goldens/home_expired.png'),
    );
  });

  testWidgets('golden: unavailable with last-good', (tester) async {
    final reader = _Reader();
    final client = _LastGoodThenFail();
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(
          reader: reader,
          statusClient: client,
          packagesClient: _Packages(null),
          now: () => DateTime.utc(2026, 8, 14, 12),
          snapshotStore: NoopWidgetSnapshotStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reload status'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t refresh status'), findsOneWidget);
    _assertNoFullScreenStatusColor(tester);
    await expectLater(
      find.byType(DeviceStatusPage),
      matchesGoldenFile('goldens/home_unavailable_last_good.png'),
    );
  });

  testWidgets('golden: first loading', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceStatusPage(
          reader: _Reader(),
          statusClient: _HangStatus(),
          packagesClient: _HangPackages(),
          now: () => DateTime.utc(2026, 8, 14, 12),
          snapshotStore: NoopWidgetSnapshotStore(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    _assertNoFullScreenStatusColor(tester);
    await expectLater(
      find.byType(DeviceStatusPage),
      matchesGoldenFile('goldens/home_loading.png'),
    );
  });

  testWidgets('golden: packages error', (tester) async {
    await _pump(
      tester,
      status: _Status(_status()),
      packages: _Packages(
        null,
        error: const DevicePackagesProviderUnavailableException(),
      ),
    );
    expect(find.text('Couldn’t refresh packages'), findsOneWidget);
    _assertNoFullScreenStatusColor(tester);
    await expectLater(
      find.byType(DeviceStatusPage),
      matchesGoldenFile('goldens/home_packages_error.png'),
    );
  });
}

class _LastGoodThenFail implements DeviceStatusClient {
  var _calls = 0;

  @override
  Future<DeviceStatus> fetchStatus({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) async {
    _calls += 1;
    if (_calls == 1) {
      return _status();
    }
    throw DeviceStatusNetworkException('down');
  }
}

class _HangStatus implements DeviceStatusClient {
  @override
  Future<DeviceStatus> fetchStatus({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) {
    return Completer<DeviceStatus>().future;
  }
}

class _HangPackages implements DevicePackagesClient {
  @override
  Future<DevicePackages> fetchPackages({
    String? deviceSerial,
    String? deviceExternalId,
    String? credential,
  }) {
    return Completer<DevicePackages>().future;
  }
}
