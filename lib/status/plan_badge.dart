import '../api/device_status.dart';

/// Icon kind for the plan badge (UI maps these to widgets/emoji).
enum PlanBadgeIconKind { flag, regional, globe, neutral }

/// Presentation model for the compact plan badge.
///
/// Pure Dart — must not affect [OperationalStatusView] / StatusSurface.
class PlanBadgeView {
  const PlanBadgeView({
    required this.title,
    required this.subtitle,
    required this.iconKind,
    this.flagEmoji,
  });

  final String title;
  final String? subtitle;
  final PlanBadgeIconKind iconKind;

  /// Set when [iconKind] is [PlanBadgeIconKind.flag].
  final String? flagEmoji;
}

/// Build badge view from API plan, or null when badge should be hidden.
PlanBadgeView? buildPlanBadgeView(DeviceStatusPlan? plan) {
  if (plan == null) {
    return null;
  }
  final title = (plan.title ?? '').trim();
  if (title.isEmpty) {
    return null;
  }

  final coverage = (plan.coverageType ?? '').trim().toLowerCase();
  final country = (plan.countryCode ?? '').trim().toUpperCase();
  final flag = countryFlagEmoji(country);

  late final PlanBadgeIconKind kind;
  String? flagEmoji;
  if (coverage == 'local' && flag != null) {
    kind = PlanBadgeIconKind.flag;
    flagEmoji = flag;
  } else if (coverage == 'regional') {
    kind = PlanBadgeIconKind.regional;
  } else if (coverage == 'global') {
    kind = PlanBadgeIconKind.globe;
  } else if (flag != null) {
    kind = PlanBadgeIconKind.flag;
    flagEmoji = flag;
  } else {
    kind = PlanBadgeIconKind.neutral;
  }

  return PlanBadgeView(
    title: title,
    subtitle: null,
    iconKind: kind,
    flagEmoji: flagEmoji,
  );
}

/// Join allowance and validity with ` · `; omit missing parts (no stray sep).
String? formatPlanSubtitle({
  String? dataAllowance,
  int? validityDays,
}) {
  final parts = <String>[];
  final allowance = (dataAllowance ?? '').trim();
  if (allowance.isNotEmpty) {
    parts.add(allowance);
  }
  if (validityDays != null && validityDays > 0) {
    parts.add(validityDays == 1 ? '1 day' : '$validityDays days');
  }
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' · ');
}

/// ISO 3166-1 alpha-2 → regional-indicator flag emoji; null if invalid.
String? countryFlagEmoji(String? countryCode) {
  if (countryCode == null) {
    return null;
  }
  final code = countryCode.trim().toUpperCase();
  if (code.length != 2) {
    return null;
  }
  final a = code.codeUnitAt(0);
  final b = code.codeUnitAt(1);
  if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) {
    return null;
  }
  return String.fromCharCodes(<int>[
    0x1F1E6 + (a - 0x41),
    0x1F1E6 + (b - 0x41),
  ]);
}
