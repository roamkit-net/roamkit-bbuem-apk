import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_packages.dart';
import 'package:roamkit_bbuem_apk/api/device_status.dart';
import 'package:roamkit_bbuem_apk/api/device_status_errors.dart';
import 'package:roamkit_bbuem_apk/status/operational_status_view.dart';
import 'package:roamkit_bbuem_apk/status/usage_bar_view.dart';
import 'package:roamkit_bbuem_apk/widget/widget_snapshot.dart';

void main() {
  final now = DateTime.utc(2026, 8, 14, 12, 35);

  test('home_widget provider FQCNs stay on both receivers', () {
    expect(
      WidgetSnapshot.compactProvider,
      'net.roamkit.bbuem.RoamKitCompactWidgetProvider',
    );
    expect(
      WidgetSnapshot.wideProvider,
      'net.roamkit.bbuem.RoamKitWideWidgetProvider',
    );
  });

  AppliedPackage activeTopup() {
    return AppliedPackage(
      id: 'pkg-1',
      kind: 'topup',
      status: 'active',
      dataAllowance: '1 GB',
      validityDays: 7,
      isUnlimited: false,
      remainingMb: 900,
      createdAt: now,
      activatedAt: '2026-08-12T10:50:00+00:00',
      expiresAt: '2026-08-19T10:50:00+00:00',
      paidUsd: '4.00',
      currency: 'USD',
    );
  }

  OperationalStatusView activeView() {
    return evaluateOperationalView(
      DeviceStatus(
        deviceExternalId: 'dev-1',
        bindingStatus: 'active',
        esim: const DeviceStatusEsim(id: 1, iccid: '8910', status: 'in_use'),
        usage: DeviceStatusUsage(
          dataRemaining: '1926 MB',
          dataUsed: '122 MB',
          expiresAt: DateTime.utc(2026, 9, 1),
        ),
        autoTopup: const DeviceStatusAutoTopup(enabled: false),
        checkedAt: now,
      ),
      now: now,
    );
  }

  UsageBarView meteredBar() {
    return buildUsageBarView(
      dataRemaining: '1926 MB',
      dataUsed: '122 MB',
    );
  }

  test('ACTIVE + valid active_package shows kind · spec title', () {
    final snap = WidgetSnapshot.fromState(
      view: activeView(),
      activePackage: activeTopup(),
      bar: meteredBar(),
      coverageAvailable: true,
      packagesFailed: false,
      now: now,
    );
    expect(snap.schemaVersion, 2);
    expect(snap.displayStatus, 'active');
    expect(snap.statusLabel, 'ACTIVE');
    expect(snap.activePackageTitle, 'Top-up · 1 GB · 7 days');
    expect(snap.hasUsage, isTrue);
    expect(snap.remainingText, '1.88 GB');
    expect(snap.totalText, '2 GB');
    expect(snap.usedText, '122 MB');
    expect(snap.percent, 94);
    expect(snap.coverageAvailable, isTrue);
    expect(snap.updateUnavailable, isFalse);
    expect(snap.containsForbiddenKeys, isFalse);
  });

  test('double gate: not_active is never a title fallback', () {
    final queued = AppliedPackage(
      id: 'q',
      kind: 'topup',
      status: 'not_active',
      dataAllowance: '1 GB',
      validityDays: 7,
      isUnlimited: false,
      remainingMb: 1024,
      createdAt: now,
      activatedAt: null,
      expiresAt: null,
      paidUsd: '4.00',
      currency: 'USD',
    );
    final snap = WidgetSnapshot.fromState(
      view: activeView(),
      activePackage: queued,
      bar: meteredBar(),
      coverageAvailable: false,
      packagesFailed: false,
      now: now,
    );
    expect(snap.activePackageTitle, isNull);
    expect(snap.hasUsage, isTrue);
  });

  test('ACTIVE without package hides title and keeps usage', () {
    final snap = WidgetSnapshot.fromState(
      view: activeView(),
      activePackage: null,
      bar: meteredBar(),
      coverageAvailable: false,
      packagesFailed: false,
      now: now,
    );
    expect(snap.displayStatus, 'active');
    expect(snap.activePackageTitle, isNull);
    expect(snap.hasUsage, isTrue);
    expect(snap.percent, 94);
  });

  test('packages error hides title but keeps ACTIVE', () {
    final snap = WidgetSnapshot.fromState(
      view: activeView(),
      activePackage: activeTopup(),
      bar: meteredBar(),
      coverageAvailable: true,
      packagesFailed: true,
      now: now,
    );
    expect(snap.displayStatus, 'active');
    expect(snap.activePackageTitle, isNull);
    expect(snap.hasUsage, isTrue);
    expect(snap.updateUnavailable, isFalse);
  });

  test('ACTIVE missing usage sets has_usage false', () {
    final snap = WidgetSnapshot.fromState(
      view: activeView(),
      activePackage: activeTopup(),
      bar: const UsageBarView.unavailable(),
      coverageAvailable: false,
      packagesFailed: false,
      now: now,
    );
    expect(snap.displayStatus, 'active');
    expect(snap.hasUsage, isFalse);
    expect(snap.activePackageTitle, 'Top-up · 1 GB · 7 days');
  });

  test('unlimited has no percent for native to show', () {
    final snap = WidgetSnapshot.fromState(
      view: activeView(),
      activePackage: activeTopup(),
      bar: const UsageBarView.unlimited(),
      coverageAvailable: false,
      packagesFailed: false,
      now: now,
    );
    expect(snap.unlimited, isTrue);
    expect(snap.hasUsage, isTrue);
    expect(snap.remainingText, 'Unlimited');
    expect(snap.percent, 100);
  });

  test('EXPIRED has no usage', () {
    final view = evaluateOperationalView(
      DeviceStatus(
        deviceExternalId: 'dev-1',
        bindingStatus: 'active',
        esim: const DeviceStatusEsim(id: 1, iccid: '8910', status: 'in_use'),
        usage: DeviceStatusUsage(
          dataRemaining: '12 MB',
          dataUsed: '88 MB',
          expiresAt: DateTime.utc(2026, 8, 1),
        ),
        autoTopup: const DeviceStatusAutoTopup(enabled: false),
        checkedAt: now,
      ),
      now: now,
    );
    final snap = WidgetSnapshot.fromState(
      view: view,
      activePackage: activeTopup(),
      bar: meteredBar(),
      coverageAvailable: true,
      packagesFailed: false,
      now: now,
    );
    expect(snap.displayStatus, 'expired');
    expect(snap.activePackageTitle, isNull);
    expect(snap.hasUsage, isFalse);
  });

  test('UNAVAILABLE last-good keeps usage and hides title', () {
    final lastGood = WidgetSnapshot.fromState(
      view: activeView(),
      activePackage: activeTopup(),
      bar: meteredBar(),
      coverageAvailable: true,
      packagesFailed: false,
      now: now,
    );
    final snap = WidgetSnapshot.fromState(
      view: OperationalStatusView.fromException(
        DeviceStatusNetworkException('down'),
      ),
      bar: const UsageBarView.unavailable(),
      coverageAvailable: false,
      packagesFailed: true,
      lastGood: lastGood,
      now: now.add(const Duration(minutes: 1)),
    );
    expect(snap.displayStatus, 'unavailable');
    expect(snap.activePackageTitle, isNull);
    expect(snap.hasUsage, isTrue);
    expect(snap.remainingText, '1.88 GB');
    expect(snap.percent, 94);
    expect(snap.updateUnavailable, isTrue);
    expect(snap.lastSuccessAt, lastGood.lastSuccessAt);
  });

  test('UNAVAILABLE without last-good has no ring', () {
    final snap = WidgetSnapshot.fromState(
      view: OperationalStatusView.fromException(
        const MissingManagedConfigException(),
      ),
      bar: const UsageBarView.unavailable(),
      coverageAvailable: false,
      packagesFailed: true,
      now: now,
    );
    expect(snap.displayStatus, 'unavailable');
    expect(snap.hasUsage, isFalse);
    expect(snap.updateUnavailable, isFalse);
    expect(snap.lastSuccessAt, isNull);
  });

  test('atomic JSON has only v2 keys and no secrets', () {
    final snap = WidgetSnapshot.fromState(
      view: activeView(),
      activePackage: activeTopup(),
      bar: meteredBar(),
      coverageAvailable: true,
      packagesFailed: false,
      now: now,
    );
    expect(
      snap.toJson().keys.toSet(),
      {
        'schema_version',
        'generated_at',
        'last_success_at',
        'display_status',
        'status_label',
        'active_package_title',
        'has_usage',
        'remaining_text',
        'total_text',
        'used_text',
        'percent',
        'unlimited',
        'coverage_available',
        'update_unavailable',
      },
    );
    expect(snap.toJsonString().toLowerCase().contains('iccid'), isFalse);
    expect(snap.toJsonString().toLowerCase().contains('credential'), isFalse);
    final roundTrip = WidgetSnapshot.fromJsonString(snap.toJsonString());
    expect(roundTrip.percent, 94);
    expect(roundTrip.activePackageTitle, 'Top-up · 1 GB · 7 days');
  });

  test('unknown schema and status fail fromJson', () {
    expect(
      () => WidgetSnapshot.fromJsonString('{"schema_version":1}'),
      throwsFormatException,
    );
    expect(
      () => WidgetSnapshot.fromJsonString(
        '{"schema_version":2,"display_status":"green"}',
      ),
      throwsFormatException,
    );
  });

  test('older generated_at must not overwrite newer', () {
    final newer = WidgetSnapshot.fromState(
      view: activeView(),
      bar: meteredBar(),
      coverageAvailable: false,
      packagesFailed: false,
      now: now,
    );
    final older = newer.copyWith(
      generatedAt: now.subtract(const Duration(minutes: 5)).toIso8601String(),
    );
    expect(snapshotIsStaleWrite(newer, older), isTrue);
    expect(snapshotIsStaleWrite(older, newer), isFalse);
  });

  test('stale mark keeps usage', () {
    final active = WidgetSnapshot.fromState(
      view: activeView(),
      activePackage: activeTopup(),
      bar: meteredBar(),
      coverageAvailable: true,
      packagesFailed: false,
      now: now,
    );
    final stale = active.markStale(now: now.add(const Duration(hours: 1)));
    expect(stale.displayStatus, 'unavailable');
    expect(stale.updateUnavailable, isTrue);
    expect(stale.activePackageTitle, isNull);
    expect(stale.hasUsage, isTrue);
    expect(stale.percent, 94);
  });
}
