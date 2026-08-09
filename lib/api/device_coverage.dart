import 'device_status.dart';

/// Read-only coverage snapshot from `POST /api/v1/device/coverage/`.
class DeviceCoverage {
  const DeviceCoverage({
    required this.deviceExternalId,
    required this.coverageType,
    required this.coverage,
    required this.checkedAt,
  });

  final String deviceExternalId;
  final String? coverageType;

  /// Purchase-time list, or null for legacy orders without a snapshot.
  final List<DeviceCoverageCountry>? coverage;
  final DateTime? checkedAt;

  factory DeviceCoverage.fromJson(Map<String, dynamic> json) {
    final raw = json['coverage'];
    List<DeviceCoverageCountry>? countries;
    if (raw == null) {
      countries = null;
    } else if (raw is List) {
      countries = [
        for (final item in raw)
          if (item is Map)
            DeviceCoverageCountry.fromJson(Map<String, dynamic>.from(item)),
      ];
    } else {
      countries = const [];
    }
    return DeviceCoverage(
      deviceExternalId: json['device_external_id'] as String? ?? '',
      coverageType: _asNullableString(json['coverage_type']),
      coverage: countries,
      checkedAt: parseApiDateTime(json['checked_at']),
    );
  }
}

class DeviceCoverageCountry {
  const DeviceCoverageCountry({
    required this.countryCode,
    required this.countryName,
    required this.operators,
  });

  final String countryCode;
  final String? countryName;
  final List<String> operators;

  /// Display name: prefer country_name, else country_code.
  String get displayName {
    final name = countryName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return countryCode;
  }

  factory DeviceCoverageCountry.fromJson(Map<String, dynamic> json) {
    final opsRaw = json['operators'];
    final operators = <String>[];
    if (opsRaw is List) {
      for (final item in opsRaw) {
        if (item is String) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) {
            operators.add(trimmed);
          }
        }
      }
    }
    return DeviceCoverageCountry(
      countryCode: (json['country_code'] as String? ?? '').trim().toUpperCase(),
      countryName: _asNullableString(json['country_name']),
      operators: operators,
    );
  }
}

String? _asNullableString(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}
