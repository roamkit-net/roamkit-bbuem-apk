import '../api/device_packages.dart';

/// Display grouping for applied package history (same as web).
class AppliedPackageGroup {
  const AppliedPackageGroup({
    required this.available,
    required this.previous,
    required this.unknown,
  });

  final List<AppliedPackage> available;
  final List<AppliedPackage> previous;
  final List<AppliedPackage> unknown;

  int get availableCount => available.length;

  int get activeCount =>
      available.where((pkg) => pkg.status == 'active').length;

  int get notActiveCount =>
      available.where((pkg) => pkg.status == 'not_active').length;

  bool get hasNotActive => notActiveCount > 0;
}

/// Available = active + not_active; Previous = expired + finished;
/// everything else is Unknown (never labeled Expired).
AppliedPackageGroup partitionAppliedPackages(List<AppliedPackage> packages) {
  final available = <AppliedPackage>[];
  final previous = <AppliedPackage>[];
  final unknown = <AppliedPackage>[];

  for (final pkg in packages) {
    switch (pkg.status) {
      case 'active':
      case 'not_active':
        available.add(pkg);
      case 'expired':
      case 'finished':
        previous.add(pkg);
      default:
        unknown.add(pkg);
    }
  }

  return AppliedPackageGroup(
    available: available,
    previous: previous,
    unknown: unknown,
  );
}

String appliedPackageStatusLabel(String status) {
  return switch (status) {
    'active' => 'Active',
    'not_active' => 'Not active',
    'expired' || 'finished' => 'Expired',
    _ => 'Unknown',
  };
}

String appliedPackageKindLabel(String kind) {
  return kind == 'esim' ? 'eSIM' : 'Top-up';
}

String packageSpecLabel(AppliedPackage pkg) {
  final days = pkg.validityDays == 1 ? '1 day' : '${pkg.validityDays} days';
  if (pkg.isUnlimited) {
    return 'Unlimited · $days';
  }
  final data = pkg.dataAllowance.trim();
  return '${data.isEmpty ? '—' : data} · $days';
}

String formatPaidAmount(String? paidUsd, String? currency) {
  if (paidUsd == null || paidUsd.isEmpty) {
    return '—';
  }
  final amount = double.tryParse(paidUsd);
  if (amount == null || !amount.isFinite) {
    return '—';
  }
  final code = (currency ?? '').trim();
  final suffix = code.isEmpty ? 'USD' : code;
  return '\$${amount.toStringAsFixed(2)} $suffix';
}

String availablePackagesCaption(int count) {
  if (count == 1) {
    return '1 package available';
  }
  return '$count packages available';
}
