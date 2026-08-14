import '../api/device_packages.dart';
import 'applied_packages.dart';
import 'operational_status_view.dart';

/// In-app status paint. Evaluation stays on [OperationalStatusView].
enum HomeStatusKind { active, inactive, expired, unavailable }

class HomeStatusChrome {
  const HomeStatusChrome({
    required this.kind,
    required this.glyph,
    required this.label,
    required this.semantics,
    this.secondary,
  });

  final HomeStatusKind kind;
  final String glyph;
  final String label;
  final String semantics;
  final String? secondary;

  String get badge => '$glyph $label';
}

/// Map evaluated hero labels to locked in-app chrome. Color stays off.
HomeStatusChrome homeStatusChrome(OperationalStatusView view) {
  if (!view.isSuccessSnapshot) {
    return const HomeStatusChrome(
      kind: HomeStatusKind.unavailable,
      glyph: '↻',
      label: 'UNAVAILABLE',
      secondary: 'Status is temporarily unavailable',
      semantics: 'Status: Unavailable',
    );
  }
  return switch (view.heroLabel) {
    'ACTIVE' => const HomeStatusChrome(
        kind: HomeStatusKind.active,
        glyph: '✓',
        label: 'ACTIVE',
        semantics: 'Status: Active',
      ),
    'EXPIRED' => const HomeStatusChrome(
        kind: HomeStatusKind.expired,
        glyph: '!',
        label: 'EXPIRED',
        secondary: 'Data package expired',
        semantics: 'Status: Expired',
      ),
    'INACTIVE' || 'NO DATA' || 'EXHAUSTED' => const HomeStatusChrome(
        kind: HomeStatusKind.inactive,
        glyph: '○',
        label: 'INACTIVE',
        secondary: 'No active data package',
        semantics: 'Status: Inactive',
      ),
    _ => const HomeStatusChrome(
        kind: HomeStatusKind.unavailable,
        glyph: '↻',
        label: 'UNAVAILABLE',
        secondary: 'Status is temporarily unavailable',
        semantics: 'Status: Unavailable',
      ),
  };
}

/// Hero title only when status is ACTIVE and [activePackage] is active.
bool showHeroPackageTitle(
  OperationalStatusView view,
  AppliedPackage? activePackage,
) {
  return view.isSuccessSnapshot &&
      view.heroLabel == 'ACTIVE' &&
      activePackage != null &&
      activePackage.status == 'active';
}

String appliedPackageTitle(AppliedPackage pkg) {
  return '${appliedPackageKindLabel(pkg.kind)} · ${packageSpecLabel(pkg)}';
}

String previousCardTitle(List<AppliedPackage> previous) {
  if (previous.length == 1) {
    return 'Previous · ${packageSpecLabel(previous.first)}';
  }
  return 'Previous packages · ${previous.length}';
}
