import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_packages.dart';
import 'package:roamkit_bbuem_apk/status/applied_packages.dart';
import 'package:roamkit_bbuem_apk/status/home_status_chrome.dart';
import 'package:roamkit_bbuem_apk/status/operational_status_view.dart';

AppliedPackage pkg(
  String status, {
  String id = '1',
  String kind = 'esim',
  String dataAllowance = '1 GB',
  int validityDays = 7,
  String? expiresAt,
  String? activatedAt,
  DateTime? createdAt,
}) {
  return AppliedPackage(
    id: id,
    kind: kind,
    status: status,
    dataAllowance: dataAllowance,
    validityDays: validityDays,
    isUnlimited: false,
    remainingMb: 100,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 1),
    activatedAt: activatedAt,
    expiresAt: expiresAt,
    paidUsd: '11.50',
    currency: 'USD',
  );
}

void main() {
  test('partitions current / previous and omits unknown', () {
    final groups = partitionAppliedPackages([
      pkg('active', id: 'a'),
      pkg('not_active', id: 'n'),
      pkg('expired', id: 'e'),
      pkg('finished', id: 'f'),
      pkg('queued', id: 'q'),
      pkg('weird', id: 'u'),
    ]);
    expect(groups.active.map((p) => p.id), ['a']);
    expect(groups.notActive.map((p) => p.id), ['n']);
    expect(groups.queued.map((p) => p.id), ['q']);
    expect(groups.previous.map((p) => p.id), ['e', 'f']);
    expect(groups.omittedUnknown.map((p) => p.id), ['u']);
    expect(groups.activeCount, 1);
    expect(groups.queuedHeaderCount, 2);
    expect(groups.headerSummary, '1 active · 2 queued');
    expect(groups.hasCurrent, isTrue);
  });

  test('leads with API active_package id', () {
    final groups = partitionAppliedPackages(
      [
        pkg('active', id: 'second'),
        pkg('active', id: 'first'),
      ],
      activePackage: pkg('active', id: 'first'),
    );
    expect(groups.active.map((p) => p.id), ['first', 'second']);
  });

  test('previous newest first by expires_at', () {
    final groups = partitionAppliedPackages([
      pkg('expired', id: 'old', expiresAt: '2026-08-01T00:00:00Z'),
      pkg('expired', id: 'new', expiresAt: '2026-08-10T00:00:00Z'),
    ]);
    expect(groups.previous.map((p) => p.id), ['new', 'old']);
  });

  test('not_active is Starts on first use; queued is Queued', () {
    expect(appliedPackageStatusLabel('not_active'), 'Starts on first use');
    expect(appliedPackageStatusLabel('queued'), 'Queued');
    expect(appliedPackageStatusLabel('expired'), 'Expired');
    expect(appliedPackageStatusLabel('weird'), 'Unknown');
  });

  test('kind and spec labels', () {
    expect(appliedPackageKindLabel('esim'), 'eSIM');
    expect(appliedPackageKindLabel('topup'), 'Top-up');
    expect(packageSpecLabel(pkg('active')), '1 GB · 7 days');
    expect(
      appliedPackageTitle(pkg('active', kind: 'topup')),
      'Top-up · 1 GB · 7 days',
    );
    expect(
      previousCardTitle([pkg('expired', dataAllowance: '300 MB', validityDays: 3)]),
      'Previous · 300 MB · 3 days',
    );
    expect(
      previousCardTitle([
        pkg('expired', id: '1'),
        pkg('expired', id: '2'),
        pkg('expired', id: '3'),
      ]),
      'Previous packages · 3',
    );
  });

  test('paid amount is local retail or omitted', () {
    expect(formatPaidAmount('11.50', 'USD'), r'$11.50 USD');
    expect(formatPaidAmountOrNull(null, 'USD'), isNull);
    expect(formatPaidAmount('nope', 'USD'), '—');
  });

  test('double gate hides title unless ACTIVE and active_package', () {
    final active = pkg('active', kind: 'topup');
    final view = OperationalStatusView(
      surface: StatusSurface.green,
      heroLabel: 'ACTIVE',
      isSuccessSnapshot: true,
    );
    expect(showHeroPackageTitle(view, active), isTrue);
    expect(
      showHeroPackageTitle(
        const OperationalStatusView(
          surface: StatusSurface.red,
          heroLabel: 'EXPIRED',
          isSuccessSnapshot: true,
        ),
        active,
      ),
      isFalse,
    );
    expect(showHeroPackageTitle(view, pkg('not_active')), isFalse);
    expect(showHeroPackageTitle(view, null), isFalse);
  });

  test('chrome maps success NO DATA to INACTIVE', () {
    final chrome = homeStatusChrome(
      const OperationalStatusView(
        surface: StatusSurface.red,
        heroLabel: 'NO DATA',
        isSuccessSnapshot: true,
      ),
    );
    expect(chrome.label, 'INACTIVE');
    expect(chrome.secondary, 'No active data package');
  });

  test('chrome maps slate errors to UNAVAILABLE', () {
    final chrome = homeStatusChrome(OperationalStatusView.loading());
    expect(chrome.kind, HomeStatusKind.unavailable);
    final offline = homeStatusChrome(
      const OperationalStatusView(
        surface: StatusSurface.slateError,
        heroLabel: 'OFFLINE',
        isSuccessSnapshot: false,
        errorDetail: 'Network error',
      ),
    );
    expect(offline.label, 'UNAVAILABLE');
    expect(offline.secondary, 'Status is temporarily unavailable');
  });
}
