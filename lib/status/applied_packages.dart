import '../api/device_packages.dart';
import '../api/device_status.dart';

/// Display grouping for applied package history.
///
/// Current = active + not_active + queued. Previous = expired + finished.
/// Unknown statuses are omitted (fail-closed) — never painted as queued.
class AppliedPackageGroup {
  const AppliedPackageGroup({
    required this.active,
    required this.notActive,
    required this.queued,
    required this.previous,
    required this.omittedUnknown,
  });

  final List<AppliedPackage> active;
  final List<AppliedPackage> notActive;
  final List<AppliedPackage> queued;
  final List<AppliedPackage> previous;
  final List<AppliedPackage> omittedUnknown;

  int get activeCount => active.length;

  /// Header queued count includes not_active (upcoming).
  int get queuedHeaderCount => notActive.length + queued.length;

  bool get hasCurrent =>
      active.isNotEmpty || notActive.isNotEmpty || queued.isNotEmpty;

  String? get headerSummary {
    final parts = <String>[];
    if (activeCount > 0) {
      parts.add('$activeCount active');
    }
    if (queuedHeaderCount > 0) {
      parts.add('$queuedHeaderCount queued');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }
}

AppliedPackageGroup partitionAppliedPackages(
  List<AppliedPackage> packages, {
  AppliedPackage? activePackage,
}) {
  final active = <AppliedPackage>[];
  final notActive = <AppliedPackage>[];
  final queued = <AppliedPackage>[];
  final previous = <AppliedPackage>[];
  final omittedUnknown = <AppliedPackage>[];

  for (final pkg in packages) {
    switch (pkg.status) {
      case 'active':
        active.add(pkg);
      case 'not_active':
        notActive.add(pkg);
      case 'queued':
        queued.add(pkg);
      case 'expired':
      case 'finished':
        previous.add(pkg);
      default:
        omittedUnknown.add(pkg);
    }
  }

  previous.sort(_newestPreviousFirst);

  return AppliedPackageGroup(
    active: _leadWithActivePackage(active, activePackage),
    notActive: notActive,
    queued: queued,
    previous: previous,
    omittedUnknown: omittedUnknown,
  );
}

List<AppliedPackage> _leadWithActivePackage(
  List<AppliedPackage> active,
  AppliedPackage? selected,
) {
  if (selected == null || selected.status != 'active') {
    return active;
  }
  final match = active.where((pkg) => pkg.id == selected.id).toList();
  final rest = active.where((pkg) => pkg.id != selected.id).toList();
  if (match.isEmpty) {
    return active;
  }
  return [...match, ...rest];
}

int _newestPreviousFirst(AppliedPackage a, AppliedPackage b) {
  final ak = _previousSortKey(a);
  final bk = _previousSortKey(b);
  if (ak == null && bk == null) {
    return 0;
  }
  if (ak == null) {
    return 1;
  }
  if (bk == null) {
    return -1;
  }
  return bk.compareTo(ak);
}

DateTime? _previousSortKey(AppliedPackage pkg) {
  return parseApiDateTime(pkg.expiresAt) ??
      parseApiDateTime(pkg.activatedAt) ??
      pkg.createdAt;
}

String appliedPackageStatusLabel(String status) {
  return switch (status) {
    'active' => 'Active',
    'not_active' => 'Starts on first use',
    'queued' => 'Queued',
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

String? formatPaidAmountOrNull(String? paidUsd, String? currency) {
  if (paidUsd == null || paidUsd.isEmpty) {
    return null;
  }
  final amount = double.tryParse(paidUsd);
  if (amount == null || !amount.isFinite) {
    return null;
  }
  final code = (currency ?? '').trim();
  final suffix = code.isEmpty ? 'USD' : code;
  return '\$${amount.toStringAsFixed(2)} $suffix';
}

String formatPaidAmount(String? paidUsd, String? currency) {
  return formatPaidAmountOrNull(paidUsd, currency) ?? '—';
}
