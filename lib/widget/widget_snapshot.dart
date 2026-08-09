import 'dart:convert';

import '../status/operational_status_view.dart';
import '../status/plan_badge.dart';

/// Atomic home-widget paint contract (schema 1).
///
/// Persisted as a single JSON string under [storageKey]. Native code paints
/// only — it must not re-evaluate eSIM health.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.schema,
    required this.revision,
    required this.surface,
    required this.hero,
    required this.remaining,
    required this.expires,
    required this.planTitle,
    required this.planSubtitle,
    required this.planFlag,
    required this.planIcon,
    required this.detail,
    required this.generatedAt,
  });

  static const schemaVersion = 1;
  static const storageKey = 'widget_snapshot_v1';

  static const compactProvider =
      'net.roamkit.bbuem.RoamKitCompactWidgetProvider';
  static const wideProvider = 'net.roamkit.bbuem.RoamKitWideWidgetProvider';

  final int schema;
  final int revision;
  final String surface;
  final String hero;
  final String remaining;
  final String expires;
  final String planTitle;
  final String planSubtitle;
  final String planFlag;
  final String planIcon;
  final String detail;
  final String generatedAt;

  /// Build from Dart view-models. Never include secrets / ICCID / external id.
  factory WidgetSnapshot.fromViews({
    required OperationalStatusView view,
    PlanBadgeView? plan,
    required int revision,
    DateTime? generatedAt,
  }) {
    final at = (generatedAt ?? DateTime.now()).toUtc();
    return WidgetSnapshot(
      schema: schemaVersion,
      revision: revision,
      surface: _surfaceName(view.surface),
      hero: view.heroLabel,
      remaining: view.dataRemainingDisplay ?? '—',
      expires: shortExpiresLabel(view.expiresDisplay),
      planTitle: plan?.title ?? '',
      planSubtitle: plan?.subtitle ?? '',
      planFlag: plan?.flagEmoji ?? '',
      planIcon: plan == null ? '' : _planIconName(plan.iconKind),
      detail: view.errorDetail ?? '',
      generatedAt: at.toIso8601String(),
    );
  }

  Map<String, Object?> toJson() => {
    'schema': schema,
    'revision': revision,
    'surface': surface,
    'hero': hero,
    'remaining': remaining,
    'expires': expires,
    'plan_title': planTitle,
    'plan_subtitle': planSubtitle,
    'plan_flag': planFlag,
    'plan_icon': planIcon,
    'detail': detail,
    'generated_at': generatedAt,
  };

  String toJsonString() => jsonEncode(toJson());

  factory WidgetSnapshot.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('widget snapshot is not a map');
    }
    final map = Map<String, dynamic>.from(decoded);
    return WidgetSnapshot(
      schema: (map['schema'] as num?)?.toInt() ?? -1,
      revision: (map['revision'] as num?)?.toInt() ?? 0,
      surface: map['surface'] as String? ?? '',
      hero: map['hero'] as String? ?? '',
      remaining: map['remaining'] as String? ?? '—',
      expires: map['expires'] as String? ?? '—',
      planTitle: map['plan_title'] as String? ?? '',
      planSubtitle: map['plan_subtitle'] as String? ?? '',
      planFlag: map['plan_flag'] as String? ?? '',
      planIcon: map['plan_icon'] as String? ?? '',
      detail: map['detail'] as String? ?? '',
      generatedAt: map['generated_at'] as String? ?? '',
    );
  }

  /// Sensitive key names must never appear in the JSON payload.
  static const forbiddenKeys = <String>{
    'credential',
    'iccid',
    'device_external_id',
    'deviceexternalid',
    'device_credential',
  };

  bool get containsForbiddenKeys {
    for (final key in toJson().keys) {
      if (forbiddenKeys.contains(key.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}

String _surfaceName(StatusSurface surface) {
  return switch (surface) {
    StatusSurface.green => 'green',
    StatusSurface.red => 'red',
    StatusSurface.slateLoading => 'slateLoading',
    StatusSurface.slateError => 'slateError',
  };
}

String _planIconName(PlanBadgeIconKind kind) {
  return switch (kind) {
    PlanBadgeIconKind.flag => 'flag',
    PlanBadgeIconKind.regional => 'regional',
    PlanBadgeIconKind.globe => 'globe',
    PlanBadgeIconKind.neutral => 'neutral',
  };
}

/// "12 Aug 2026" → "12 Aug"; "—" stays "—".
String shortExpiresLabel(String expiresDisplay) {
  final trimmed = expiresDisplay.trim();
  if (trimmed.isEmpty || trimmed == '—') {
    return '—';
  }
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0]} ${parts[1]}';
  }
  return trimmed;
}
