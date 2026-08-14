import 'dart:convert';

import '../api/device_packages.dart';
import '../status/home_status_chrome.dart';
import '../status/operational_status_view.dart';
import '../status/usage_bar_view.dart';

/// Atomic home-widget paint contract (schema 2).
///
/// Flutter decides meaning. Native only paints. One JSON string under
/// [storageKey]. Never include secrets, ICCID, serial, or raw API bodies.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.schemaVersion,
    required this.generatedAt,
    required this.lastSuccessAt,
    required this.displayStatus,
    required this.statusLabel,
    required this.activePackageTitle,
    required this.hasUsage,
    required this.remainingText,
    required this.totalText,
    required this.usedText,
    required this.percent,
    required this.unlimited,
    required this.coverageAvailable,
    required this.updateUnavailable,
  });

  static const schemaVersionValue = 2;
  static const storageKey = 'widget_snapshot';
  static const legacyStorageKey = 'widget_snapshot_v1';

  static const compactProvider =
      'net.roamkit.bbuem.RoamKitCompactWidgetProvider';
  static const wideProvider = 'net.roamkit.bbuem.RoamKitWideWidgetProvider';

  static const displayStatuses = <String>{
    'active',
    'inactive',
    'expired',
    'unavailable',
  };

  final int schemaVersion;
  final String generatedAt;
  final String? lastSuccessAt;
  final String displayStatus;
  final String statusLabel;
  final String? activePackageTitle;
  final bool hasUsage;
  final String remainingText;
  final String totalText;
  final String usedText;
  final int percent;
  final bool unlimited;
  final bool coverageAvailable;
  final bool updateUnavailable;

  /// Build the finalized paint object. [packagesFailed] hides the title only.
  factory WidgetSnapshot.fromState({
    required OperationalStatusView view,
    AppliedPackage? activePackage,
    required UsageBarView bar,
    required bool coverageAvailable,
    required bool packagesFailed,
    WidgetSnapshot? lastGood,
    required DateTime now,
  }) {
    final at = now.toUtc();
    final generated = at.toIso8601String();

    if (!view.isSuccessSnapshot) {
      return _unavailable(
        generatedAt: generated,
        lastGood: lastGood,
      );
    }

    final chrome = homeStatusChrome(view);
    final displayStatus = _displayStatus(chrome.kind);
    final showTitle = !packagesFailed &&
        showHeroPackageTitle(view, activePackage);
    final usage = _usageFields(bar);
    final expired = chrome.kind == HomeStatusKind.expired;

    return WidgetSnapshot(
      schemaVersion: schemaVersionValue,
      generatedAt: generated,
      lastSuccessAt: generated,
      displayStatus: displayStatus,
      statusLabel: chrome.label,
      activePackageTitle:
          showTitle ? appliedPackageTitle(activePackage!) : null,
      hasUsage: expired ? false : usage.hasUsage,
      remainingText: expired ? '' : usage.remainingText,
      totalText: expired ? '' : usage.totalText,
      usedText: expired ? '' : usage.usedText,
      percent: expired ? 0 : usage.percent,
      unlimited: expired ? false : usage.unlimited,
      coverageAvailable: coverageAvailable,
      updateUnavailable: false,
    );
  }

  static WidgetSnapshot _unavailable({
    required String generatedAt,
    WidgetSnapshot? lastGood,
  }) {
    if (lastGood == null || lastGood.lastSuccessAt == null) {
      return WidgetSnapshot(
        schemaVersion: schemaVersionValue,
        generatedAt: generatedAt,
        lastSuccessAt: null,
        displayStatus: 'unavailable',
        statusLabel: 'UNAVAILABLE',
        activePackageTitle: null,
        hasUsage: false,
        remainingText: '',
        totalText: '',
        usedText: '',
        percent: 0,
        unlimited: false,
        coverageAvailable: false,
        updateUnavailable: false,
      );
    }
    return WidgetSnapshot(
      schemaVersion: schemaVersionValue,
      generatedAt: generatedAt,
      lastSuccessAt: lastGood.lastSuccessAt,
      displayStatus: 'unavailable',
      statusLabel: 'UNAVAILABLE',
      activePackageTitle: null,
      hasUsage: lastGood.hasUsage,
      remainingText: lastGood.remainingText,
      totalText: lastGood.totalText,
      usedText: lastGood.usedText,
      percent: lastGood.percent,
      unlimited: lastGood.unlimited,
      coverageAvailable: lastGood.coverageAvailable,
      updateUnavailable: true,
    );
  }

  /// Offline stale flip — no API. Keeps last-good usage.
  WidgetSnapshot markStale({required DateTime now}) {
    if (lastSuccessAt == null) {
      return _unavailable(generatedAt: now.toUtc().toIso8601String());
    }
    return copyWith(
      generatedAt: now.toUtc().toIso8601String(),
      displayStatus: 'unavailable',
      statusLabel: 'UNAVAILABLE',
      clearTitle: true,
      updateUnavailable: true,
    );
  }

  WidgetSnapshot copyWith({
    String? generatedAt,
    String? lastSuccessAt,
    bool clearLastSuccessAt = false,
    String? displayStatus,
    String? statusLabel,
    String? activePackageTitle,
    bool clearTitle = false,
    bool? hasUsage,
    String? remainingText,
    String? totalText,
    String? usedText,
    int? percent,
    bool? unlimited,
    bool? coverageAvailable,
    bool? updateUnavailable,
  }) {
    return WidgetSnapshot(
      schemaVersion: schemaVersion,
      generatedAt: generatedAt ?? this.generatedAt,
      lastSuccessAt:
          clearLastSuccessAt ? null : (lastSuccessAt ?? this.lastSuccessAt),
      displayStatus: displayStatus ?? this.displayStatus,
      statusLabel: statusLabel ?? this.statusLabel,
      activePackageTitle: clearTitle
          ? null
          : (activePackageTitle ?? this.activePackageTitle),
      hasUsage: hasUsage ?? this.hasUsage,
      remainingText: remainingText ?? this.remainingText,
      totalText: totalText ?? this.totalText,
      usedText: usedText ?? this.usedText,
      percent: percent ?? this.percent,
      unlimited: unlimited ?? this.unlimited,
      coverageAvailable: coverageAvailable ?? this.coverageAvailable,
      updateUnavailable: updateUnavailable ?? this.updateUnavailable,
    );
  }

  Map<String, Object?> toJson() => {
        'schema_version': schemaVersion,
        'generated_at': generatedAt,
        'last_success_at': lastSuccessAt,
        'display_status': displayStatus,
        'status_label': statusLabel,
        'active_package_title': activePackageTitle,
        'has_usage': hasUsage,
        'remaining_text': remainingText,
        'total_text': totalText,
        'used_text': usedText,
        'percent': percent,
        'unlimited': unlimited,
        'coverage_available': coverageAvailable,
        'update_unavailable': updateUnavailable,
      };

  String toJsonString() => jsonEncode(toJson());

  factory WidgetSnapshot.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('widget snapshot is not a map');
    }
    final map = Map<String, dynamic>.from(decoded);
    final schema = (map['schema_version'] as num?)?.toInt() ?? -1;
    if (schema != schemaVersionValue) {
      throw FormatException('unsupported widget schema $schema');
    }
    final status = map['display_status'] as String? ?? '';
    if (!displayStatuses.contains(status)) {
      throw FormatException('unknown display_status $status');
    }
    return WidgetSnapshot(
      schemaVersion: schema,
      generatedAt: map['generated_at'] as String? ?? '',
      lastSuccessAt: map['last_success_at'] as String?,
      displayStatus: status,
      statusLabel: map['status_label'] as String? ?? 'UNAVAILABLE',
      activePackageTitle: map['active_package_title'] as String?,
      hasUsage: map['has_usage'] as bool? ?? false,
      remainingText: map['remaining_text'] as String? ?? '',
      totalText: map['total_text'] as String? ?? '',
      usedText: map['used_text'] as String? ?? '',
      percent: _clampPercent((map['percent'] as num?)?.toInt() ?? 0),
      unlimited: map['unlimited'] as bool? ?? false,
      coverageAvailable: map['coverage_available'] as bool? ?? false,
      updateUnavailable: map['update_unavailable'] as bool? ?? false,
    );
  }

  static const forbiddenKeys = <String>{
    'credential',
    'iccid',
    'device_external_id',
    'deviceexternalid',
    'device_credential',
    'device_serial',
    'serial',
    'wholesale',
    'results',
    'plan_title',
  };

  bool get containsForbiddenKeys {
    for (final key in toJson().keys) {
      if (forbiddenKeys.contains(key.toLowerCase())) {
        return true;
      }
    }
    final blob = toJsonString().toLowerCase();
    return blob.contains('iccid') ||
        blob.contains('credential') ||
        blob.contains('device_serial');
  }

  static String _displayStatus(HomeStatusKind kind) {
    return switch (kind) {
      HomeStatusKind.active => 'active',
      HomeStatusKind.inactive => 'inactive',
      HomeStatusKind.expired => 'expired',
      HomeStatusKind.unavailable => 'unavailable',
    };
  }
}

