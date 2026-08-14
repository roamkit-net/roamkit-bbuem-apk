import 'package:flutter_test/flutter_test.dart';
import 'package:roamkit_bbuem_apk/api/device_packages.dart';
import 'package:roamkit_bbuem_apk/status/applied_packages.dart';

AppliedPackage pkg(String status, {String id = '1', String kind = 'esim'}) {
  return AppliedPackage(
    id: id,
    kind: kind,
    status: status,
    dataAllowance: '1 GB',
    validityDays: 7,
    isUnlimited: false,
    remainingMb: 100,
    createdAt: DateTime.utc(2026, 8, 1),
    activatedAt: null,
    expiresAt: null,
    paidUsd: '11.50',
    currency: 'USD',
  );
}

void main() {
  test('partitions available / previous / unknown', () {
    final groups = partitionAppliedPackages([
      pkg('active', id: 'a'),
      pkg('not_active', id: 'n'),
      pkg('expired', id: 'e'),
      pkg('finished', id: 'f'),
      pkg('queued', id: 'q'),
    ]);
    expect(groups.available.map((p) => p.id), ['a', 'n']);
    expect(groups.previous.map((p) => p.id), ['e', 'f']);
    expect(groups.unknown.map((p) => p.id), ['q']);
    expect(groups.activeCount, 1);
    expect(groups.notActiveCount, 1);
    expect(groups.hasNotActive, isTrue);
  });

  test('unknown is never labeled Expired', () {
    expect(appliedPackageStatusLabel('queued'), 'Unknown');
    expect(appliedPackageStatusLabel('expired'), 'Expired');
    expect(appliedPackageStatusLabel('finished'), 'Expired');
    expect(appliedPackageStatusLabel('not_active'), 'Not active');
  });

  test('kind and spec labels', () {
    expect(appliedPackageKindLabel('esim'), 'eSIM');
    expect(appliedPackageKindLabel('topup'), 'Top-up');
    expect(
      packageSpecLabel(pkg('active')),
      '1 GB · 7 days',
    );
    expect(
      packageSpecLabel(
        AppliedPackage(
          id: 'u',
          kind: 'esim',
          status: 'active',
          dataAllowance: 'Unlimited',
          validityDays: 1,
          isUnlimited: true,
          remainingMb: null,
          createdAt: null,
          activatedAt: null,
          expiresAt: null,
          paidUsd: null,
          currency: 'USD',
        ),
      ),
      'Unlimited · 1 day',
    );
  });

  test('paid amount is local retail or em dash', () {
    expect(formatPaidAmount('11.50', 'USD'), r'$11.50 USD');
    expect(formatPaidAmount(null, 'USD'), '—');
    expect(formatPaidAmount('nope', 'USD'), '—');
  });
}