class _UsageFields {
  const _UsageFields({
    required this.hasUsage,
    required this.remainingText,
    required this.totalText,
    required this.usedText,
    required this.percent,
    required this.unlimited,
  });

  final bool hasUsage;
  final String remainingText;
  final String totalText;
  final String usedText;
  final int percent;
  final bool unlimited;
}

_UsageFields _usageFields(UsageBarView bar) {
  if (bar.kind == UsageBarKind.unlimited) {
    return const _UsageFields(
      hasUsage: true,
      remainingText: 'Unlimited',
      totalText: '',
      usedText: '',
      percent: 100,
      unlimited: true,
    );
  }
  if (bar.kind != UsageBarKind.metered ||
      bar.remainingMb == null ||
      bar.usedMb == null ||
      bar.totalMb == null ||
      bar.remainingPercent == null) {
    return const _UsageFields(
      hasUsage: false,
      remainingText: '',
      totalText: '',
      usedText: '',
      percent: 0,
      unlimited: false,
    );
  }
  return _UsageFields(
    hasUsage: true,
    remainingText: formatDataMb(bar.remainingMb!),
    totalText: formatDataMb(bar.totalMb!),
    usedText: formatDataMb(bar.usedMb!),
    percent: _clampPercent(bar.remainingPercent!),
    unlimited: false,
  );
}

int _clampPercent(int value) {
  if (value < 0) {
    return 0;
  }
  if (value > 100) {
    return 100;
  }
  return value;
}

/// True when [candidate] is older than [current] and must not overwrite it.
bool snapshotIsStaleWrite(WidgetSnapshot current, WidgetSnapshot candidate) {
  final currentAt = DateTime.tryParse(current.generatedAt);
  final nextAt = DateTime.tryParse(candidate.generatedAt);
  if (currentAt == null || nextAt == null) {
    return false;
  }
  return nextAt.isBefore(currentAt);
}
